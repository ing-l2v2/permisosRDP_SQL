/*
    UPDATE infraPermisosTemp SET Asignacion='2026-02-11 15:00', Expira = '2026-02-12 10:00' WHERE IdPermiso IN (10);
    SELECT * FROM infraPermisosTemp WHERE Estado = 'ASIGNADO';
    EXEC sp_infra_revoca_permiso_unitario 'jarzolay', 'ALL', 'RSA_RETAIL';
    DELETE FROM infraPermisosTemp WHERE Estado = 'ERROR';
    
*/
USE master;
GO

IF OBJECT_ID('dbo.sp_infra_revoca_permiso_unitario') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_revoca_permiso_unitario;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-14
-- Description:	Quitar o revocar permisos expirados para un usuario en servidores 2008
-- =============================================
CREATE PROCEDURE dbo.sp_infra_revoca_permiso_unitario
    @Usuario SYSNAME,
    @TipoAcceso VARCHAR(20),   -- PERMISO, SERVER_ROLE, DB_ROLE -- R, W, RW, RWSP, SP, SM, RWSM, JOB, SYS, PRF
    -- @Permiso VARCHAR(200),         -- Ej: 'ALTER TRACE', 'SELECT', 'EXECUTE'    
    @BaseDatos SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Rol AS VARCHAR(100);
    DECLARE @TipoAsignacion VARCHAR(50);
    DECLARE @PermisoAsignado VARCHAR(200);
    DECLARE @IdPermiso INT;
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

    DECLARE @Id INT,
            @Usr SYSNAME,
            @Tipo VARCHAR(50),
            @Permiso VARCHAR(200),
            @DB SYSNAME,
            @Sql NVARCHAR(MAX);


    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT IdPermiso, Usuario, TipoAsignacion, PermisoAsignado, BaseDatos
        FROM master.dbo.infraPermisosTemp
        WHERE Estado IN ('ASIGNADO','REVOCADO')
          AND Usuario = @Usuario
          AND TipoAsignacion = @TipoAsignacion
          AND ((@BaseDatos IS NULL AND BaseDatos IS NULL)
            OR  (@BaseDatos IS NOT NULL AND BaseDatos=@BaseDatos)
          )
        ORDER BY Estado ASC;

    OPEN cur;
    FETCH NEXT FROM cur INTO @Id, @Usr, @Tipo, @Permiso, @DB;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        ------------------------------------------------------------
        -- Determinar sentencia de revocación
        ------------------------------------------------------------
        IF @Tipo = 'PERMISO' AND @Permiso = 'ALTER TRACE'    -- AND @DB IS NULL
        BEGIN            
            SET @Sql = N'
            USE master;
            REVOKE ' + @Permiso + N' FROM [' + @Usr + N']';
        END
        -- Permiso a nivel de base de datos
--        ELSE IF @Tipo = 'PERMISO' AND @DB IS NOT NULL
--        BEGIN
--            SET @Sql = N'USE [' + @DB + N']; REVOKE ' + @Permiso + N' FROM [' + @Usr + N']';            
--        END
        -- Rol de servidor → NO soportado en SQL 2008
        ELSE IF @Tipo = 'SERVER_ROLE'
        BEGIN            
            IF @Permiso = 'sysadmin'
            BEGIN
                SET @Sql = N'EXEC master..sp_dropsrvrolemember '''+ @Permiso +''', '''+ @Usuario +'''';  -- NO se puede ejecutar            
            END
            ELSE IF @Permiso = 'SQLAgentOperatorRole'
            BEGIN
                SET @Sql = N'EXEC master..sp_droprolemember '''+ @Permiso +''', '''+ @Usuario +'''';  -- NO se puede ejecutar
            END
        END
        /*
        ELSE IF @Tipo = 'SERVER_ROLE'
        BEGIN
            SET @Sql = NULL;  -- NO se puede ejecutar            
        END
        */
        -- Rol de base de datos → reemplazar "DROP MEMBER" por sp_droprolemember
        ELSE IF @Tipo = 'DB_ROLE'
        BEGIN
            SET @Sql = N'
                USE [' + @DB + N'];
                EXEC sp_droprolemember ''' + @Permiso + ''',''' + @Usr + ''';
            ';
        END
        ELSE
        BEGIN
            SET @Sql = NULL;
        END

        ------------------------------------------------------------
        -- Ejecutar revocación si es válida
        ------------------------------------------------------------
        BEGIN TRY
            IF @Sql IS NOT NULL
                EXEC(@Sql);
            PRINT @Sql;
            UPDATE master.dbo.infraPermisosTemp
            SET Estado = 'REVOCADO',
                Revocado = GETDATE(),
                Observacion = LTRIM(RTRIM(
                  @Sql +' '+ ISNULL(Observacion,'')
                ))
            WHERE IdPermiso = @Id;

            SET @IdPermiso = @Id;
        END TRY
        BEGIN CATCH
            UPDATE master.dbo.infraPermisosTemp
            SET Estado = 'ERROR',
                Observacion = LTRIM(RTRIM(
                    ERROR_MESSAGE() +' '+ ISNULL(Observacion, '')
                ))
            WHERE IdPermiso = @Id;
        END CATCH
        EXEC master.dbo.sp_infra_login_estado_usuario @LoginName = @Usr;

        FETCH NEXT FROM cur INTO @Id, @Usr, @Tipo, @Permiso, @DB;
    END

    CLOSE cur;
    DEALLOCATE cur;
    SELECT IdPermiso, Usuario, PermisoAsignado, BaseDatos, Expira, Estado, NumReg, CodUser FROM infraPermisosTemp WHERE IdPermiso=@IdPermiso;
END
GO
