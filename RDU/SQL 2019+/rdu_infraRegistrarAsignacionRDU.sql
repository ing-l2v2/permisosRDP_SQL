/*
    ALTER TABLE infraAccesosTempRDU
      ADD CodUser VARCHAR(5) NULL
    EXEC dbo.rdu_infraRegistrarAsignacionRDU 'FIDENSLAT\gchavez','10.0.0.61',"Remote Desktop Users", 48, NULL, NULL, NULL;
    SELECT * FROM infraAccesosTempRDU WHERE Estado='ASIGNADO' ORDER BY Id DESC
    SELECT * FROM infraAccesosTempRDU WHERE NumReg=16897
    UPDATE dbo.infraAccesosTempRDU SET Estado = 'ASIGNADO', Expira='2026-02-27 23:59', Revocado = NULL, Observacion=NULL WHERE Id=101;
    DELETE infraAccesosTempRDU WHERE ID IN (163)
*/

USE [master]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.rdu_infraRegistrarAsignacionRDU') IS NOT NULL
    DROP PROCEDURE dbo.rdu_infraRegistrarAsignacionRDU;
GO
-- =============================================
-- Author:		Leonel Villa
-- Create date: 2026-02-14
-- Description:	Genera registro de asignacion de permiso si existe lo revoca previamente y luego asigna.
--      GESTIONA SERVIDOR 10.0.0.49 UNICAMENTE
-- Contempla caso de usuarios del grupo SAC. Si existe duplicidad, extiende el permiso
CREATE PROCEDURE dbo.rdu_infraRegistrarAsignacionRDU
(
    @Usuario NVARCHAR(200),
    @Servidor NVARCHAR(200),
    @Grupo NVARCHAR(100),
    @DuracionHoras INT = 48,        -- Por defecto 48h
    @Expira DATETIME = NULL,
    @NumReg INT = NULL,
    @CodUser VARCHAR(5) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Tmp TABLE (
        Duplicado INT,
        NumReg INT,
        CodUser VARCHAR(5),
        Est VARCHAR(20),
        Expira DATETIME,
        Revocado VARCHAR(16),
        Usuario SYSNAME NULL,
        Grupo VARCHAR(100),        
        id INT
    );
    DECLARE @Id INT;
    DECLARE @Duplicado INT = -1;
    DECLARE @NuevoId TABLE (Id INT);
    DECLARE @IdSalida INT;
    DECLARE @DuracionMaxima INT
    DECLARE @MaxDuracion INT = 48;
    DECLARE @MaxDuracionSac INT = 7*24;

    SET @DuracionMaxima = 
        CASE
            WHEN @Usuario IN ('.\jarzolay','.\mcobos','.\mvasquez','.\larroba','.\aaguilar','FIDENSLAT\jarzolay','FIDENSLAT\mcobos','FIDENSLAT\mvasquez','FIDENSLAT\larroba','FIDENSLAT\aaguilar')
                THEN @MaxDuracionSac 
            ELSE @MaxDuracion
        END; 


    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'infraAccesosTempRDU')
    BEGIN
        CREATE TABLE infraAccesosTempRDU (
            Id INT IDENTITY PRIMARY KEY,
            Usuario     NVARCHAR(200),
            Servidor    NVARCHAR(200),
            Grupo       NVARCHAR(100),
            Asignacion  DATETIME NOT NULL DEFAULT GETDATE(),
            Expira      DATETIME NOT NULL,
            Estado      NVARCHAR(20) NULL, -- ASIGNADO | REVOCADO | ERROR
            Revocado    DATETIME,
            Observacion NVARCHAR(1000) NULL,
            NumReg      INT NULL,
            CodUser     VARCHAR(5) NULL
        );
        ------------------------------------------------------------
        -- ÍNDICES ÚTILES
        ------------------------------------------------------------
        CREATE INDEX IX_infraAccesosTempRDU_Estado
            ON dbo.infraAccesosTempRDU (Estado);

        CREATE INDEX IX_infraAccesosTempRDU_Expira
            ON dbo.infraAccesosTempRDU (Expira);
    END

    --------------------------------------------------------------------
    -- REVOKE ANTES DE ASIGNAR SI EXISTE UN PERMISO ACTIVO
    --------------------------------------------------------------------
    INSERT INTO @Tmp
    EXEC dbo.rdu_infra_duplicado_permiso_RDU @Usuario, @Servidor, @Grupo;

    IF (EXISTS( SELECT 1 FROM @Tmp))
    BEGIN
        SELECT TOP 1 @Duplicado=Duplicado, @Id = id,
            @NumReg = (CASE WHEN @NumReg IS NULL THEN NumReg ELSE @NumReg END),
            @CodUser = (CASE WHEN @CodUser IS NULL THEN CodUser ELSE @CodUser END),
            @Expira = (CASE WHEN @Expira IS NULL THEN Expira ELSE @Expira END)
        FROM @Tmp;
        
        IF (@Duplicado=1)
        BEGIN
            UPDATE master.dbo.infraAccesosTempRDU
            SET Revocado = GETDATE(),
                Estado = 'REVOCADO',
                Observacion = 'FORZADO-ANTES-DE-ASIGNAR'
            WHERE Id= @Id;            
        END;
    END
    ELSE
    BEGIN 
        INSERT INTO @Tmp (Duplicado) VALUES (0);
    END;

    -- Registrar nuevo acceso temporal (máximo 48h)    
    INSERT INTO master.dbo.infraAccesosTempRDU (Usuario, Servidor, Grupo, Estado, NumReg, CodUser, Expira)
    OUTPUT INSERTED.Id INTO @NuevoId
    VALUES (@Usuario, @Servidor, @Grupo, 'ASIGNADO', @NumReg, @CodUser,
        CASE 
        -- Caso 1: @Expira válida y futura
        WHEN @Expira IS NOT NULL 
             AND ISDATE(@Expira) = 1
             AND @Expira > GETDATE() 
             AND DATEDIFF(HOUR, GETDATE(), @Expira) <= @DuracionMaxima
            THEN @Expira
        -- Caso 2: @Expira existe pero excede 49 horas → limitar
        WHEN @Expira IS NOT NULL 
             AND ISDATE(@Expira) = 1
             AND @Expira > GETDATE()
             AND DATEDIFF(HOUR, GETDATE(), @Expira) > @DuracionMaxima
            THEN DATEADD(HOUR, @DuracionMaxima, GETDATE())  -- límite máximo permitido
        -- Caso 3: @Expira nula o inválida → usar @DuracionHoras máximo @DuracionMaxima
        ELSE DATEADD(
            HOUR, 
            CASE 
                WHEN @DuracionHoras IS NULL THEN @DuracionMaxima          -- por defecto
                WHEN @DuracionHoras > @DuracionMaxima THEN @DuracionMaxima            -- limitar
                ELSE @DuracionHoras 
            END,
            GETDATE()
        )
        END
    );

    SELECT @IdSalida = Id FROM @NuevoId;
    --------------------------------------------------------------------
    -- *** ÚNICO RESULTADO FINAL ***
    --------------------------------------------------------------------    
    SELECT NumReg, CodUser, Estado AS Est, CONVERT(VARCHAR(16), Expira, 120) As FechaFin, Grupo, Id AS idAcceso, Expira, @Duplicado As Duplicado FROM dbo.infraAccesosTempRDU WHERE Id = @IdSalida;
END;