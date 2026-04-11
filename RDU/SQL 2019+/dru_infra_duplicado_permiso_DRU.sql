USE master;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.rdu_infra_duplicado_permiso_RDU') IS NOT NULL
    DROP PROCEDURE dbo.rdu_infra_duplicado_permiso_RDU;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-03-06
-- Description:	Exclusivo gestiona servidor 49 
-- Si ya existe el permiso retorna 1
-- Si el permiso se puede asignar sin problemas retorna todos 0
-- SELECT TOP 20 * FROM dbo.infraAccesosTempRDU ORDER BY Expira DESC
-- UPDATE dbo.infraAccesosTempRDU SET Estado='ASIGNADO', Expira='2026-03-09 11:00', Revocado=NULL WHERE Id=166;
-- EXEC dbo.rdu_infra_duplicado_permiso_RDU '.\mcobos', '10.0.0.102', 'Remote Desktop Users';
-- =============================================
CREATE PROCEDURE dbo.rdu_infra_duplicado_permiso_RDU
    @Usuario NVARCHAR(200),
    @Servidor NVARCHAR(200),
    @Grupo NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Duplicado INT = 0;
--    select * from dbo.infraAccesosTempRDU
    DECLARE @Tmp TABLE (
        Duplicado INT,
        NumReg INT,
        CodUser VARCHAR(5),
        Est VARCHAR(20),
        Expira DATETIME,
        Revocado VARCHAR(16),
        Usuario SYSNAME NULL,
        Grupo VARCHAR(100),        
        id INT
    );

    IF (EXISTS( SELECT 1 FROM master.dbo.infraAccesosTempRDU
        WHERE Usuario = @Usuario
        AND Servidor = @Servidor
        AND Grupo = @Grupo
        AND Estado = 'ASIGNADO'
    ))
    BEGIN
        INSERT INTO @Tmp (Duplicado, NumReg, CodUser, Est, Expira, Revocado, Usuario, Grupo, id)
        SELECT 1, NumReg, CodUser, Estado, Expira, Revocado, Usuario, Grupo, id 
        FROM master.dbo.infraAccesosTempRDU
        WHERE Usuario = @Usuario
            AND Servidor = @Servidor
            AND Grupo = @Grupo
            AND Estado = 'ASIGNADO';                
    END
    ELSE
    BEGIN
        INSERT INTO @Tmp (Duplicado) VALUES (0);
    END;        
    SELECT * FROM @Tmp;
END
GO