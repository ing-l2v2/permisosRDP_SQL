/*
SELECT * from infraAccesosTempRDU WHERE Estado='ASIGNADO';
SELECT * from infraAccesosTempRDU WHERE Estado='REVOCADO' AND CAST(Revocado AS DATE)=CAST(GETDATE() AS DATE);
EXEC dbo.rdu_infraRegistrarRevocacionRDU
    @usr = 'FIDENSLAT\jbarona',
    @serv = '10.0.0.203',
    @grp = 'Remote Desktop Users';
EXEC dbo.rdu_infraRegistrarRevocacionRDU
    @usr = '.\mcobos',
    @serv = '10.0.0.86',
    @grp = 'Remote Desktop Users';
SELECT TOP 1 Id, NumReg 
    FROM infraAccesosTempRDU 
    WHERE Servidor='10.0.0.203'
    AND Usuario='FIDENSLAT\jbarona'
    AND Grupo = 'Remote Desktop Users'
    AND Estado = 'ASIGNADO';
SELECT TOP 1 Id, NumReg 
    FROM infraAccesosTempRDU 
    WHERE Servidor='10.0.0.203'
    AND Usuario='FIDENSLAT\kcuenca'
    AND Grupo = 'Administrators'
    AND Estado = 'REVOCADO';
SELECT TOP 1 Id, NumReg, CodUser, Estado, Expira 
        FROM infraAccesosTempRDU 
        WHERE Servidor='10.0.0.86'
        AND Usuario='.\mcobos'
        AND Grupo = 'Remote Desktop Users'
        AND Estado IN ('ASIGNADO','REVOCADO')
        AND CAST(Expira AS DATE) >= CAST(DATEADD(DAY, -1, GETDATE()) AS DATE);
DELETE FROM infraAccesosTempRDU WHERE Id IN (1,2,3,4);
UPDATE infraAccesosTempRDU SET Estado='ASIGNADO' WHERE id=33;
EXEC dbo.rdu_infraRegistrarRevocacionRDU
    @usr = '.\pvalera',
    @serv = '10.0.0.102',
    @grp = 'Remote Desktop Users';
*/
USE [master]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.rdu_infraRegistrarRevocacionRDU') IS NOT NULL
    DROP PROCEDURE dbo.rdu_infraRegistrarRevocacionRDU;
GO
-- =============================================
-- Author:		Leonel Villa
-- Create date: 2026-02-14
-- Description:	Para el elemento con id se establece como REVOCADO, GESTIONA SERVIDOR 10.0.0.49
--      Se obtiene el Id de infraAccesosTempRDU con proyeccion de -15 dias de ASIGNADO.
CREATE PROCEDURE dbo.rdu_infraRegistrarRevocacionRDU
(
	@serv NVARCHAR(200),
	@usr NVARCHAR(200),
	@grp NVARCHAR(100),
    @Obs NVARCHAR(1000) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;  -- IMPORTANTE
    DECLARE @DiasBack INT = -15;
    DECLARE @Id INT, @NumReg INT, @CodUser VARCHAR(5);
    /*
    SELECT * FROM infraAccesosTempRDU WHERE Usuario = '.\mcobos'
    UPDATE infraAccesosTempRDU SET Estado = 'ASIGNADO' WHERE ID=98;
    */
    SELECT TOP 1 @Id=Id, @NumReg=NumReg, @CodUser=CodUser 
        FROM infraAccesosTempRDU 
        WHERE Servidor=@serv
        AND Usuario=@usr
        AND Grupo = @grp
        AND Estado IN ('ASIGNADO', 'EXPIRADO')
        --AND Estado IN ('ASIGNADO')
        AND CAST(Expira AS DATE) >= CAST(DATEADD(DAY, @DiasBack, GETDATE()) AS DATE)
        ORDER BY Estado ASC, Id DESC;    
    IF (@Id IS NOT NULL)
    BEGIN
        UPDATE infraAccesosTempRDU
        SET Estado = CASE WHEN @Obs IS NULL THEN 'REVOCADO' ELSE 'ERROR' END,
            Revocado = GETDATE(),
            Observacion = @Obs
        WHERE Id = @Id;
    END;    
    ------------------------------
    -- RESULTADO FORZADO Y LIMPIO
    SELECT CAST(@Id AS INT)     AS Id,
           CAST(@NumReg AS INT) AS NumReg,
           @CodUser AS CodUser;
END;
