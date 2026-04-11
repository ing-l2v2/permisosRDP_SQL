USE [master]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.rdu_infraObtenerAccesosExpiradosRDU') IS NOT NULL
    DROP PROCEDURE dbo.rdu_infraObtenerAccesosExpiradosRDU;
GO
-- =============================================
-- Author:		Leonel Villa
-- Create date: 2026-02-14
-- Description:	Obtiene los accesos cuyo atributo Expira es menor que GETDATE()
-- GESTIONADO POR 49 UNICAMENTE
CREATE PROCEDURE dbo.rdu_infraObtenerAccesosExpiradosRDU
AS
BEGIN
    SELECT * 
    FROM infraAccesosTempRDU
    WHERE Estado = 'ASIGNADO'
      AND Expira <= GETDATE()
    ORDER BY Expira ASC;
END;
