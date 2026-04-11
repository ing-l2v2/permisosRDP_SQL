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
IF OBJECT_ID('dbo.sp_infra_list_asignados_RDU') IS NOT NULL
    DROP PROCEDURE sp_infra_list_asignados_RDU;
GO
CREATE PROCEDURE sp_infra_list_asignados_RDU
	@Estado VARCHAR(10) = 'SOLICITADO',
    @SortOp VARCHAR(2) = 'SU',
    @DiasAtras INT = 1
AS
BEGIN
	SET NOCOUNT ON;	
	--SELECT * FROM infraAccesosTempRDU;
	SELECT Usuario, Servidor, Grupo, NumReg, CodUser, 
		CONVERT(VARCHAR(16), Asignacion, 120) AS FechaIni, 
		CONVERT(VARCHAR(16), Expira, 120) AS FechaFin,
		Id, CONVERT(VARCHAR(16), Revocado, 120) AS Revocado, Estado
	FROM infraAccesosTempRDU
	WHERE (@Estado NOT IN ('ASIGNADO','REVOCADO') OR Estado = @Estado)
	AND (
		-- Si el estado es REVOCADO → filtrar por fecha Revocado
        (@Estado = 'REVOCADO' 
            AND CAST(Revocado AS DATE) >= CAST(DATEADD(DAY, -@DiasAtras, GETDATE()) AS DATE)
        )
        OR
        -- Si el estado es SOLICITADO → filtrar por Expira
        (@Estado = 'SOLICITADO'
            AND CAST(Expira AS DATE) >= CAST(DATEADD(DAY, -@DiasAtras, GETDATE()) AS DATE)
        )
        OR
        -- Cualquier otro estado usa Expira
        (@Estado NOT IN ('REVOCADO','SOLICITADO')
            AND CAST(Expira AS DATE) >= CAST(DATEADD(DAY, -@DiasAtras, GETDATE()) AS DATE)
        )
     )
	ORDER BY 
            ----------------------------------------------------------------
        -- EU = Servidor → Usuario
        ----------------------------------------------------------------
        CASE WHEN @SortOp= 'SU' THEN Servidor END ASC,
        CASE WHEN @SortOp= 'SU' THEN Usuario END ASC,
        ----------------------------------------------------------------
        -- UE = Usuario → Servidor
        ----------------------------------------------------------------
        CASE WHEN @SortOp= 'US' THEN Usuario END ASC,
        CASE WHEN @SortOp= 'US' THEN Servidor END ASC,
        ----------------------------------------------------------------
        -- GS = Grupo → Servidor + Usuario
        ----------------------------------------------------------------
        CASE WHEN @SortOp= 'GS' THEN Grupo END ASC,
        CASE WHEN @SortOp= 'GS' THEN Servidor END ASC,
        CASE WHEN @SortOp= 'GS' THEN Usuario END ASC,
        ----------------------------------------------------------------
        -- SG = Servidor → Grupo + Usuario
        ----------------------------------------------------------------
        CASE WHEN @SortOp= 'SG' THEN Servidor END ASC,
        CASE WHEN @SortOp= 'SG' THEN Grupo END ASC,
        CASE WHEN @SortOp= 'SG' THEN Usuario END ASC,
        ----------------------------------------------------------------
        -- GC = Grupo → CodUser
        ----------------------------------------------------------------
        CASE WHEN @SortOp= 'GC' THEN Grupo END ASC,
        CASE WHEN @SortOp= 'GC' THEN CodUser END ASC,
        ----------------------------------------------------------------
        -- CG = CodUser → Grupo
        ----------------------------------------------------------------
        CASE WHEN @SortOp = 'CG' THEN CodUser END ASC,
        CASE WHEN @SortOp = 'CG' THEN Grupo END ASC,
        ----------------------------------------------------------------
        -- CS = CodUser → Servidor 
        ----------------------------------------------------------------
        CASE WHEN @SortOp = 'CS' THEN CodUser END ASC,
        CASE WHEN @SortOp = 'CS' THEN Servidor END ASC,
        ----------------------------------------------------------------
        -- SC = Servidor → CodUser 
        ----------------------------------------------------------------
        CASE WHEN @SortOp = 'SC' THEN Servidor END ASC,
        CASE WHEN @SortOp = 'SC' THEN CodUser END ASC,
        ----------------------------------------------------------------
        -- FI = FechaInicio
        ----------------------------------------------------------------
        CASE WHEN @SortOp = 'FI' THEN Asignacion END DESC,
        ----------------------------------------------------------------
        -- FF = FechaFin
        ----------------------------------------------------------------
        CASE WHEN @SortOp = 'FF' THEN Expira END DESC,
        ----------------------------------------------------------------
        -- RV = Revocacion
        ----------------------------------------------------------------
        CASE WHEN @SortOp = 'RV' THEN Revocado END DESC,
        ----------------------------------------------------------------
        -- Default estable (para desempates)
        ----------------------------------------------------------------
        Id DESC;
END
GO
