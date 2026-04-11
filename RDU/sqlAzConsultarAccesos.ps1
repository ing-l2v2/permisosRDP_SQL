# Datos de conexión
$server = "tcp:sql-ginger.database.windows.net"
$user = "csilva"
$pass = "Ohdef_1007"

$masterCon = "Server=$server;Database=master;User ID=$user;Password=$pass;Encrypt=True;"

$inicioProc = Get-Date

$dbs = Invoke-Sqlcmd -ConnectionString $masterCon -Query "
    SELECT name FROM sys.databases WHERE database_id > 4;
"

$resultado = @()
$sqlAzureBd = @()     # Acumular los resulados de $rows

Write-Host "Procesando: Analisis de AZURE sql-ginger" -ForegroundColor Yellow

# ================================
# PROGRESO + TIEMPO ESTIMADO
# ================================
$total = $dbs.count
$startTime = Get-Date
$index = 0
foreach ($db in $dbs.name) {
    $index++
    $percent = [math]::Round(($index / $total) * 100, 2)
    # ===== Tiempo estimado =====
    $elapsed = (Get-Date) - $startTime
    if ($percent -gt 0) {
        $remaining = $elapsed.TotalSeconds * (100 - $percent) / $percent
        $eta = [TimeSpan]::FromSeconds($remaining)
        $etaText = "{0:hh\:mm\:ss}" -f $eta
    }
    else {
        $etaText = "Calculando..."
    }
    Write-Progress `
        -Activity "Procesando Azure SQL-GINGER" `
        -Status "Progreso: $percent% | ETA: $etaText | Base: $db " `
        -PercentComplete $percent

    $con = "Server=$server;Database=$db;User ID=$user;Password=$pass;Encrypt=True;"

    $sql = @"
-- Roles del usuario (resumidos)
WITH Roles AS (
    SELECT 
        u.principal_id,
        STRING_AGG(r.name, ', ') AS Roles
    FROM sys.database_principals u
    LEFT JOIN sys.database_role_members rm ON u.principal_id = rm.member_principal_id
    LEFT JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
    WHERE u.type IN ('S','U','G','E')
    GROUP BY u.principal_id
),

-- Permisos expresos resumidos
Permisos AS (
    SELECT 
        u.principal_id,
        pp.permission_name,
        COUNT(*) AS CantObjetos
    FROM sys.database_principals u
    LEFT JOIN sys.database_permissions pp
         ON u.principal_id = pp.grantee_principal_id
    WHERE u.type IN ('S','U','G','E')
    GROUP BY u.principal_id, pp.permission_name
),

-- Permisos agrupados por usuario
PermisosFinal AS (
    SELECT 
        principal_id,
        STRING_AGG(permission_name + ' (' + CAST(CantObjetos AS NVARCHAR(10)) + ')', ', ') AS PermisosResumidos
    FROM Permisos
    GROUP BY principal_id
)

SELECT  
    DB_NAME() AS BaseDatos,
    u.name AS Usuario,
    r.Roles,
    p.PermisosResumidos,
    ISNULL((SELECT SUM(CantObjetos) FROM Permisos pe WHERE pe.principal_id = u.principal_id),0) AS TotalPermisos
FROM sys.database_principals u
LEFT JOIN Roles r ON r.principal_id = u.principal_id
LEFT JOIN PermisosFinal p ON p.principal_id = u.principal_id
WHERE u.type IN ('S','U','G','E')
ORDER BY Usuario;
"@
    
    $rows = Invoke-Sqlcmd -ConnectionString $con -Query $sql
    $resultado += $rows
    if (-not $rows) {
        Write-Host "[sql-ginger] No existen resultados de consultas en azure." -ForegroundColor Magenta
    }
    else {
        foreach ($a in $rows) {
            $sqlAzureBd += [PSCustomObject]@{
                BaseDatos       = $a["BaseDatos"]
                Usuario         = $a["Usuario"]
                Roles           = $a["Roles"]
                PermisoResumido = $a["PermisosResumidos"]
                TotalPermisos   = $a["TotalPermisos"]
            }
        }
    }
}

# Cerrar barra de progreso
Write-Progress -Activity "Procesando Azure SQL-GINGER" -Completed -Status "Completado"


$repDir = ".\reportes"
$cssDir = "$repDir\css"
$jsDir = "$repDir\js"

if (!(Test-Path $repDir)) { New-Item -ItemType Directory -Path $repDir | Out-Null }
if (!(Test-Path $cssDir)) { New-Item -ItemType Directory -Path $cssDir | Out-Null }
if (!(Test-Path $jsDir)) { New-Item -ItemType Directory -Path $jsDir | Out-Null }

# Exportar resultados
$export = "$repDir\ResumenDBA.csv"
$resultado | Export-Csv -Path $export -NoTypeInformation -Encoding UTF8
# Write-Host "Reporte generado: $export" -ForegroundColor Green

# Construcción tabla SQL
$rowsSql = ""
foreach ($r in $sqlAzureBd) {
    $rowsSql += @"
<tr>
<td>$($r.BaseDatos.Trim("'").Trim())</td>
<td>$($r.Usuario.Trim("'").Trim())</td>
<td>$($r.Roles)</td>
<td>$($r.PermisoResumido)</td>
<td>$($r.TotalPermisos)</td>
</tr>    
"@
}

# Informacion para Dashboard
$totalRegistros = $sqlAzureBd.Count
$totalBases = ($sqlAzureBd.BaseDatos | Sort-Object -Unique).Count
$usuariosSql = ($sqlAzureBd.Usuario | Sort-Object -Unique).Count
$totalRoles = ($sqlAzureBd.Roles | Sort-Object -Unique).Count

$fecha = Get-Date -Format "yyyyMMdd"
$htmlFile = "$repDir\resumenDBA.html"

$finProc = Get-Date
$duracionProc = ($finProc - $inicioProc).ToString("hh\:mm\:ss")

$html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Resumen DBA Azure Ginger</title>
<link rel="stylesheet" href="css/asignados.css">
</head>

<body>
<h1>Detalle para DBA de SQL Azure.</h1>

<!-- Mini Dashboard -->
<div class="dashboard">
<div class="card">
<div class="cardTitle">Bases Datos</div>
<div class="cardValue">$totalBases</div>
</div>
<div class="card">
<div class="cardTitle">Usuarios</div>
<div class="cardValue">$usuariosSql</div>
</div>
<div class="card">
<div class="cardTitle">Roles</div>
<div class="cardValue">$totalRoles</div>
</div>
<div class="card">
<div class="cardTitle">Poblacion</div>
<div class="cardValue">$totalRegistros</div>
</div>
</div>

<input type="text" id="globalSearch" placeholder="Buscar en todo el reporte...">
<h2 id="accesosSql">Bases de datos de Azure SQL-GINGER.</h2>
<input type="text" class="groupSearch" data-table="tablaSql" placeholder="Buscar en Azure">

<table id="tablaSql">
<thead>

<!-- Filtros de cabeceras en tablaSql -->
<tr class="filters">
<th><input class="colFilter" data-col="0" data-table="tablaSql"></th>
<th><input class="colFilter" data-col="1" data-table="tablaSql"></th>
<th><input class="colFilter" data-col="2" data-table="tablaSql"></th>
<th><input class="colFilter" data-col="3" data-table="tablaSql"></th>
<th><input class="colFilter" data-col="4" data-table="tablaSql"></th>
</tr>

<tr>
<th onclick="sortTable(0,'tablaSql')">BaseDatos <span class="arrow"></span></th>
<th onclick="sortTable(1,'tablaSql')">Usuario <span class="arrow"></span></th>
<th onclick="sortTable(2,'tablaSql')">Roles <span class="arrow"></span></th>
<th onclick="sortTable(3,'tablaSql')">Permiso <span class="arrow"></span></th>
<th onclick="sortTable(4,'tablaSql')">TotalPermiso <span class="arrow"></span></th>
</tr>
</thead>

<tbody>
$rowsSql
</tbody>
</table>

<br><br><p><strong>Informe generado en: </strong> <span id='totalProceso'>$duracionProc</span></p><br><br>

<script src="js/asignados.js"></script>
</body>
</html>
"@

$html | Out-File $htmlFile -Encoding utf8
Start-Process $htmlFile

Write-Host "Tiempo de ejecucion del proceso $duracionProc" -ForegroundColor DarkRed