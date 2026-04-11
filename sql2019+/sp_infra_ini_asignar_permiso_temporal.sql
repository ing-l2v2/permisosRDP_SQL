/*
    EXEC sp_infra_ini_asignar_permiso_temporal @Usuario='mvasquez', @TipoAcceso='RW', @BaseDatos=117, @DuracionHoras=48, @Expira=NULL, @NumReg=NULL, @CodUser=NULL;
    SELECT TOP 20 * FROM infraPermisosTemp WHERE Usuario = 'mcobos' ORDER BY Expira DESC, BaseDatos ASC;
    UPDATE infraPermisosTemp SET Expira='2026-03-09 10:29:17' WHERE IdPermiso IN (188,189)
    SELECT * FROM infraBasesGestionadas;
    INSERT INTO infraBasesGestionadas (idAdminFidens, BaseDatos, Estado) VALUES (50, 'DERCO_CORREDOR', 1);
    UPDATE infraBasesGestionadas SET idAdminFidens = 92 WHERE idBase=5;
    DELETE FROM infraPermisosTemp WHERE idPermiso IN ( 50, 51 );

    UPDATE infraBasesGestionadas SET idAdminFidens=89 WHERE idBase=1;
    UPDATE infraBasesGestionadas SET idAdminFidens=89 WHERE idBase=2;
    UPDATE infraBasesGestionadas SET Estado = 0 WHERE idBase IN (1,2,5,6);

    UPDATE infraBasesGestionadas SET Estado=0 WHERE idBase IN (5,10,11);

    ALTER LOGIN [jbarona] DISABLE
    GO

    SELECT name, create_date, modify_date, type, is_disabled
    FROM sys.server_principals
    WHERE 
        -- name = @Usr  AND -- ejemplo: 'gchavez' 
        type IN ('S'); -- SQL Login / Windows Login
    
    EXEC sp_help 'sp_infra_ini_asignar_permiso_temporal';
    sp_helptext 'sp_infra_ini_asignar_permiso_temporal';
*/
USE master;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.sp_infra_ini_asignar_permiso_temporal') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_ini_asignar_permiso_temporal;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-14
-- Description:	Iniciar permisos a la base de datos para usuarios en servidores 2019+
-- EXEC sp_infra_ini_asignar_permiso_temporal @Usuario='mvasquez', @TipoAcceso='RW', @BaseDatos=117, @DuracionHoras=48, @Expira=NULL, @NumReg=NULL, @CodUser=NULL;
-- =============================================
CREATE PROCEDURE dbo.sp_infra_ini_asignar_permiso_temporal
    @Usuario SYSNAME,
    @TipoAcceso VARCHAR(20),   -- PERMISO, SERVER_ROLE, DB_ROLE -- R, W, RW, RWSP, SP, SM, RWSM, JOB, SYS, PRF, ALL
    -- @Permiso VARCHAR(200),         -- Ej: 'ALTER TRACE', 'SELECT', 'EXECUTE'    
    @BaseDatos INT = NULL,     -- Null si es permiso de servidor JOB o PRF
    @DuracionHoras INT = 48,        -- Por defecto 48h
    @Expira DATETIME = NULL,
    @NumReg INT = NULL,
    @CodUser VARCHAR(5) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdPermiso INT = -1;
    DECLARE @DupDuplica INT = -1;
    DECLARE @DupNumReg INT;
    DECLARE @DupCodUser VARCHAR(5);
    DECLARE @DupExpira VARCHAR(5);

    DECLARE @Dupli TABLE (
        Duplicado INT,
        NumReg INT,
        CodUser VARCHAR(5),
        Est VARCHAR(20),
        Expira DATETIME,
        Usuario SYSNAME NULL,
        TipoAcceso VARCHAR(20),
        idBaseDatos INT,
        BaseDatos SYSNAME NULL,
        idPermiso INT
    );


    DECLARE @nomBaseDatos SYSNAME;
    DECLARE @Tmp TABLE (
        NumReg INT,
        CodUser VARCHAR(5),
        Est VARCHAR(20),
        FechaFin VARCHAR(16),
        BaseDatos SYSNAME,
        IdPermiso INT
    );
    BEGIN TRY
        ------------------------------------------------------------
        -- BASES DE DATOS DEL SERVIDOR
        ------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'infraBasesGestionadas')
        BEGIN
            CREATE TABLE dbo.infraBasesGestionadas(
                idBase INT IDENTITY(1,1) PRIMARY KEY,
                idAdminFidens INT DEFAULT 1,
                BaseDatos SYSNAME UNIQUE,
                Estado INT DEFAULT(1)
            );
            CREATE INDEX IX_infraBasesGestionadas_idAdminFidens
                ON dbo.infraBasesGestionadas (idAdminFidens);

            INSERT INTO master.dbo.infraBasesGestionadas (BaseDatos, idAdminFidens, Estado)
            SELECT d.name, 1, 1
            FROM sys.databases d
            WHERE d.name NOT IN ('master','model','msdb','tempdb')
              AND d.name NOT IN (
                    SELECT BaseDatos 
                    FROM master.dbo.infraBasesGestionadas
              )
            ORDER BY d.name;
        END

        -- Validar que usuario exista en LoginName
        DECLARE @ENABLE INT;
        DECLARE @fcreate DATETIME;
        DECLARE @fmodify DATETIME;
        SELECT @fcreate = create_date,
            @fmodify = modify_date,
            @ENABLE = is_disabled
        FROM sys.server_principals
        WHERE name = @Usuario -- ejemplo: 'gchavez'
          AND type IN ('S', 'U'); -- SQL Login / Windows Login

        IF (@ENABLE IS NULL)
        BEGIN
            --PRINT N'USUARIO NO EXISTE REGISTRADO EN EL SERVIDOR, REVISAR USUARIO ' + CAST(@Usuario AS NVARCHAR(128));
            RETURN -1;
        END;        

        -- Caso 1: Permiso de servidor: JOB o PRF
        IF (@TipoAcceso='JOB' OR @TipoAcceso='PRF' OR @TipoAcceso='ALL')
        BEGIN
            -- SELECT TOP 1 BaseDatos FROM infraBasesGestionadas WHERE idAdminFidens = 117 AND Estado = 1 ORDER BY BaseDatos;
            SELECT TOP 1 @nomBaseDatos = BaseDatos FROM infraBasesGestionadas WHERE idAdminFidens = @BaseDatos AND Estado=1 ORDER BY BaseDatos ASC;

            DELETE FROM @Dupli;
            INSERT INTO @Dupli (Duplicado, NumReg, CodUser, Est, Expira, Usuario, TipoAcceso, idBaseDatos, BaseDatos, idPermiso)
            EXEC dbo.sp_infra_duplicado_permiso_temporal @Usuario = @Usuario, @TipoAcceso = @TipoAcceso, @BaseDatos = NULL, @nomBD = @nomBaseDatos;

            IF (EXISTS( SELECT 1 FROM @Dupli))
            BEGIN
                SELECT TOP 1 @DupDuplica=Duplicado, @IdPermiso = idPermiso,
                    @NumReg = (CASE WHEN @NumReg IS NULL THEN NumReg ELSE @NumReg END),
                    @CodUser = (CASE WHEN @CodUser IS NULL THEN CodUser ELSE @CodUser END),
                    @Expira = (CASE WHEN @Expira IS NULL THEN Expira ELSE @Expira END)
                FROM @Dupli;
        
                IF (@DupDuplica=1)
                BEGIN
                    UPDATE master.dbo.infraPermisosTemp
                    SET Revocado = GETDATE(),
                        Estado = 'REVOCADO',
                        Observacion = 'FORZADO-ANTES-DE-ASIGNAR'
                    WHERE IdPermiso= @IdPermiso;
                END;
            END
            ELSE
            BEGIN 
                INSERT INTO @Dupli(Duplicado) VALUES (0);
                SET @DupDuplica = 0;
            END

            -- EXEC master.dbo.sp_infra_asignar_permiso_temporal @Usuario, @TipoAcceso, @nomBaseDatos, @DuracionHoras, @Expira, @NumReg, @CodUser, @DupDuplica, @idPermiso;
            INSERT INTO @Tmp
            EXEC master.dbo.sp_infra_asignar_permiso_temporal 
                        @Usuario = @Usuario, @TipoAcceso = @TipoAcceso, @BaseDatos = @nomBaseDatos, 
                        @DuracionHoras = @DuracionHoras, @Expira = @Expira, @NumReg = @NumReg, 
                        @CodUser = @CodUser, @DupDuplica = @DupDuplica, @IdPermiso = @IdPermiso;
            SELECT * FROM @Tmp;
            RETURN;
        END
        -- Caso 2: Aplicar a múltiples bases administradas
        IF @BaseDatos IS NOT NULL AND EXISTS(SELECT 1 FROM infraBasesGestionadas WHERE idAdminFidens = @BaseDatos AND Estado=1)
        BEGIN;
            --SELECT @nomBaseDatos = BaseDatos FROM infraBasesGestionadas WHERE idAdminFidens = @BaseDatos AND Estado=1;
            --PRINT @nomBaseDatos;
            --IF (@nomBaseDatos IS NOT NULL)
            --BEGIN
                DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
                    SELECT BaseDatos FROM infraBasesGestionadas WHERE idAdminFidens = @BaseDatos AND Estado=1;
                OPEN cur;
                FETCH NEXT FROM cur INTO @nomBaseDatos;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    DELETE FROM @Dupli;
                    INSERT INTO @Dupli (Duplicado, NumReg, CodUser, Est, Expira, Usuario, TipoAcceso, idBaseDatos, BaseDatos, idPermiso)
                    EXEC dbo.sp_infra_duplicado_permiso_temporal @Usuario = @Usuario, @TipoAcceso = @TipoAcceso, @BaseDatos = NULL, @nomBD = @nomBaseDatos;

                    IF (EXISTS( SELECT 1 FROM @Dupli))
                    BEGIN
                        DECLARE @nomBdDupli SYSNAME; 
                        SELECT TOP 1 @DupDuplica=Duplicado, @IdPermiso = idPermiso, @nomBdDupli = BaseDatos,
                            @NumReg = (CASE WHEN @NumReg IS NULL THEN NumReg ELSE @NumReg END),
                            @CodUser = (CASE WHEN @CodUser IS NULL THEN CodUser ELSE @CodUser END),
                            @Expira = (CASE WHEN @Expira IS NULL THEN Expira ELSE @Expira END)
                        FROM @Dupli;
                        --PRINT CAST(@nomBdDupli AS VARCHAR(128)) + " " +CAST(@nomBaseDatos AS VARCHAR(128));
                        IF (@DupDuplica=1)
                        BEGIN
                            UPDATE master.dbo.infraPermisosTemp
                            SET Revocado = GETDATE(),
                                Estado = 'REVOCADO',
                                Observacion = 'FORZADO-ANTES-DE-ASIGNAR'
                            WHERE IdPermiso= @IdPermiso;
                        END;
                    END
                    ELSE
                    BEGIN 
                        INSERT INTO @Dupli(Duplicado) VALUES (0);
                        SET @DupDuplica = 0;
                    END;

                    INSERT INTO @Tmp
                    EXEC master.dbo.sp_infra_asignar_permiso_temporal 
                        @Usuario = @Usuario, @TipoAcceso = @TipoAcceso, @BaseDatos = @nomBaseDatos, 
                        @DuracionHoras = @DuracionHoras, @Expira = @Expira, @NumReg = @NumReg, 
                        @CodUser = @CodUser, @DupDuplica = @DupDuplica, @IdPermiso = @IdPermiso;

                    FETCH NEXT FROM cur INTO @nomBaseDatos;
                END
                CLOSE cur;
                DEALLOCATE cur;                
            --END
        END
        SELECT * FROM @Tmp;
    END TRY
    BEGIN CATCH
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
        RETURN -1;
    END CATCH
END