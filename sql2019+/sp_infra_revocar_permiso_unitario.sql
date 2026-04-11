/*
    UPDATE infraPermisosTemp SET Asignacion='2026-02-11 15:00', Expira = '2026-02-12 10:00' WHERE IdPermiso IN (3,4);
    SELECT * FROM infraPermisosTemp WHERE Estado = 'ASIGNADO';
    EXEC sp_infra_revoca_permiso_unitario mvasquez, RWSP, Banmedica;
    EXEC master.dbo.sp_infra_asignar_permiso_temporal 'mvasquez', 'RWSP', 'Banmedica';
    DELETE FROM infraPermisosTemp WHERE idPermiso IN (11,12,13)
*/
USE master;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.sp_infra_revoca_permiso_unitario') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_revoca_permiso_unitario;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-14
-- Description:	Quitar o revocar los permisos expirados para un usuario en particular en servidores 2019+
-- =============================================
CREATE PROCEDURE dbo.sp_infra_revoca_permiso_unitario
    @Usuario SYSNAME,
    @TipoAcceso VARCHAR(20),   -- PERMISO, SERVER_ROLE, DB_ROLE -- R, W, RW, RWSP, SP, SM, RWSM, JOB, SYS, PRF, ALL
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
        WHERE Estado = 'ASIGNADO'
          AND Usuario = @Usuario
          AND TipoAsignacion = @TipoAsignacion
          AND ((@BaseDatos IS NULL AND BaseDatos IS NULL)
            OR  (@BaseDatos IS NOT NULL AND BaseDatos=@BaseDatos)
          );

    OPEN cur;
    FETCH NEXT FROM cur INTO @Id, @Usr, @Tipo, @Permiso, @DB;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        ------------------------------------------------------------
        -- Determinar sentencia de revocación
        ------------------------------------------------------------
        IF @Tipo = 'PERMISO' AND @Permiso = 'ALTER TRACE'    -- AND @DB IS NULL
            SET @Sql = N'REVOKE ' + @Permiso + N' FROM [' + @Usr + N']';

        ELSE IF @Tipo = 'SERVER_ROLE' AND @Permiso='sysadmin'
            SET @Sql = N'ALTER SERVER ROLE [' + @Permiso + '] DROP MEMBER [' + @Usr + ']';

        ELSE IF @Tipo = 'SERVER_ROLE' AND @Permiso='SQLAgentOperatorRole'
            SET @Sql = N'
                USE msdb;
                ALTER ROLE [' + @Permiso + '] DROP MEMBER [' + @Usr + ']
            ';
        ELSE IF @Tipo = 'DB_ROLE'
            SET @Sql = N'USE [' + @DB + ']; ALTER ROLE [' + @Permiso + '] DROP MEMBER [' + @Usr + ']';

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
            
            SET @IdPermiso = @Id;
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
        EXEC master.dbo.sp_infra_login_estado_usuario @LoginName = @Usr;

        FETCH NEXT FROM cur INTO @Id, @Usr, @Tipo, @Permiso, @DB;
    END

    CLOSE cur;
    DEALLOCATE cur;
    SELECT IdPermiso, Usuario, PermisoAsignado, BaseDatos, Expira, Estado, NumReg, CodUser FROM infraPermisosTemp WHERE IdPermiso=@IdPermiso;
END
GO


