/*
    UPDATE infraPermisosTemp SET Asignacion='2026-02-11 15:00', Expira = '2026-02-12 10:00' WHERE IdPermiso IN (3,4);
    SELECT * FROM infraPermisosTemp WHERE Estado = 'ASIGNADO';
    SELECT * FROM infraPermisosTemp WHERE Usuario = 'jarzolay' ORDER BY idPermiso DESC;
    EXEC sp_infra_revocar_permisos_expirados;
    DELETE FROM infraPermisosTemp WHERE idPermiso IN (11,12,13)
*/
USE master;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.sp_infra_revocar_permisos_expirados') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_revocar_permisos_expirados;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-14
-- Description:	Quitar o revocar masivamente los permisos expirados para usuarios en servidores 2019+
-- =============================================
CREATE PROCEDURE dbo.sp_infra_revocar_permisos_expirados
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Id INT,
            @Usuario SYSNAME,
            @Tipo VARCHAR(50),  -- Tipo de asignacion
            @Permiso VARCHAR(200),  -- Permiso asignado
            @DB SYSNAME,
            @Sql NVARCHAR(MAX);

    SELECT * FROM infraPermisosTemp
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
            SET @Sql = N'REVOKE ' + @Permiso + N' FROM [' + @Usuario + N']';

        -- ELSE IF @Tipo = 'PERMISO' AND @DB IS NOT NULL
        --    SET @Sql = N'USE [' + @DB + ']; REVOKE ' + @Permiso + N' FROM [' + @Usuario + N']';

        ELSE IF @Tipo = 'SERVER_ROLE' AND @Permiso='sysadmin'
            SET @Sql = N'ALTER SERVER ROLE [' + @Permiso + '] DROP MEMBER [' + @Usuario + ']';

        ELSE IF @Tipo = 'SERVER_ROLE' AND @Permiso = 'SQLAgentOperatorRole'
            SET @Sql = N'
                USE msdb;
                ALTER ROLE [' + @Permiso + '] DROP MEMBER [' + @Usuario + '];
            ';

        ELSE IF @Tipo = 'DB_ROLE'
            SET @Sql = N'USE [' + @DB + ']; ALTER ROLE [' + @Permiso + '] DROP MEMBER [' + @Usuario + ']';

        ELSE
            SET @Sql = NULL;

        ------------------------------------------------------------
        -- Ejecutar revocación si es válida
        ------------------------------------------------------------
        BEGIN TRY
            IF @Sql IS NOT NULL
                EXEC sys.sp_executesql @Sql;

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
                Revocado = GETDATE(),
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
