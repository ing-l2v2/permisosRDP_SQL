SELECT * FROM dbo.infraBasesGestionadas

INSERT INTO master.dbo.infraBasesGestionadas (BaseDatos, idAdminFidens, Estado)
        SELECT d.name, 1, 1
        FROM sys.databases d
        WHERE d.name NOT IN ('master','model','msdb','tempdb','ReportServerTempDB')
          AND d.name NOT IN (
                SELECT BaseDatos 
                FROM master.dbo.infraBasesGestionadas
                ORDER BY dbo.infraBasesGestionadas.BaseDatos ASC
          )
        ORDER BY d.name;

UPDATE master.dbo.infraBasesGestionadas SET idAdminFidens = 19 WHERE idBase=9;
UPDATE master.dbo.infraBasesGestionadas SET idAdminFidens = 20 WHERE idBase=8;
UPDATE master.dbo.infraBasesGestionadas SET idAdminFidens = 92 WHERE idBase=7;