USE [master]
GO
/*
 ALTER TABLE infraPermisosProcesadosProyFidens
   ADD CodUser VARCHAR(5) DEFAULT '';

CREATE INDEX IX_infraPermisosProcesadosProyFidens_Procesado_IdPermiso
ON dbo.infraPermisosProcesadosProyFidens (Procesado, IdPermiso);

CREATE INDEX IX_infraPermisosTemp_IdPermiso
    ON dbo.infraPermisosTemp (IdPermiso);

 SELECT * FROM dbo.infraPermisosProcesadosProyFidens WHERE Usuario = 'mcobos' ORDER BY Revocado DESC, IdPermiso ASC
 delete from dbo.infraPermisosProcesadosProyFidens where Procesado = 0
*/
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.sp_infra_list_revocados_sql') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_list_revocados_sql;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-21
-- Description:	Genera lista de elementos revocados únicamente para asignacion desde script 
-- powershell en TODOS LOS SERVIDORES SQL
-- =============================================
CREATE PROCEDURE dbo.sp_infra_list_revocados_sql
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'infraPermisosProcesadosProyFidens')
    BEGIN
        CREATE TABLE dbo.infraPermisosProcesadosProyFidens (
            IdPermiso        INT IDENTITY(1,1) PRIMARY KEY,
            NumReg           INT           NOT NULL,
            Usuario          SYSNAME       NOT NULL,
            HoraHigh         DATETIME      NOT NULL,
            Revocado         DATETIME      NOT NULL,
            Procesado        INT NOT NULL DEFAULT 0,
            Estado           INT NOT NULL DEFAULT 0,
            CodUser        VARCHAR(5) NOT NULL DEFAULT '',
            BaseDatos        SYSNAME       NULL
        );
        CREATE INDEX IX_infraPermisosProcesadosProyFidens_Procesado_IdPermiso
            ON dbo.infraPermisosProcesadosProyFidens (Procesado, IdPermiso);
    END;

    UPDATE dbo.infraPermisosProcesadosProyFidens
    SET Procesado = Procesado + 1
    WHERE Procesado IN (0);

/*    
    UPDATE infraPermisosProcesadosProyFidens
    SET Estado=2, Procesado=0 WHERE Procesado=1 AND CAST(HoraHigh AS DATE) = CAST(GETDATE() AS DATE);

    DELETE FROM dbo.infraPermisosProcesadosProyFidens WHERE Procesado=0
    SELECT * FROM infraPermisosProcesadosProyFidens
    SELECT * FROM dbo.infraPermisosTemp
*/
    INSERT INTO dbo.infraPermisosProcesadosProyFidens (NumReg, Usuario, HoraHigh, Revocado, Estado, CodUser)
    SELECT 
        t.NumReg,
        t.Usuario,
        CASE
        WHEN (t.Estado = 'ASIGNADO') THEN
            NULL
        WHEN (t.Estado = 'REVOCADO') THEN
            DATEADD(HOUR, DATEDIFF(HOUR, 0, t.Revocado) + 1, 0)
        END AS 'GrupoRevocado',
        t.Revocado,
        CASE WHEN (t.Estado='ASIGNADO') THEN 2 WHEN (t.Estado='REVOCADO') THEN 3 END AS Estado,
        --CASE WHEN (t.Estado='ASIGNADO') THEN 2 WHEN (t.Estado='REVOCADO') THEN 6 END
        t.CodUser
    FROM dbo.infraPermisosTemp t
    WHERE t.NumReg IS NOT NULL
    AND t.Estado = 'REVOCADO'
    AND CAST(t.Expira AS DATE) >= CAST(DATEADD(DAY, -4, GETDATE()) AS DATE)
    AND NOT EXISTS(
        SELECT 1
        FROM dbo.infraPermisosProcesadosProyFidens p
        WHERE p.NumReg = t.NumReg
    );
    -------------------------------------------------
    -- Salida final
    -------------------------------------------------
	SELECT pry.NumReg, pry.Estado, pry.Usuario, pry.HoraHigh, pry.Procesado, pry.CodUser, permiso.BaseDatos, pry.IdPermiso, permiso.PermisoAsignado
    FROM dbo.infraPermisosProcesadosProyFidens AS pry
    LEFT JOIN dbo.infraPermisosTemp AS permiso ON pry.IdPermiso = permiso.IdPermiso    
    WHERE Procesado IN (0);    
END
GO