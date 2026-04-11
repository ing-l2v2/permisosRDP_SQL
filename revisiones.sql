SELECT * FROM infraAccesosTempRDU;
SELECT * FROM infraAccesosTempRDU WHERE Estado='ASIGNADO';
SELECT * FROM infraAccesosTempRDU WHERE Usuario = '.\jtoledo';
SELECT * FROM infraAccesosTempRDU WHERE Usuario = 'FIDENSLAT\kcuenca';
SELECT * FROM infraAccesosTempRDU WHERE CAST(Revocado AS date) = CAST(GETDATE() AS date);
SELECT * FROM infraPermisosTemp WHERE Estado='REVOCADO' AND CAST(Revocado AS date) = CAST(GETDATE() AS date);
SELECT * FROM infraPermisosTemp WHERE Estado='ASIGNADO';
SELECT * FROM infraPermisosTemp WHERE Usuario='ecordova' AND Estado='ASIGNADO';
SELECT * FROM infraPermisosTemp WHERE IdPermiso IN (34)
SELECT * FROM infraPermisosProcesadosProyFidens 

DELETE FROM infraPermisosProcesadosProyFidens WHERE IdPermiso=11;

EXEC dbo.sp_infra_revocar_permisos_expirados;
EXEC dbo.sp_infra_login_estado_usuario @LoginName='jbogado';
INSERT INTO infraPermisosTemp (Usuario, TipoAsignacion, PermisoAsignado, BaseDatos, Asignacion, Expira, Estado, NumReg, CodUser) VALUES
('kcuenca', 'DB_ROLE', 'db_rwsp', 'AutomovilClub', '2026-02-23 10:51', '2026-02-24 21:00', 'ASIGNADO', 16707, 00120),
('kcuenca', 'DB_ROLE', 'db_rwsp', 'AutomovilClub_log', '2026-02-23 10:51', '2026-02-24 21:00', 'ASIGNADO', 16707, 00120);

INSERT INTO infraAccesosTempRDU(Usuario, Servidor, Grupo, Asignacion, Expira, Estado, NumReg)
SELECT './jtoledo','10.0.0.49','Remote Desktop Users', '2026-02-20 12:35', '2026-02-22 23:59', 'ASIGNADO', 16671;

UPDATE infraPermisosTemp SET Asignacion='2026-02-18 11:00:59' WHERE IdPermiso IN (44);
UPDATE infraPermisosTemp SET Expira='2026-02-25 09:00:00' WHERE IdPermiso IN (35);
UPDATE infraPermisosTemp SET Usuario='jarzolay' WHERE IdPermiso IN (32);
UPDATE infraPermisosTemp SET Usuario='mcobos' WHERE IdPermiso IN (46);

UPDATE infraPermisosTemp SET NumReg=16723 WHERE IdPermiso IN (27);
UPDATE infraPermisosTemp SET NumReg=16666 WHERE IdPermiso IN (21);
UPDATE infraPermisosTemp SET NumReg=16659 WHERE IdPermiso IN (12);

UPDATE infraPermisosTemp SET NumReg=16667 WHERE IdPermiso IN (35);
UPDATE infraPermisosTemp SET NumReg=16668 WHERE IdPermiso IN (36);
UPDATE infraPermisosTemp SET NumReg=16658 WHERE IdPermiso IN (37);
UPDATE infraPermisosTemp SET NumReg=16658 WHERE IdPermiso IN (38);
UPDATE infraPermisosTemp SET NumReg=16652 WHERE IdPermiso IN (39);
UPDATE infraPermisosTemp SET NumReg=16663 WHERE IdPermiso IN (40);
UPDATE infraPermisosTemp SET Estado='ASIGNADO' WHERE IdPermiso IN (35);

UPDATE infraAccesosTempRDU SET Estado='ASIGNADO' WHERE Id IN (102,103);
UPDATE infraAccesosTempRDU SET Estado='ASIGNADO' WHERE Id IN (71);
UPDATE infraAccesosTempRDU SET NumReg=16706 WHERE Id IN (75);
UPDATE infraAccesosTempRDU SET NumReg=16652 WHERE Id IN (45);
UPDATE infraAccesosTempRDU SET NumReg=16648 WHERE Id IN (46);
UPDATE infraAccesosTempRDU SET NumReg=16663 WHERE Id IN (50);
UPDATE infraAccesosTempRDU SET NumReg=16671 WHERE Id IN (51);
UPDATE infraAccesosTempRDU SET FechaRegistro='2026-02-20 11:03:17.680' WHERE Id IN (50);
UPDATE infraAccesosTempRDU SET Usuario='.\larroba' WHERE Id IN (38);
UPDATE infraAccesosTempRDU SET Usuario='.\jtoledo' WHERE Id IN (55);
UPDATE infraAccesosTempRDU SET Asignacion='2026-02-18 11:00:00' WHERE Id=44;
UPDATE infraAccesosTempRDU SET Expira='2026-02-25 19:05:48' WHERE Id IN (104,105);
UPDATE infraAccesosTempRDU SET Revocado=null WHERE Id=42;

DELETE infraAccesosTempRDU WHERE Id=72;

/*
    ALTER LOGIN [jbarona] DISABLE
    GO
*/

        SELECT name, create_date,
            modify_date, type,
            is_disabled
        FROM sys.server_principals
        WHERE 
          -- name = @Usr  AND -- ejemplo: 'gchavez' 
          type IN ('S', 'U'); -- SQL Login / Windows Login        

        SELECT name, create_date,
            modify_date, type,
            is_disabled
        FROM sys.server_principals
        WHERE 
          -- name = @Usr  AND -- ejemplo: 'gchavez' 
          type IN ('S'); -- SQL Login / Windows Login        


EXEC BCI_PYME..sp_change_users_login 'Report';


SELECT 
    name,
    type_desc,
    sid
FROM sys.database_principals
WHERE name = 'jarzolay';


SELECT SUSER_SID('jarzolay') AS LoginSID;

SELECT 
    dp2.name AS Usuario,
    dp.name  AS Rol
FROM sys.database_role_members drm
JOIN sys.database_principals dp 
    ON dp.principal_id = drm.role_principal_id
JOIN sys.database_principals dp2
    ON dp2.principal_id = drm.member_principal_id
WHERE dp2.name = 'jarzolay';

SELECT 
    p.class_desc, 
    p.permission_name, 
    p.state_desc, 
    obj.name AS object_name
FROM sys.database_permissions p
LEFT JOIN sys.objects obj ON p.major_id = obj.object_id
WHERE grantee_principal_id = USER_ID('db_rwsp');

DECLARE @LoginPlaceHolder SYSNAME = 'jarzolay';
DECLARE @DB SYSNAME = 'BCI_PYME';
DECLARE @UserPrincipalId INT;
SET @UserPrincipalId = (
    SELECT principal_id
    FROM [BCI_PYME].sys.database_principals
    WHERE sid = SUSER_SID(@LoginPlaceholder));
SELECT @UserPrincipalId;
SELECT principal_id, *
    FROM [BCI_PYME].sys.database_principals
    WHERE sid = SUSER_SID('jarzolay');


USE BCI_PYME;
SELECT 
    dp2.name AS Usuario,
    dp.name  AS Rol
FROM sys.database_role_members drm
JOIN sys.database_principals dp 
    ON dp.principal_id = drm.role_principal_id
JOIN sys.database_principals dp2
    ON dp2.principal_id = drm.member_principal_id
WHERE dp2.name = 'jarzolay';

USE BCI_PYME;
SELECT 
    p.class_desc, 
    p.permission_name, 
    p.state_desc, 
    obj.name AS object_name
FROM sys.database_permissions p
LEFT JOIN sys.objects obj ON p.major_id = obj.object_id
WHERE grantee_principal_id = USER_ID('db_rwsp');


USE BCI_PYME;
SELECT 
    p.class_desc, 
    p.permission_name, 
    p.state_desc, 
    obj.name AS object_name
FROM sys.database_permissions p
LEFT JOIN sys.objects obj ON p.major_id = obj.object_id
WHERE grantee_principal_id = USER_ID('db_rw');



SELECT name, sid 
FROM sys.server_principals 
WHERE name = 'jarzolay';

USE BCI_PYME;
EXEC sp_change_users_login 'Report';

USE BCI_PYME;
SELECT sid FROM sys.database_principals WHERE name='jarzolay';


    SELECT @TieneRol = COUNT(*)
    FROM [BCI_PYME].sys.database_role_members drm
    INNER JOIN [BCI_PYME].sys.database_principals r ON drm.role_principal_id = r.principal_id
    INNER JOIN [BCI_PYME].sys.database_principals u ON drm.member_principal_id = u.principal_id
    WHERE u.name = 'jarzolay';
     -- and r.name = 'db_rw';