/*
    EXEC master.dbo.sp_infra_login_estado_usuario @LoginName = 'pvalle';
*/
USE master;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.sp_infra_login_estado_usuario') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_login_estado_usuario;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-14
-- Description:	Determinar si un usuario queda en estado Login habilitado y no para usuarios en servidores 2019+
CREATE PROCEDURE dbo.sp_infra_login_estado_usuario
(
    @LoginName SYSNAME
)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------------------
    -- 0. Validar login
    ---------------------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1
        FROM sys.server_principals
        WHERE name = @LoginName
          AND type IN ('S','U')
    )
    BEGIN
        RAISERROR('El login [%s] no existe.', 16, 1, @LoginName);
        RETURN;
    END
    ELSE
    BEGIN
        PRINT 'El Login existe::['+ @LoginName +']';
    END
    ---------------------------------------------------------------------
    -- 1. KILL sesiones SLEEPING del login
    ---------------------------------------------------------------------
    DECLARE @SPID INT;
    DECLARE curKILL CURSOR LOCAL FAST_FORWARD FOR
        SELECT session_id
        FROM sys.dm_exec_sessions
        WHERE login_name = @LoginName
          AND status = 'sleeping';   -- << SOLO matar sleeping
    OPEN curKILL;
    FETCH NEXT FROM curKILL INTO @SPID;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @cmd NVARCHAR(50) = 'KILL ' + CAST(@SPID AS NVARCHAR(10));
        PRINT 'Eliminando sesión sleeping: ' + CAST(@SPID AS NVARCHAR(10)) + @cmd;        
        BEGIN TRY
            EXEC(@cmd);
        END TRY
        BEGIN CATCH
            PRINT 'No se pudo eliminar sesión ' + CAST(@SPID AS NVARCHAR(10)) + ': ' + ERROR_MESSAGE();
        END CATCH;
        FETCH NEXT FROM curKILL INTO @SPID;
    END
    CLOSE curKILL;
    DEALLOCATE curKILL;

    ---------------------------------------------------------------------
    -- 2. Verificar si quedan sesiones activas (running / background)
    ---------------------------------------------------------------------
    DECLARE @TieneSesiones BIT = 0;
    SELECT @TieneSesiones =
        CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
    FROM sys.dm_exec_sessions
    WHERE login_name = @LoginName
      AND status IN ('running','background');  -- ya no sleeping

    ---------------------------------------------------------------------
    -- 3. Verificar si tiene permisos en alguna BD de usuario
    ---------------------------------------------------------------------
    DECLARE 
        @TienePermisos BIT = 0,
        @DB SYSNAME,
        @SQL NVARCHAR(MAX),
        @R BIT;
    DECLARE curDB CURSOR LOCAL FAST_FORWARD FOR
        SELECT name
        FROM sys.databases
        WHERE database_id > 4 AND state = 0;
    OPEN curDB;
    FETCH NEXT FROM curDB INTO @DB;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @LoginSID VARBINARY(85);
        SELECT @LoginSID = sid
        FROM sys.server_principals
        WHERE name = @LoginName;
        PRINT '@LoginSID: '+ sys.fn_varbintohexstr(@LoginSID);
        SET @R = 0;


        SET @SQL = '
            -- ========================================================
            DECLARE @res BIT = 0;
            -- Buscar si usuario existe en la BD
            /*
            IF EXISTS (
                SELECT 1 FROM [' + @DB + '].sys.database_principals
                -- WHERE sid = SUSER_SID(@Login)
                WHERE sid = @LoginSID
            ) SET @res = 1;
            */
            -- Buscar si pertenece al rol sysadmin
            IF EXISTS(SELECT IS_SRVROLEMEMBER(''sysadmin'', ''@Login''))
                SET @res = 1;

            -- Buscar si pertenece a ALTER TRACE
            IF EXISTS( SELECT 1 FROM sys.server_principals sp
                LEFT JOIN sys.server_permissions perm 
                    ON sp.principal_id = perm.grantee_principal_id
                WHERE perm.permission_name = ''ALTER TRACE''
                  AND sp.name = ''@Login'') SET @res = 1;

            -- Buscar si pertenece a SQLAgentOperatorRole por TipoAcceso JOB
            IF EXISTS( SELECT 1 FROM msdb.sys.database_role_members rm
                JOIN msdb.sys.database_principals r ON rm.role_principal_id = r.principal_id
                JOIN msdb.sys.database_principals m ON rm.member_principal_id = m.principal_id
                WHERE r.name = ''SQLAgentOperatorRole''
                AND m.name = ''@Login'') SET @res = 1;

            -- Buscar si usuario pertenece a algún Rol
            IF EXISTS (
                SELECT 1 
                FROM [' + @DB + '].sys.database_role_members rm
                JOIN [' + @DB + '].sys.database_principals miembro
                  ON miembro.principal_id = rm.member_principal_id
                -- WHERE dp.sid = SUSER_SID(@Login)
                WHERE miembro.sid = @LoginSID
            ) SET @res = 1;
            -- Buscar si usuario tiene permisos explícitos
            IF EXISTS (
                SELECT 1
                FROM [' + @DB + '].sys.database_permissions p
                JOIN [' + @DB + '].sys.database_principals dp
                  ON p.grantee_principal_id = dp.principal_id
                WHERE 
                -- dp.sid = SUSER_SID(@Login)                
                dp.sid = @LoginSID
                AND dp.name NOT IN (''dbo'',''guest'',''sys'',''INFORMATION_SCHEMA'')
                AND NOT ( p.class_desc = ''DATABASE'' AND p.permission_name = ''CONNECT'' )
            ) SET @res = 1;
            --SELECT @res;
            SET @R = @res;
            -- ========================================================
        ';
        -- PRINT 'Generacion @SQL:: '+@SQL;
        EXEC sp_executesql 
            @SQL,
            N'@Login SYSNAME, @LoginSID VARBINARY(85), @R BIT OUTPUT',
            @Login = @LoginName,
            @LoginSID = @LoginSID,
            @R = @R OUTPUT;
        PRINT 'BD: ' + @DB + ' --- R devuelto = ' + ISNULL(CAST(@R AS VARCHAR(10)),'NULL');
        IF @R = 1
        BEGIN
            SET @TienePermisos = 1;
            BREAK;
        END
        FETCH NEXT FROM curDB INTO @DB;
    END
    CLOSE curDB;
    DEALLOCATE curDB;


    ---------------------------------------------------------------------
    -- 4. Decisión ENABLE / DISABLE
    ---------------------------------------------------------------------
    DECLARE @Comd NVARCHAR(200);
    IF @TieneSesiones = 1 OR @TienePermisos = 1
    BEGIN
        SET @Comd = 'ALTER LOGIN [' + @LoginName + '] ENABLE';
        PRINT 'Login habilitado (queda activo o con permisos): ' + @LoginName;
    END
    ELSE
    BEGIN
        SET @Comd = 'ALTER LOGIN [' + @LoginName + '] DISABLE';
        PRINT 'Login deshabilitado (sin sesiones ni permisos): ' + @LoginName;
    END
    BEGIN TRY
        PRINT @Comd
        EXEC(@Comd);
        DECLARE @ENABLE VARCHAR(12) = 'INHABILITADO'
        SELECT 
            @ENABLE = CASE WHEN is_disabled=1 THEN 'INHABILITADO' ELSE 'HABILITADO' END
        FROM sys.server_principals
        WHERE name = @LoginName;
        PRINT 'LOGIN: '+@LoginName+' en estado '+@ENABLE;
    END TRY
    BEGIN CATCH
        PRINT 'Error procesando login [' + @LoginName + ']: ' + ERROR_MESSAGE();
    END CATCH;
END
GO
