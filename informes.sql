ALTER LOGIN [cberruz] ENABLE
GO


SELECT *
FROM DERCO_CORREDOR.sys.database_principals dp
INNER JOIN master.sys.server_principals sp ON dp.sid = sp.sid
WHERE sp.name = 'cberruz'


    -----------------------------------------------------------------------
    -- 1. Detectar si tiene sesiones activas
    --    SQL 2008 NO expone database_id desde dm_exec_sessions
    --    y solo aparece si existe un request activo
    -----------------------------------------------------------------------
    DECLARE @LoginName SYSNAME = 'cberruz';
    DECLARE @TieneSesiones BIT = 0;
    SELECT @TieneSesiones =
        CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
    FROM sys.dm_exec_sessions s
    LEFT JOIN sys.dm_exec_requests r ON r.session_id = s.session_id    
    WHERE s.login_name = @LoginName
      AND r.database_id IS NOT NULL   -- Solo requests en BDs reales
      AND r.database_id > 4;          -- 1=master, 2=tempdb, 3=model, 4=msdb

    DECLARE 
        @TienePermisos BIT = 0,
        @DB SYSNAME,
        @SQL NVARCHAR(MAX),
        @LocalResult INT;

    DECLARE curDB CURSOR LOCAL FAST_FORWARD FOR
    SELECT name
    FROM sys.databases
    WHERE database_id > 4  -- Solo bases de usuario
      AND state = 0;       -- ONLINE

    OPEN curDB;
    FETCH NEXT FROM curDB INTO @DB;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        CREATE TABLE #tmpResult (valor INT);
        SET @SQL = '
            SET NOCOUNT ON;
            DECLARE @r INT = 0;
            -- 1. ¿Tiene usuario en la BD?
            IF EXISTS (
                SELECT 1 
                FROM [' + @DB + '].sys.database_principals
                WHERE sid = SUSER_SID(@LoginNamePlaceholder)
            )
                SET @r = 1;
            -- 2. ¿Tiene rol asignado en la BD?
            IF EXISTS (
                SELECT 1
                FROM [' + @DB + '].sys.database_role_members rm
                JOIN [' + @DB + '].sys.database_principals r ON rm.role_principal_id = r.principal_id
                JOIN [' + @DB + '].sys.database_principals u ON rm.member_principal_id = u.principal_id
                WHERE u.sid = SUSER_SID(@LoginNamePlaceholder)
            )
                SET @r = 1;
            INSERT INTO #tmpResult(valor)
            SELECT @r;
        ';
        -- Ejecuta SIN mostrar resultado, capturando en variable local
        EXEC sp_executesql 
            @SQL,
            N'@LoginNamePlaceholder SYSNAME',
            @LoginNamePlaceholder = @LoginName;
            
        SELECT @LocalResult = valor FROM #tmpResult;
        SELECT * from #tmpResult;
        DROP TABLE #tmpResult;
        IF @LocalResult = 1
        BEGIN
            SET @TienePermisos = 1;
            BREAK;
        END
        FETCH NEXT FROM curDB INTO @DB;
    END
    CLOSE curDB;
    DEALLOCATE curDB;

    -----------------------------------------------------------------------
    -- 3. Habilitar / Deshabilitar login según actividad o permisos
    -----------------------------------------------------------------------
    DECLARE @Command NVARCHAR(300);
    IF @TieneSesiones = 1 OR @TienePermisos = 1
    BEGIN
        SET @Command = 'ALTER LOGIN [' + @LoginName + '] ENABLE;';
        PRINT 'Login habilitado: ' + @LoginName;
    END
    ELSE
    BEGIN
        SET @Command = 'ALTER LOGIN [' + @LoginName + '] DISABLE;';
        PRINT 'Login deshabilitado: ' + @LoginName;
    END
    BEGIN TRY
        PRINT @Command;
        EXEC(@Command);
    END TRY
    BEGIN CATCH
        PRINT 'Error procesando login [' + @LoginName + ']: ' 
              + ERROR_MESSAGE();
    END CATCH;










DECLARE @Login SYSNAME = 'cberruz';
IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL
    DROP TABLE #Tmp;
CREATE TABLE #Tmp (
    BaseDatos SYSNAME,
    TieneUsuario BIT,
    TieneRoles BIT,
    TienePermisos BIT
);
DECLARE @DB SYSNAME, @SQL NVARCHAR(MAX);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
SELECT name 
FROM sys.databases 
WHERE database_id > 4 AND state = 0;

OPEN cur;
FETCH NEXT FROM cur INTO @DB;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = '
        INSERT INTO #Tmp(BaseDatos, TieneUsuario, TieneRoles, TienePermisos)
        SELECT 
            ''' + @DB + ''',
            CASE WHEN EXISTS (
                SELECT 1 FROM [' + @DB + '].sys.database_principals
                WHERE sid = SUSER_SID(@Login)
            ) THEN 1 ELSE 0 END,
            CASE WHEN EXISTS (
                SELECT 1 
                FROM [' + @DB + '].sys.database_role_members rm
                JOIN [' + @DB + '].sys.database_principals u 
                    ON rm.member_principal_id = u.principal_id
                WHERE u.sid = SUSER_SID(@Login)
            ) THEN 1 ELSE 0 END,
            CASE WHEN EXISTS (
                SELECT 1
                FROM [' + @DB + '].sys.database_permissions p
                JOIN [' + @DB + '].sys.database_principals dp
                    ON p.grantee_principal_id = dp.principal_id
                WHERE dp.sid = SUSER_SID(@Login)
            ) THEN 1 ELSE 0 END;
    ';
    EXEC sp_executesql @SQL, N'@Login SYSNAME', @Login=@Login;
    FETCH NEXT FROM cur INTO @DB;
END
CLOSE cur;
DEALLOCATE cur;
SELECT *
FROM #Tmp
WHERE TieneUsuario = 1 OR TieneRoles = 1 OR TienePermisos = 1;






SELECT 
    session_id,
    login_name,
    host_name,
    program_name,
    status
FROM sys.dm_exec_sessions
WHERE login_name = 'cberruz';







SELECT 
    sp.state_desc,
    sp.permission_name,
    pr.name AS principal_name
FROM sys.server_permissions sp
JOIN sys.server_principals pr
    ON sp.grantee_principal_id = pr.principal_id
WHERE pr.name = 'cberruz';
