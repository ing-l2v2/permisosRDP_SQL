/*
    EXEC sp_infra_ini_asignar_permiso_temporal 'eavalos', 'ALL', 50, 48, '2026-03-04 23:00', NULL, NULL;
    EXEC sp_infra_ini_revocar_permiso_unitario 'eavalos', 'ALL', 50;
    EXEC sp_infra_ini_asignar_permiso_temporal 'cberruz', 'RWSP', 19, 48, '2026-03-04 01:18', NULL, NULL;
    EXEC sp_infra_ini_revocar_permiso_unitario 'mvasquez', 'ALL', 118;
    EXEC sp_infra_ini_revocar_permiso_unitario 'cberruz', 'RWSP', 19;
    
    UPDATE infraPermisosTemp SET Expira='2026-02-18 19:41:17' WHERE IdPermiso IN (40, 41)
    UPDATE infraPermisosTemp SET Expira='2026-02-20 10:32:40' WHERE IdPermiso IN (38, 39)
    SELECT * FROM infraPermisosTemp WHERE Estado = 'ASIGNADO';
    SELECT * FROM infraPermisosTemp WHERE Estado = 'REVOCADO';
    SELECT * FROM infraPermisosTemp WHERE Estado = 'ERROR';
    UPDATE infraPermisosTemp SET Estado = 'ASIGNADO' WHERE Estado = 'ERROR'
    SELECT * FROM infraBasesGestionadas;
    INSERT INTO infraBasesGestionadas (idAdminFidens, BaseDatos, Estado) VALUES (50, 'DERCO_CORREDOR', 1);
    UPDATE infraBasesGestionadas SET idAdminFidens = 92 WHERE idBase=5;
    TRUNCATE TABLE infraPermisosTemp;    
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

IF OBJECT_ID('dbo.sp_infra_ini_revocar_permiso_unitario') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_ini_revocar_permiso_unitario;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-14
-- Description:	Iniciar permisos a la base de datos para usuarios en servidores 2008|2012
/*
EXEC sp_infra_ini_revocar_permiso_unitario @Usuario = 'ecordova', @TipoAcceso = 'RWSP', @BaseDatos = 22;
SELECT TOP 20 * FROM infraPermisosTemp ORDER BY Expira DESC
UPDATE infraPermisosTemp SET Estado='ASIGNADO', Revocado=NULL, Observacion=NULL WHERE IdPermiso = 239;
*/
-- =============================================
CREATE PROCEDURE dbo.sp_infra_ini_revocar_permiso_unitario
    @Usuario SYSNAME,
    @TipoAcceso VARCHAR(20),   -- PERMISO, SERVER_ROLE, DB_ROLE -- R, W, RW, RWSP, SP, SM, RWSM, JOB, SYS, PRF, ALL
    -- @Permiso VARCHAR(200),         -- Ej: 'ALTER TRACE', 'SELECT', 'EXECUTE'    
    @BaseDatos INT = NULL     -- Null si es permiso de servidor JOB, PRF    
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @nomBaseDatos SYSNAME;
    DECLARE @Tmp TABLE (
        Id INT,
        Usuario SYSNAME,
        PermisoAsignado VARCHAR(200),
        BaseDatos SYSNAME,
        Expira DATETIME,
        Estado VARCHAR(20),
        NumReg int,
        CodUser VARCHAR(5)
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
            SELECT TOP 1 @nomBaseDatos = BaseDatos FROM infraBasesGestionadas WHERE idAdminFidens = @BaseDatos AND Estado=1 ORDER BY BaseDatos ASC;
            INSERT INTO @Tmp
            EXEC master.dbo.sp_infra_revoca_permiso_unitario @Usuario, @TipoAcceso, @nomBaseDatos;
            SELECT * FROM @Tmp;
            RETURN;
        END
        -- Caso 2: Aplicar a múltiples bases administradas
        IF @BaseDatos IS NOT NULL AND EXISTS(SELECT 1 FROM infraBasesGestionadas WHERE idAdminFidens = @BaseDatos AND Estado=1)
        BEGIN;
                DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
                    SELECT BaseDatos FROM infraBasesGestionadas WHERE idAdminFidens = @BaseDatos AND Estado=1;
                OPEN cur;
                FETCH NEXT FROM cur INTO @nomBaseDatos;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    INSERT INTO @Tmp
                    EXEC master.dbo.sp_infra_revoca_permiso_unitario @Usuario, @TipoAcceso, @nomBaseDatos;
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
GO
