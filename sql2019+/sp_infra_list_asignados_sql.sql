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
-- EXEC sp_infra_list_asignados_sql 'REVOCADO'
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Leonel
-- Create date: 2026-02-25
-- Description:	Lista elementos ASIGNADOS, futuras revocatorias SQL, usarlo en todos los servidores SQL 2008, 2012, 2019+
-- =============================================
IF OBJECT_ID('dbo.sp_infra_list_asignados_sql') IS NOT NULL
    DROP PROCEDURE sp_infra_list_asignados_sql;
GO
CREATE PROCEDURE sp_infra_list_asignados_sql
  @Estado VARCHAR(10) = 'SOLICITADO',
  @SortOp VARCHAR(2) = "EB",
  @DiasAtras INT = 1
AS
BEGIN
	SET NOCOUNT ON;
	SELECT Usuario, BaseDatos, PermisoAsignado, NumReg, CodUser, 
		CONVERT(VARCHAR(16), Asignacion, 120) AS FechaIni, 
		CONVERT(VARCHAR(16), Expira, 120) AS FechaFin,
		IdPermiso, CONVERT(VARCHAR(16), Revocado, 120) AS Revocado, Estado
	FROM infraPermisosTemp 
	WHERE (@Estado NOT IN ('ASIGNADO','REVOCADO') OR Estado = @Estado)
	AND (
		-- Si el estado es REVOCADO -> filtrar por fecha Revocado
        (@Estado = 'REVOCADO' 
            AND CAST(Revocado AS DATE) >= CAST(DATEADD(DAY, -@DiasAtras, GETDATE()) AS DATE)
        )
        OR
        -- Si el estado es SOLICITADO -> filtrar por Expira
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
        -- EU = Expira → Usuario
        ----------------------------------------------------------------
        CASE WHEN @SortOp= 'EU' THEN Expira END ASC,
        CASE WHEN @SortOp= 'EU' THEN Usuario END ASC,
        ----------------------------------------------------------------
        -- UE = Usuario → Expira
        ----------------------------------------------------------------
        CASE WHEN @SortOp= 'UE' THEN Usuario END ASC,
        CASE WHEN @SortOp= 'UE' THEN Expira END ASC,
        ----------------------------------------------------------------
        -- UB = Usuario → BaseDatos
        ----------------------------------------------------------------
        CASE WHEN @SortOp= 'UB' THEN Usuario END ASC,
        CASE WHEN @SortOp= 'UB' THEN BaseDatos END ASC,
        ----------------------------------------------------------------
        -- BU = BaseDatos → Usuario
        ----------------------------------------------------------------
        CASE WHEN @SortOp= 'BU' THEN BaseDatos END ASC,
        CASE WHEN @SortOp= 'BU' THEN Usuario END ASC,
        ----------------------------------------------------------------
        -- BE = BaseDatos → Expira
        ----------------------------------------------------------------
        CASE WHEN @SortOp = 'BE' THEN BaseDatos END ASC,
        CASE WHEN @SortOp = 'BE' THEN Expira END ASC,
        ----------------------------------------------------------------
        -- EB = Expira → BaseDatos 
        ----------------------------------------------------------------
        CASE WHEN @SortOp = 'EB' THEN Expira END ASC,
        CASE WHEN @SortOp = 'EB' THEN BaseDatos END ASC,
        ----------------------------------------------------------------
        -- EB = CodUser → BaseDatos 
        ----------------------------------------------------------------
        CASE WHEN @SortOp = 'CB' THEN CodUser END ASC,
        CASE WHEN @SortOp = 'CB' THEN BaseDatos END ASC,
        ----------------------------------------------------------------
        -- EB = BaseDatos → CodUser
        ----------------------------------------------------------------
        CASE WHEN @SortOp = 'BC' THEN BaseDatos END ASC,
        CASE WHEN @SortOp = 'BC' THEN CodUser END ASC,
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
        IdPermiso DESC;
END
GO
