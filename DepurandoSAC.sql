SELECT * FROM infraPermisosTemp where Estado='ASIGNADO' AND Usuario IN ('jarzolay','mcobos','larroba','mvasquez','aaguilar') AND Expira>GETDATE();
UPDATE dbo.infraPermisosTemp SET Expira=DATEADD(HOUR, 7*24, Asignacion) where Estado='ASIGNADO' AND Usuario IN ('jarzolay','mcobos','larroba','mvasquez','aaguilar') AND IdPermiso<>172;
UPDATE dbo.infraPermisosTemp SET Expira='2026-03-09 15:20' WHERE Estado='ASIGNADO' AND Usuario IN ('jarzolay','mcobos','larroba','mvasquez','aaguilar');
UPDATE dbo.infraPermisosTemp SET Expira='2026-03-04 15:20' where NumReg=16819

DELETE FROM dbo.infraPermisosTemp WHERE IdPermiso IN (172, 176)

SELECT * FROM ProyFidens.dbo.ADM_ACTIVACION_CUENTA 
WHERE AAC_IDENAAC IN (
	SELECT NumReg FROM infraPermisosTemp where Estado='ASIGNADO' AND Usuario IN ('jarzolay','mcobos','larroba','mvasquez','aaguilar') AND Expira>GETDATE()
)

UPDATE ProyFidens.dbo.ADM_ACTIVACION_CUENTA SET ACC_FECHAFIN = '2026-03-09'
WHERE AAC_IDENAAC IN (
	SELECT NumReg FROM infraPermisosTemp where Estado='ASIGNADO' AND Usuario IN ('jarzolay','mcobos','larroba','mvasquez','aaguilar') AND Expira>GETDATE()
)

UPDATE infraAccesosTempRDU SET Expira='2026-03-09 15:20' WHERE id IN (
	SELECT Id FROM infraAccesosTempRDU where Estado='ASIGNADO'AND Usuario IN ('.\jarzolay','.\mcobos','.\mvasquez','.\larroba','.\aaguilar','FIDENSLAT\jarzolay','FIDENSLAT\mcobos','FIDENSLAT\mvasquez','FIDENSLAT\larroba','FIDENSLAT\aaguilar')
)