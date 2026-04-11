USE master;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.sp_infra_duplicado_permiso_temporal') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_duplicado_permiso_temporal;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-03-06
-- Description:	Para todos los servidores 2008/2012/2019+
-- Valida si NO Existe el usuario retorna -1
-- Si no existe la base retorna -2
-- Si ya existe el permiso retorna 1
-- Si el permiso se puede asignar sin problemas retorna todos 0
-- Puede retornar varios registros si existen varias bases con el mismo codigo asignado
-- EXEC dbo.sp_infra_duplicado_permiso_temporal 'ecordova', 'RWSP', NULL, 'DERCO_CORREDOR';
-- EXEC dbo.sp_infra_duplicado_permiso_temporal 'ecordova', 'RWSP', 50, 'DERCO_CORREDOR';
-- EXEC dbo.sp_infra_duplicado_permiso_temporal 'ecordova', 'RWSP', 50, NULL;
-- EXEC dbo.sp_infra_duplicado_permiso_temporal 'mvasquez', 'RW', NULL, 'AutomovilClub';
-- EXEC dbo.sp_infra_duplicado_permiso_temporal 'mvasquez', 'RW', 117, NULL;
-- SELECT TOP 20 * FROM dbo.infraPermisosTemp ORDER BY IdPermiso DESC
-- UPDATE dbo.infraPermisosTemp SET Expira = '2026-03-08 16:30' WHERE IdPermiso IN (237, 238);
-- UPDATE dbo.infraPermisosTemp SET Estado='ASIGNADO', Expira = '2026-03-09 15:20', Revocado=NULL, Observacion=NULL WHERE IdPermiso IN (237, 238);
-- DELETE FROM dbo.infraPermisosTemp WHERE IdPermiso IN (241, 242);
-- =============================================
CREATE PROCEDURE dbo.sp_infra_duplicado_permiso_temporal
    @Usuario SYSNAME,
    @TipoAcceso VARCHAR(20),    -- PERMISO, SERVER_ROLE, DB_ROLE -- R, W, RW, RWSP, SP, SM, RWSM, JOB, SYS, PRF
    @BaseDatos INT = NULL,              -- Null si es permiso de servidor JOB, PRF o SYS
    @nomBD SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ENABLE INT;
    DECLARE @fcreate DATETIME;
    DECLARE @fmodify DATETIME;
    DECLARE @Duplicado INT = 0;
    DECLARE @nomBaseDatos SYSNAME;
    DECLARE @Tmp TABLE (
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
    DECLARE @Rol VARCHAR(100);
    DECLARE @TipoAsignacion VARCHAR(50);
    DECLARE @PermisoAsignado VARCHAR(200);

    SELECT @fcreate = create_date,
    @fmodify = modify_date,
    @ENABLE = is_disabled
    FROM sys.server_principals
    WHERE name = @Usuario -- ejemplo: 'gchavez'
        AND type IN ('S', 'U'); -- SQL Login / Windows Login

    IF (@ENABLE IS NULL)
    BEGIN
        --PRINT N'USUARIO NO EXISTE REGISTRADO EN EL SERVIDOR, REVISAR USUARIO ' + CAST(@Usuario AS NVARCHAR(128));
        INSERT INTO @Tmp (Duplicado) VALUES (-1);
        SELECT * FROM @Tmp;
        RETURN;
    END;
    IF (NOT EXISTS(SELECT 1    
                    FROM infraBasesGestionadas 
                    WHERE Estado=1 
                    AND (
                idAdminFidens = @BaseDatos
             OR (@BaseDatos IS NULL AND BaseDatos = @nomBD)
            )))
    BEGIN
        --PRINT N'USUARIO EXISTE REGISTRADO EN EL SERVIDOR, REVISAR USUARIO ' + CAST(@Usuario AS NVARCHAR(128));
        INSERT INTO @Tmp (Duplicado) VALUES (-2);
        SELECT * FROM @Tmp;
        RETURN;
    END;
    -- SELECT @nomBaseDatos = BaseDatos FROM infraBasesGestionadas WHERE idAdminFidens = @BaseDatos AND Estado=1;
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

    -- Caso 1: Permiso de servidor: JOB o PRF
    IF (@TipoAcceso='JOB' OR @TipoAcceso='PRF' OR @TipoAcceso='ALL')
    BEGIN        
        SELECT @nomBaseDatos = BaseDatos
        FROM infraBasesGestionadas
        WHERE Estado = 1
        AND (
                idAdminFidens = @BaseDatos
             OR (@BaseDatos IS NULL AND BaseDatos = @nomBD)
            );
        IF (EXISTS( SELECT 1
                    FROM master.dbo.infraPermisosTemp
                    WHERE Usuario = @Usuario
                        AND TipoAsignacion = @TipoAsignacion
                        AND PermisoAsignado = @PermisoAsignado
                        AND Estado = 'ASIGNADO'
                    ))
        BEGIN
            INSERT INTO @Tmp (Duplicado, NumReg, CodUser, Est, Expira, Usuario, TipoAcceso, idBaseDatos, BaseDatos, idPermiso)
            SELECT 1, NumReg, CodUser, Estado, Expira, Usuario, @TipoAcceso, @BaseDatos, BaseDatos, idPermiso 
            FROM master.dbo.infraPermisosTemp
            WHERE Usuario = @Usuario
                AND TipoAsignacion = @TipoAsignacion
                AND PermisoAsignado = @PermisoAsignado
                AND Estado = 'ASIGNADO'
                AND (BaseDatos = @nomBaseDatos OR BaseDatos IS NULL)
        END
        ELSE
        BEGIN
            INSERT INTO @Tmp (Duplicado) VALUES (0);
        END;
        SELECT * FROM @Tmp;
        RETURN;
    END
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT BaseDatos FROM infraBasesGestionadas 
        WHERE Estado=1 
        AND (
                idAdminFidens = @BaseDatos
             OR (@BaseDatos IS NULL AND BaseDatos = @nomBD)
            );
    OPEN cur;
    FETCH NEXT FROM cur INTO @nomBaseDatos;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF (EXISTS( SELECT 1
                    FROM master.dbo.infraPermisosTemp
                    WHERE Usuario = @Usuario
                        AND TipoAsignacion = @TipoAsignacion
                        AND PermisoAsignado = @PermisoAsignado
                        AND Estado = 'ASIGNADO'
                        AND (BaseDatos = @nomBaseDatos OR BaseDatos IS NULL) ))
        BEGIN            
            INSERT INTO @Tmp (Duplicado, NumReg, CodUser, Est, Expira, Usuario, TipoAcceso, idBaseDatos, BaseDatos, idPermiso)
            SELECT 1, NumReg, CodUser, Estado, Expira, Usuario, @TipoAcceso, @BaseDatos, BaseDatos, idPermiso 
            FROM master.dbo.infraPermisosTemp
            WHERE Usuario = @Usuario
                AND TipoAsignacion = @TipoAsignacion
                AND PermisoAsignado = @PermisoAsignado
                AND Estado = 'ASIGNADO'
                AND (BaseDatos = @nomBaseDatos OR BaseDatos IS NULL)
        END
        ELSE
        BEGIN
            INSERT INTO @Tmp (Duplicado) VALUES (0);
        END;
        FETCH NEXT FROM cur INTO @nomBaseDatos;
    END
    CLOSE cur;
    DEALLOCATE cur;
    SELECT * FROM @Tmp;
END
GO