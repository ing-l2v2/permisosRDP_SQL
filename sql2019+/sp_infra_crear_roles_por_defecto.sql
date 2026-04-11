/*
    EXEC dbo.sp_infra_crear_roles_por_defecto 'IMCRUZ';
*/
USE master;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.sp_infra_crear_roles_por_defecto') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_crear_roles_por_defecto;
GO

CREATE PROCEDURE dbo.sp_infra_crear_roles_por_defecto
    @BaseDatos SYSNAME
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);

    ------------------------------------------------------------
    -- PLANTILLA GENERAL PARA CREAR ROLES SI NO EXISTEN
    ------------------------------------------------------------
    SET @SQL = N'
    USE [' + @BaseDatos + N'];

    -- db_rw
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''db_rw'')
        CREATE ROLE [db_rw];
    GRANT SELECT, INSERT, UPDATE, DELETE TO [db_rw];

    -- db_ejecutor
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''db_ejecutor'')
        CREATE ROLE [db_ejecutor];
    GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE TO [db_ejecutor];
    GRANT ALTER ANY SCHEMA TO [db_ejecutor];

    -- db_modificar_sp (ALTER + EXECUTE sobre SP)
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''db_modificar_sp'')
        CREATE ROLE [db_modificar_sp];
    GRANT VIEW DEFINITION TO [db_modificar_sp];
    GRANT EXECUTE TO [db_modificar_sp];
    GRANT CREATE PROC TO [db_modificar_sp];
    GRANT ALTER ANY SCHEMA TO [db_modificar_sp];

    -- db_rwsp
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''db_rwsp'')
        CREATE ROLE [db_rwsp];
    GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE TO [db_rwsp];
    GRANT VIEW DEFINITION TO [db_rwsp];

    -- db_rwsp_upd
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''db_rwsp_upd'')
        CREATE ROLE [db_rwsp_upd];
    GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE TO [db_rwsp_upd];
    GRANT CREATE PROC TO [db_rwsp_upd];
    GRANT VIEW DEFINITION TO [db_rwsp_upd];
    ';

    EXEC(@SQL);
END
GO