USE ProyFidens;
GO

SELECT 
    OBJECT_SCHEMA_NAME(d.referencing_id) AS Esquema,
    OBJECT_NAME(d.referencing_id) AS Objeto,
    o.type_desc AS TipoObjeto,
    d.referenced_entity_name AS EntidadReferenciada
FROM sys.sql_expression_dependencies d
INNER JOIN sys.objects o
    ON d.referencing_id = o.object_id
WHERE d.referenced_entity_name LIKE 'ADM_ACTIVACION_CUENTA'
ORDER BY TipoObjeto, Objeto;