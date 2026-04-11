USE [master]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Leonel Villa
-- Create date: 2026-02-14
-- Description:	Consulta y obtiene el primer id que coincide con Servidor, Usuario, grupo y estado SOLICITADO
-- =============================================
IF OBJECT_ID('dbo.rdu_consul_serv_usr_grp_est') IS NOT NULL
    DROP PROCEDURE dbo.rdu_consul_serv_usr_grp_est;
GO
CREATE PROCEDURE dbo.rdu_consul_serv_usr_grp_est
	@serv NVARCHAR(200),
	@usr NVARCHAR(200),
	@grp NVARCHAR(100)
AS
BEGIN
	DECLARE @est NVARCHAR(15);
	DECLARE @idSalida INT;
	SET @est = 'ASIGNADO';
	SELECT TOP(1) Id
	FROM infraAccesosTempRDU 
	WHERE Servidor=@serv 
	AND Usuario = @usr
	AND Grupo = @grp
	AND Estado = @est;
	RETURN @idSalida;
END
GO
