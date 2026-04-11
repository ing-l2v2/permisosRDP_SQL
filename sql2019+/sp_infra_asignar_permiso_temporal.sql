USE master;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.sp_infra_asignar_permiso_temporal') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_asignar_permiso_temporal;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-14
-- Description:	Iniciar permisos a la base de datos para usuarios en servidores 2019+
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
CREATE PROCEDURE dbo.sp_infra_asignar_permiso_temporal
    @Usuario SYSNAME,
    @TipoAcceso VARCHAR(20),   -- PERMISO, SERVER_ROLE, DB_ROLE -- R, W, RW, RWSP, SP, SM, RWSM, JOB, SYS, PRF
    -- @Permiso VARCHAR(200),         -- Ej: 'ALTER TRACE', 'SELECT', 'EXECUTE'    
    @BaseDatos SYSNAME = NULL,     -- Null si es permiso de servidor JOB, PRF o SYS
    @DuracionHoras INT = 48,        -- Por defecto 48h
    @Expira DATETIME = NULL,
    @NumReg INT = NULL,
    @CodUser VARCHAR(5) = NULL,
    @DupDuplica INT = NULL,
    @IdPermiso INT = NULL
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
        IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'infraPermisosTemp')
        BEGIN
            CREATE TABLE dbo.infraPermisosTemp (
                IdPermiso        INT IDENTITY(1,1) PRIMARY KEY,
                Usuario          SYSNAME       NOT NULL,
                TipoAsignacion   VARCHAR(50)   NOT NULL,  -- 'PERMISO', 'ROL', 'DB_ROLE'  -- R, W, RW, RWSP, SP, SM, RWSM, JOB, SYS, PRF
                PermisoAsignado  VARCHAR(200)  NOT NULL,  -- Ej: 'ALTER TRACE', 'GRANT SELECT', 'EXECUTE ON SP'
                BaseDatos        SYSNAME       NULL,      -- NULL = permiso a nivel de servidor
                Asignacion       DATETIME      NOT NULL DEFAULT(GETDATE()),
                Expira           DATETIME      NOT NULL,  -- normalmente 48h después
                Estado           VARCHAR(20)   NOT NULL DEFAULT('ASIGNADO'), -- 'ASIGNADO', 'REVOCADO', 'ERROR'
                Revocado         DATETIME      NULL,
                Observacion      VARCHAR(500)  NULL,
                NumReg           INT      NULL,
                CodUser          VARCHAR(5) NULL
            );            
            ------------------------------------------------------------
            -- ÍNDICES ÚTILES
            ------------------------------------------------------------
            CREATE INDEX IX_infraPermisosTemp_Estado
                ON dbo.infraPermisosTemp (Estado);

            CREATE INDEX IX_infraPermisosTemp_Expira
                ON dbo.infraPermisosTemp (Expira);
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
                WHEN @TipoAcceso IN ('JOB', 'ALL') THEN 'SERVER_ROLE'
                WHEN @TipoAcceso IN ('PRF') THEN 'PERMISO'                
                WHEN @Rol IS NOT NULL AND @TipoAcceso NOT IN ('JOB', 'ALL', 'PRF') THEN 'DB_ROLE'
            END;
        SET @PermisoAsignado = 
            CASE 
                WHEN @TipoAcceso = 'JOB' THEN 'SQLAgentOperatorRole'
                WHEN @TipoAcceso = 'PRF' THEN 'ALTER TRACE'
                WHEN @TipoAcceso = 'ALL' THEN 'sysadmin'
                WHEN @Rol IS NOT NULL AND @TipoAcceso NOT IN ('JOB', 'ALL', 'PRF') THEN @Rol
            END;

        --------------------------------------------------------------------
        -- REVOKE ANTES DE ASIGNAR SI EXISTE UN PERMISO ACTIVO
        --------------------------------------------------------------------
        /*
        SELECT @IdBase=idAdminFidens
            FROM dbo.infraBasesGestionadas
            WHERE Estado = 1
            AND (
                    idAdminFidens = @BaseDatos
                 OR (@BaseDatos IS NULL AND BaseDatos = @BaseDatos)
                );
        */
        IF (@DupDuplica = 1 AND @IdPermiso IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.infraPermisosTemp WHERE IdPermiso = @IdPermiso))
        BEGIN
            UPDATE master.dbo.infraPermisosTemp
            SET Revocado = GETDATE(),
                Estado = 'REVOCADO',
                Observacion = 'FORZADO-ANTES-DE-ASIGNAR'
            WHERE IdPermiso= @IdPermiso;

            DECLARE @tmNumReg INT;
            SELECT TOP 1 @tmNumReg = NumReg FROM master.dbo.infraPermisosTemp WHERE IdPermiso= @IdPermiso;
            IF @tmNumReg IS NOT NULL
            BEGIN
                DELETE FROM dbo.infraPermisosProcesadosProyFidens WHERE NumReg = @tmNumReg AND Procesado = 1;
            END;
        END;
        ELSE IF (@DupDuplica = 0)
        BEGIN
            ------------------------------------------------------------
            -- ASIGNACION REAL DEL PERMISO
            -- 1. Server-level permissions: JOB, PRF, ALL
            ------------------------------------------------------------        
            IF @TipoAcceso = 'ALL'
            BEGIN
                SET @Sql = N'ALTER SERVER ROLE [sysadmin] ADD MEMBER [' + @Usuario + ']';
                EXEC(@Sql);
                GOTO RegistrarPermiso;
            END
            IF @TipoAcceso = 'JOB'
            BEGIN
                SET @Sql = N'
                    USE msdb;
                    IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name = '''+@Usuario+N''')
                       CREATE USER ['+@Usuario+N'] FOR LOGIN ['+@Usuario+N'];

                    ALTER ROLE [SQLAgentOperatorRole] ADD MEMBER [' + @Usuario + ']
                ';
                EXEC(@Sql);
                GOTO RegistrarPermiso;
            END
            IF @TipoAcceso = 'PRF'
            BEGIN
                SET @Sql = N'GRANT ALTER TRACE TO [' + @Usuario + ']';
                EXEC(@Sql);
                GOTO RegistrarPermiso;
            END
            ------------------------------------------------------------
            -- 2. Database-level role assignment. Caso DB_ROLE
            ------------------------------------------------------------
            IF @Rol IS NOT NULL
            BEGIN
                --------------------------------------------------------
                -- 1. Crear roles si no existen
                --------------------------------------------------------
                EXEC master.dbo.sp_infra_crear_roles_por_defecto @BaseDatos;

                DECLARE @SqlUser NVARCHAR(MAX) = '
                USE [' + @BaseDatos + '];
                IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''' + @Usuario + ''')
                BEGIN
                    CREATE USER [' + @Usuario + '] FOR LOGIN [' + @Usuario + '];
                END
                ALTER USER ['+ @Usuario +'] WITH LOGIN = ['+ @Usuario +'];
                ALTER ROLE [' + @Rol + '] ADD MEMBER [' + @Usuario + '];
                ';
                EXEC(@SqlUser);            
                GOTO RegistrarPermiso;
            END
            ELSE
            BEGIN
                RAISERROR('Rol no reconocido.',16,1);
                RETURN -2;
            END;
        END;

    --------------------------------------------------------------------
    -- INSERTAR NUEVO PERMISO TEMPORAL
    --------------------------------------------------------------------
RegistrarPermiso:
    DECLARE @ipEntra INT;

    SELECT @ipEntra = HABILITADO FROM ValidIPAddressRange WHERE USER_LOGIN=@Usuario AND IP='10.253.253';    
    IF (@ipEntra IS NULL)
    BEGIN
        INSERT INTO ValidIPAddressRange
        (USER_LOGIN, IP, HABILITADO)        
        SELECT @Usuario, '10.253.253', 1;
    END
    ELSE
    BEGIN
        UPDATE ValidIPAddressRange
        SET HABILITADO=1
        WHERE USER_LOGIN = @Usuario AND IP='10.253.253'
    END

    INSERT INTO master.dbo.infraPermisosTemp
    (Usuario, TipoAsignacion, PermisoAsignado, BaseDatos, CodUser, NumReg, Expira)
    OUTPUT INSERTED.IdPermiso INTO @NuevoId
    SELECT @Usuario, @TipoAsignacion, @PermisoAsignado, @BaseDatos, @CodUser, @NumReg,
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
     
        EXEC dbo.sp_infra_login_estado_usuario @LoginName = @Usuario;

        SELECT @IdSalida = Id FROM @NuevoId;
        --------------------------------------------------------------------
        -- *** ÚNICO RESULTADO FINAL ***
        --------------------------------------------------------------------
        SELECT NumReg, CodUser, Estado AS Est, CONVERT(VARCHAR(16), Expira, 120) As FechaFin, BaseDatos AS BaseDatos, IdPermiso 
        FROM dbo.infraPermisosTemp 
        WHERE IdPermiso = @IdSalida;
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
