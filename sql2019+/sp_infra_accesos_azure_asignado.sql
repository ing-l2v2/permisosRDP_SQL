USE master;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.sp_infra_accesos_azure') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_accesos_azure;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-14
-- Description:	Iniciar permisos a la base de datos para usuarios en servidor 49 para Azure
--    ALTER TABLE dbo.infraPermisosTemp
--      ADD CodUser VARCHAR(5) NULL;
--     EXEC sp_infra_asignar_permiso_temporal 'mvasquez', 'RW', 'AutomovilClub', 48, NULL, NULL, NULL;
--    SELECT TOP 50 * FROM infraPermisosTemp ORDER BY IdPermiso DESC;
--    SELECT * FROM infraBasesGestionadas;
--    UPDATE infraPermisosTemp SET Servidor = '10.0.0.49' WHERE IdPermiso IN (8,9,10,11,12,13)
--    Código	Significado	                    Tipo	        Acción SQL Server
--    R	    Lectura	                        DB_ROLE	        db_datareader
--    W	    Escritura	                    DB_ROLE	        db_datawriter
--    RW	    Lectura y Escritura	            DB_ROLE	        db_rw
--    SP	    Ejecución de SP	                DB_ROLE	        db_ejecutor
--    SM	    Ejecución + Modificación de SP	DB_ROLE	        db_modificar_sp
--    RWSP	Lectura + Escritura + SP	    DB_ROLE	        db_rwsp
--    RWSM	L+E + modificar SP	            DB_ROLE	        db_rwsp_upd
--    JOB	    Control de SQL Agent	        SERVER_ROLE	    SQLAgentOperatorRole
--    SYS	    Administrador BD	            DB_ROLE	        db_owner
--    PRF	    Permiso de Trace	            SERVER_PERMISSION	ALTER TRACE
--    ALL	    Administrador de Servidor	    SERVER_ROLE	    sysadmin
--  EXEC sp_infra_asignar_permiso_temporal @Usuario='mvasquez', @TipoAcceso='RW', @BaseDatos='AutomovilClub', @DuracionHoras=48, @Expira=NULL, @NumReg=NULL, @CodUser=NULL, @DupDuplica=1, @IdPermiso=178;
--  SELECT TOP 20 * FROM dbo.infraPermisosTemp ORDER BY IdPermiso DESC;
--  UPDATE dbo.infraPermisosTemp SET Estado='ASIGNADO', Revocado=NULL, Observacion = NULL WHERE IdPermiso IN (178,179);
--  DELETE FROM dbo.infraPermisosTemp WHERE IdPermiso IN (207, 208);
-- Servidores 2019+
-- =============================================
CREATE PROCEDURE dbo.sp_infra_accesos_azure
    @Servidor VARCHAR(128) = 'sql-ginger.database.windows.net',
    @Usuario VARCHAR(128),
    @TipoAcceso VARCHAR(20),   -- PERMISO, SERVER_ROLE, DB_ROLE -- R, W, RW, RWSP, SP, SM, RWSM, JOB, SYS, PRF
    -- @Permiso VARCHAR(200),         -- Ej: 'ALTER TRACE', 'SELECT', 'EXECUTE'    
    @BaseDatos VARCHAR(Max) = NULL,     -- Null si es permiso de servidor JOB, PRF o SYS
    @DuracionHoras INT = 48,        -- Por defecto 48h
    @Expira DATETIME = NULL,
    @NumReg INT = NULL,
    @CodUser VARCHAR(5) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Rol VARCHAR(100);
    DECLARE @Sql NVARCHAR(MAX);
    DECLARE @TipoAsignacion VARCHAR(50);
    DECLARE @PermisoAsignado VARCHAR(200);
    DECLARE @Id INT;
    DECLARE @revocaPrev INT = -1;
    DECLARE @NuevoId TABLE (Id INT);
    DECLARE @IdSalida INT;
    DECLARE @dupDuplica INT;
    DECLARE @IdPermiso INT;
    DECLARE @DuracionMaxima INT
    DECLARE @MaxDuracion INT = 48;
    DECLARE @MaxDuracionSac INT = 7*24;

    SET @DuracionMaxima = 
        CASE
            WHEN @Usuario IN ('jarzolay','mcobos','mvasquez','larroba','aaguilar')
                THEN @MaxDuracionSac 
            ELSE @MaxDuracion
        END; 

    BEGIN TRY
        ------------------------------------------------------------
        -- TABLA PARA CONTROL DE PERMISOS TEMPORALES
        ------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'infraAccesosAzure')
        BEGIN
            CREATE TABLE infraAccesosAzure(
                IdAzure          INT IDENTITY(1,1) PRIMARY KEY,
                Servidor         VARCHAR(100)  NOT NULL DEFAULT('sql-ginger.database.windows.net'),
                Usuario          VARCHAR(128)  NOT NULL,
                TipoAsignacion   VARCHAR(50)   NOT NULL,  -- 'PERMISO', 'ROL', 'DB_ROLE'  -- R, W, RW, RWSP, SP, SM, RWSM, JOB, SYS, PRF
                PermisoAsignado  VARCHAR(200)  NOT NULL,  -- Ej: 'ALTER TRACE', 'GRANT SELECT', 'EXECUTE ON SP'
                BaseDatos        VARCHAR(200)  NOT NULL,      -- NULL = permiso a nivel de servidor
                Asignacion       DATETIME      NOT NULL DEFAULT(GETDATE()),
                Expira           DATETIME      NOT NULL,  -- normalmente 48h después
                Estado           VARCHAR(20)   NOT NULL DEFAULT('ASIGNADO'), -- 'ASIGNADO', 'REVOCADO', 'ERROR'
                Revocado         DATETIME      NULL,
                Observacion      VARCHAR(500)  NULL,
                NumReg           INT      NULL,
                CodUser          VARCHAR(5) NULL,
                Ejecutar         VARCHAR(Max) NULL
            )
            ------------------------------------------------------------
            -- ÍNDICES ÚTILES
            ------------------------------------------------------------
            CREATE INDEX IX_infraAccesosAzureTemp_Expira_Estado
                ON dbo.infraAccesosAzure (Expira, Estado);

            CREATE INDEX IX_infraAccesosAzureTemp_ServUsrBdPermisoEstado
                ON dbo.infraAccesosAzure (Servidor, Usuario, BaseDatos, PermisoAsignado, Estado);

            CREATE INDEX IX_infraAccesosAzureTemp_NumReg
                ON dbo.infraAccesosAzure (NumReg);
        END    

        ------------------------------------------------------------
        -- MAPEO DE CÓDIGOS → ROLES O PERMISOS
        ------------------------------------------------------------
        SET @Rol = CASE @TipoAcceso
                       WHEN 'R'      THEN N'db_datareader'
                       WHEN 'W'      THEN N'db_datawriter'
                       WHEN 'RW'     THEN N'db_rw'
                       WHEN 'SP'     THEN N'db_ejecutor'
                       WHEN 'SM'     THEN N'db_modificar_sp'
                       WHEN 'RWSP'   THEN N'db_rwsp'
                       WHEN 'RWSM'   THEN N'db_rwsp_upd'
                       WHEN 'SYS'    THEN N'db_owner'
                       ELSE NULL
                   END;

        --------------------------------------------------------------------
        -- FUNCIÓN AUXILIAR: Revocar un permiso activo si existe
        --------------------------------------------------------------------
        SET @TipoAsignacion = 
            CASE                
                WHEN @TipoAcceso IN ('PRF') THEN 'PERMISO'
                WHEN @Rol IS NOT NULL AND @TipoAcceso NOT IN ('JOB', 'ALL', 'PRF') THEN 'DB_ROLE'
            END;
        SET @PermisoAsignado = 
            CASE                
                WHEN @TipoAcceso = 'PRF' THEN 'ALTER TRACE'                
                WHEN @Rol IS NOT NULL AND @TipoAcceso NOT IN ('JOB', 'ALL', 'PRF') THEN @Rol
            END;

        SELECT @DupDuplica = 1, @IdPermiso = IdAzure FROM dbo.infraAccesosAzure
        WHERE Servidor = @Servidor
        AND Usuario = @Usuario
        AND BaseDatos = @BaseDatos
        AND Estado = 'ASIGNADO'

        IF (@DupDuplica = 1 AND @IdPermiso IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.infraAccesosAzure WHERE IdAzure = @IdPermiso))
        BEGIN
            UPDATE master.dbo.infraAccesosAzure
            SET Revocado = GETDATE(),
                Estado = 'REVOCADO',
                Observacion = 'FORZADO-ANTES-DE-ASIGNAR'
            WHERE IdAzure= @IdPermiso;
        END;
    --------------------------------------------------------------------
    -- INSERTAR NUEVO PERMISO TEMPORAL
    --------------------------------------------------------------------
RegistrarPermiso:
    INSERT INTO master.dbo.infraAccesosAzure
    (Servidor, Usuario, TipoAsignacion, PermisoAsignado, BaseDatos, CodUser, NumReg, Expira)
    OUTPUT INSERTED.IdAzure INTO @NuevoId
    SELECT @Servidor, @Usuario, @TipoAsignacion, @PermisoAsignado, @BaseDatos, @CodUser, @NumReg,
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
        -- Caso 3: @Expira nula o inválida → usar @DuracionHoras máximo 49
        ELSE DATEADD(
                HOUR, 
                CASE 
                    WHEN @DuracionHoras IS NULL THEN @DuracionMaxima          -- por defecto
                    WHEN @DuracionHoras > @DuracionMaxima THEN @DuracionMaxima            -- limitar
                    ELSE @DuracionHoras 
                END,
                GETDATE()
             )
        END;     
     
        --EXEC dbo.sp_infra_login_estado_usuario @LoginName = @Usuario;

        SELECT @IdSalida = Id FROM @NuevoId;
        --------------------------------------------------------------------
        -- *** ÚNICO RESULTADO FINAL ***
        --------------------------------------------------------------------
        SELECT NumReg, CodUser, Estado AS Est, CONVERT(VARCHAR(16), Expira, 120) As FechaFin, BaseDatos AS BaseDatos, IdAzure 
        FROM dbo.infraAccesosAzure 
        WHERE IdAzure = @IdSalida;
        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @msg NVARCHAR(4000)=ERROR_MESSAGE();
        RAISERROR(@msg,16,1);
        RETURN -1;
    END CATCH
END
GO
-- EXEC sp_helptext 'sp_infra_asignar_permiso_temporal';
