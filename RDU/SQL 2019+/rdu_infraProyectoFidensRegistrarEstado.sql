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
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID('dbo.rdu_infraProyectoFidensRegistrarEstado') IS NOT NULL
    DROP PROCEDURE dbo.rdu_infraProyectoFidensRegistrarEstado;
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-20
-- Description:	Registrar estado de acuerdo a NumReg GESTIONADO en el 102
-- Referido desde ProyFidens.dbo.SYS_ADM_EMAIL_SOLICITUD_ACCESO_PRODUCCION
--  EXEC dbo.rdu_infraProyectoFidensRegistrarEstado 16897, 3, '120';  
-- EXEC dbo.rdu_infraProyectoFidensRegistrarEstado 16890, 3, '31';
-- EXEC dbo.rdu_infraProyectoFidensRegistrarEstado
--	@NumReg = 16890,		@Estado = 3,
--	@CodUser = '31',		@FechaFin = NULL;
--USE ProyFidens;
--EXEC sp_help 'ProyFidens.dbo.ADM_ACTIVACION_CUENTA';
--USE master;
-- =============================================
CREATE PROCEDURE rdu_infraProyectoFidensRegistrarEstado
	@NumReg INT,
	@Estado INT,
	@CodUser VARCHAR(5),
	@FechaFin DATETIME = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	IF (EXISTS(SELECT 1 FROM ProyFidens.dbo.ADM_ACTIVACION_CUENTA WHERE AAC_IDENAAC=@NumReg))
	BEGIN
		UPDATE ProyFidens.dbo.ADM_ACTIVACION_CUENTA
			SET ESTADO = @Estado,
			ACC_FECHAFIN =  
			   CASE 
			      WHEN @FechaFin IS NOT NULL 
				    AND ISDATE(@FechaFin) = 1
				    AND CAST(@FechaFin AS DATE) <> ACC_FECHAFIN 
				  THEN CAST(@FechaFin AS DATE) 
				  ELSE ACC_FECHAFIN 
			   END,
			ACC_HORAFIN = 
				CASE 
				WHEN @FechaFin IS NOT NULL 
				AND ISDATE(@FechaFin) = 1
				AND CAST(@FechaFin AS TIME) <> CAST(ACC_HORAFIN AS TIME)
				-- THEN CAST(@FechaFin AS TIME) 
				THEN CONVERT(VARCHAR(5), CAST(@FechaFin AS TIME), 108)
				ELSE ACC_HORAFIN END			
		WHERE ProyFidens.dbo.ADM_ACTIVACION_CUENTA.AAC_IDENAAC=@NumReg
		IF (@CodUser IS NOT NULL)
			EXEC [ProyFidens].[dbo].[SYS_ADM_EMAIL_SOLICITUD_ACCESO_PRODUCCION] @CodUser, @NumReg;
	END;

	SELECT TOP 1 CTA.AAC_IDENAAC AS NumReg, CTA.ESTADO AS Estado, CAST(CTA.ACC_FECHAFIN AS DATE) AS FFIN, CTA.ACC_HORAFIN AS HFIN 
	FROM ProyFidens.dbo.ADM_ACTIVACION_CUENTA CTA
	WHERE CTA.AAC_IDENAAC = @NumReg;
END
GO
