/*
    UPDATE infraPermisosTemp SET Asignacion='2026-02-11 15:00', Expira = '2026-02-12 10:00' WHERE IdPermiso IN (10);
    SELECT * FROM infraPermisosTemp WHERE Estado = 'ASIGNADO';
    SELECT * FROM infraPermisosTemp WHERE Estado = 'REVOCADO';
    EXEC sp_infra_revocar_permisos_expirados;
    DELETE FROM infraPermisosTemp WHERE Estado = 'ERROR';
*/
USE master;
GO

IF OBJECT_ID('dbo.sp_infra_revocar_permisos_expirados') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_revocar_permisos_expirados;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-14
-- Description:	Quitar o revocar masivamente los permisos expirados para los usuario en servidores 2008
-- =============================================
CREATE PROCEDURE dbo.sp_infra_revocar_permisos_expirados
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Id INT,
            @Usuario SYSNAME,
            @Tipo VARCHAR(50),
            @Permiso VARCHAR(200),
            @DB SYSNAME,
            @Sql NVARCHAR(MAX);

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT IdPermiso, Usuario, TipoAsignacion, PermisoAsignado, BaseDatos
        FROM master.dbo.infraPermisosTemp
        WHERE Estado = 'ASIGNADO'
          AND Expira <= GETDATE();

    OPEN cur;
    FETCH NEXT FROM cur INTO @Id, @Usuario, @Tipo, @Permiso, @DB;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        ------------------------------------------------------------
        -- Determinar sentencia de revocación
        ------------------------------------------------------------
        IF @Tipo = 'PERMISO' AND @Permiso = 'ALTER TRACE'   -- AND @DB IS NULL
        BEGIN            
            SET @Sql = N'REVOKE ' + @Permiso + N' FROM [' + @Usuario + N']';
        END
        -- Permiso a nivel de base de datos
--        ELSE IF @Tipo = 'PERMISO' AND @DB IS NOT NULL
--        BEGIN
--            SET @Sql = N'USE [' + @DB + N']; REVOKE ' + @Permiso + N' FROM [' + @Usuario + N']';            
--        END
        -- Rol de servidor → NO soportado en SQL 2008
        ELSE IF @Tipo = 'SERVER_ROLE'
        BEGIN
            IF @Permiso = 'sysadmin'
            BEGIN
                SET @Sql = N'EXEC master..sp_dropsrvrolemember @loginame='''+@Usuario+N''', @rolename='''+@Permiso+''';';  -- NO se puede ejecutar            
            END
            ELSE IF @Permiso = 'SQLAgentOperatorRole'
            BEGIN
                SET @Sql = N'
                   USE msdb;
                   EXEC msdb..sp_droprolemember '''+@Permiso+N''', '''+ @Usuario+''';';  -- NO se puede ejecutar
            END
        END
        -- Rol de base de datos → reemplazar "DROP MEMBER" por sp_droprolemember
        ELSE IF @Tipo = 'DB_ROLE'
        BEGIN
            SET @Sql = N'
                USE [' + @DB + N'];
                EXEC sp_droprolemember ''' + @Permiso + ''',''' + @Usuario + ''';
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

            UPDATE master.dbo.infraPermisosTemp
            SET Estado = 'REVOCADO',
                Revocado = GETDATE(),
                Observacion = LTRIM(RTRIM(
                  @Sql +' '+ ISNULL(Observacion,'')
                ))
            WHERE IdPermiso = @Id;
        END TRY
        BEGIN CATCH
            UPDATE master.dbo.infraPermisosTemp
            SET Estado = 'ERROR',
                Observacion = LTRIM(RTRIM(
                    ERROR_MESSAGE() +' '+ ISNULL(Observacion, '')
                ))
            WHERE IdPermiso = @Id;
        END CATCH
        EXEC master.dbo.sp_infra_login_estado_usuario @LoginName = @Usuario;

        FETCH NEXT FROM cur INTO @Id, @Usuario, @Tipo, @Permiso, @DB;
    END

    CLOSE cur;
    DEALLOCATE cur;
END
GO
