/*
    EXEC sp_infra_ini_asignar_permiso_temporal 'eavalos', 'RWSP', 50, 48, '2026-03-04 04:10', NULL, NULL;

    EXEC sp_infra_ini_asignar_permiso_temporal 'eavalos', 'JOB', 50, 48, '2026-03-04 04:10', NULL, NULL;
    EXEC sp_infra_ini_revocar_permiso_unitario 'eavalos', 'RWSP', 50;
    EXEC sp_infra_ini_revocar_permiso_unitario 'eavalos', 'JOB', 50;
    EXEC sp_infra_ini_asignar_permiso_temporal
    @Usuario = 'larroba',
    @TipoAcceso = 'RW',
    @BaseDatos = 111,
    @DuracionHoras = 48,
    @Expira = '2026-02-28 11:00',
    @NumReg = 16794,
    @CodUser = '00137';

    EXEC sp_infra_ini_asignar_permiso_temporal 'MCOBOS', 'RWSP', 22, 48;
    EXEC sp_infra_ini_asignar_permiso_temporal 'MCOBOS', 'RWSP', 20, 48;
    EXEC sp_infra_ini_asignar_permiso_temporal 'cberruz', 'RWSP', 92, 48;
    EXEC sp_infra_ini_asignar_permiso_temporal 'eavalos', 'RWSP', 50, 48;
    EXEC sp_infra_ini_asignar_permiso_temporal 'gchavez', 'RWSP', 22, 48;
    SELECT * FROM infraPermisosTemp WHERE Estado = 'ASIGNADO';
    SELECT * FROM infraPermisosTemp WHERE Estado = 'REVOCADO';
    SELECT * FROM infraPermisosTemp WHERE Estado = 'ERROR';
    SELECT * FROM infraBasesGestionadas;
    UPDATE infraPermisosTemp SET Expira='2026-02-20 11:31:10' WHERE IdPermiso=6

    UPDATE infraBasesGestionadas SET idAdminFidens=114 WHERE idBase=3;
    UPDATE infraBasesGestionadas SET idAdminFidens=50 WHERE idBase=2;
    UPDATE infraBasesGestionadas SET idAdminFidens=50 WHERE idBase=3;
    UPDATE infraBasesGestionadas SET idAdminFidens=97 WHERE idBase=4;
    UPDATE infraBasesGestionadas SET idAdminFidens=20 WHERE idBase=6;
    UPDATE infraBasesGestionadas SET idAdminFidens=51 WHERE idBase=7;
    UPDATE infraBasesGestionadas SET idAdminFidens=19 WHERE idBase=8;
    UPDATE infraBasesGestionadas SET idAdminFidens=8 WHERE idBase=9;

    UPDATE infraBasesGestionadas SET Estado=0 WHERE idBase IN (1,2);

    sp_help 'sp_infra_ini_asignar_permiso_temporal';
*/
USE master;
GO

IF OBJECT_ID('dbo.sp_infra_ini_asignar_permiso_temporal') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_ini_asignar_permiso_temporal;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-14
-- Description:	Iniciar permisos a la base de datos para usuarios en servidores 2008 / 2012
-- =============================================
CREATE PROCEDURE dbo.sp_infra_ini_asignar_permiso_temporal
    @Usuario        SYSNAME,
    @TipoAcceso     VARCHAR(20),   -- PERMISO, SERVER_ROLE, DB_ROLE -- R, W, RW, RWSP, SP, SM, RWSM, JOB, SYS, PRF
    -- @Permiso     VARCHAR(200),         -- Ej: 'ALTER TRACE', 'SELECT', 'EXECUTE'    
    @BaseDatos      INT = NULL,     -- Null si es permiso de servidor JOB o PRF
    @DuracionHoras  INT = 49,        -- Por defecto 48h
    @Expira         DATETIME = NULL,
    @NumReg         INT = NULL,
    @CodUser        VARCHAR(5) = NULL    
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @nomBaseDatos SYSNAME;
    DECLARE @IdPermiso      INT;
    
    DECLARE @Tmp TABLE (
        NumReg INT,
        CodUser VARCHAR(5),
        Est VARCHAR(20),
        FechaFin VARCHAR(16),
        BaseDatos SYSNAME
    );
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
        WHERE d.name NOT IN ('master','model','msdb','tempdb','ReportServerTempDB')
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
        SELECT -2 AS NumReg, @CodUser AS CodUser, 'ERROR' AS Est, NULL AS FechaFin;
        RETURN;
    END;
    -- Caso 1: Permiso de servidor: JOB o PRF
    IF (@TipoAcceso='JOB' OR @TipoAcceso='ALL' OR @TipoAcceso='PRF')
    BEGIN
        SELECT TOP 1 @nomBaseDatos = BaseDatos FROM infraBasesGestionadas WHERE idAdminFidens = @BaseDatos AND Estado=1 ORDER BY BaseDatos ASC;
        -- INSERT INTO @Tmp
        EXEC master.dbo.sp_infra_asignar_permiso_temporal @Usuario, @TipoAcceso, @nomBaseDatos, @DuracionHoras, @Expira, @NumReg, @CodUser, @IdPermiso;
        --SELECT * FROM @Tmp;
        SELECT NumReg, CodUser, Estado AS Est, Expira AS FechaFin, BaseDatos FROM infraPermisosTemp WHERE IdPermiso = @IdPermiso;
        RETURN
    END
    IF @BaseDatos IS NOT NULL AND EXISTS(SELECT 1 FROM infraBasesGestionadas WHERE idAdminFidens = @BaseDatos AND Estado=1)
    BEGIN        
        --SELECT @nomBaseDatos = BaseDatos FROM infraBasesGestionadas WHERE idAdminFidens = @BaseDatos AND Estado=1;
        --RAISERROR(@nomBaseDatos, 0, 1) WITH NOWAIT;
        --IF (@nomBaseDatos IS NOT NULL)
        --BEGIN
            DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT BaseDatos FROM infraBasesGestionadas WHERE idAdminFidens = @BaseDatos AND Estado=1;
            OPEN cur;
            FETCH NEXT FROM cur INTO @nomBaseDatos;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                --INSERT INTO @Tmp
                EXEC master.dbo.sp_infra_asignar_permiso_temporal @Usuario, @TipoAcceso, @nomBaseDatos, @DuracionHoras, @Expira, @NumReg, @CodUser, @IdPermiso;
                FETCH NEXT FROM cur INTO @nomBaseDatos;
            END
            CLOSE cur;
            DEALLOCATE cur;
        --END
    END
    --SELECT * FROM @Tmp;
    -- PRINT @IdPermiso;
    SELECT NumReg, CodUser, Estado AS Est, Expira AS FechaFin, BaseDatos FROM infraPermisosTemp WHERE IdPermiso = @IdPermiso;
END