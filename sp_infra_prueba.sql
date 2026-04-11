USE [master]
GO
-- ================================================
-- Template generated from Template Explorer using:
-- Create Procedure (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- This block of comments will not be included in
-- the definition of the procedure.
-- EXEC dbo.sp_infra_list_asignados_RDU 'REVOCADO'
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-25
-- Description:	Lista elementos ASIGNADOS, futuras revocatorias RDP, usarlo en servidor 10.0.0.49
-- =============================================
IF OBJECT_ID('dbo.sp_infra_prueba') IS NOT NULL
    DROP PROCEDURE dbo.sp_infra_prueba;
GO
CREATE PROCEDURE dbo.sp_infra_prueba
	@Id INT
AS
BEGIN
	SET NOCOUNT ON;	

	SELECT NumReg, CodUser, Estado AS Est, CONVERT(VARCHAR(16), Expira, 120) As FechaFin FROM dbo.infraAccesosTempRDU WHERE Id = @Id;
END;