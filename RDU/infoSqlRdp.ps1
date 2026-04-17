param(
    [ValidateSet("ASIGNADO", "REVOCADO", "TODO")]
    [string]$Estado,
    [ValidateSet("SU", "US", "GS", "SG", "GC", "CG", "CS", "SC", "FI", "FF", "RV", "ID")]
    [string]$OrdRdu,
    [ValidateSet("UE", "UB", "BU", "BE", "EB", "CB", "BC", "FI", "FF", "RV", "ID")]
    [string]$OrdSql,
    [int]$DiasAtras
)

if ($DiasAtras -lt 0) {
    $DiasAtras = 0
}

$inicioProc = Get-Date

$BdRepo = "master"
$UsrSql = "lvilla"
$Serv = "10.0.0."

# Arreglo de objetos personalizados System.Array [pscustomobject], Contiene PSCustomObject en cada posici�n
$Origenes = @(
    [pscustomobject]@{ Servidor = 49; Pass = "L2v2..20&25.#" },
    [pscustomobject]@{ Servidor = 56; Pass = "L2v2..20&25.#" },
    [pscustomobject]@{ Servidor = 61; Pass = "lv..2021" },
    [pscustomobject]@{ Servidor = 80; Pass = "lv..2021" },
    [pscustomobject]@{ Servidor = 86; Pass = "lv..2021" },
    [pscustomobject]@{ Servidor = 102; Pass = "lv..2021" }
)

$ServidoresLista = $Origenes | ForEach-Object { "10.0.0.$($_.Servidor)" }
. "$PSScriptRoot\ServidoresCredenciales.ps1"
foreach ($cmdServ in $ServidoresLista) {    
    $accCreds = $Global:ServidoresCredenciales[$cmdServ]
    $accUsr = $accCreds.User
    $accPass = $accCreds.Password
    Write-Host "Validando $cmdServ..."
    # Start-Process cmdkey -ArgumentList "/add:$cmdServ", "/user:$accUsr", "/pass:$accPass" -NoNewWindow -Wait
    Start-Process cmdkey -ArgumentList "/add:$cmdServ", "/user:$accUsr", "/pass:$accPass" -NoNewWindow -Wait -RedirectStandardOutput $null
}


$OrdRdu = $OrdRdu.ToUpper()
$OrdSql = $OrdSql.ToUpper()
$Estado = $Estado.ToUpper()
# ==================================================================
# LOGGING
# ==================================================================
$LogDir = ".\logs"
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
function Write-ServerLog {
    param(
        [string]$Server,
        [string]$Message
    )
    $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $line = "$timestamp | $Message"
    $path = "$LogDir\$Server.log"
    $maxRetry = 5
    $delay = 300  # ms
    for ($i = 1; $i -le $maxRetry; $i++) {
        try {
            Add-Content -Path $path -Value $line -ErrorAction Stop
            return
        }
        catch {
            if ($i -eq $maxRetry) {
                Write-Host "[$Server] ERROR: No se pudo escribir en el log despu�s de $maxRetry intentos" -ForegroundColor Red
                return
            }
            Start-Sleep -Milliseconds $delay
        }
    }
}
# ==================================================================
# 		CONVERSION A VALOR SQL
# ==================================================================
function ConvertirToValorSql {
    param(
        [Parameter(Mandatory = $false)]
        $Value
    )
    # 		    NULL o vacío
    # ------------------------------------------
    if ($Value -is [System.DBNull] -or $null -eq $Value -or $Value -eq "") { return "NULL" }    
    #   BOOL / BIT;    # true → 1    # false → 0
    # ------------------------------------------
    if ($Value -is [bool]) { return ($(if ($Value) { 1 }else { 0 })) }
    # 			INT
    # ------------------------------------------
    if ($Value -is [int] -or $Value -is [long]) { return $Value }
    # 		DECIMAL / FLOAT / NUMÉRICOS
    # ------------------------------------------
    if ($Value -is [double] -or $Value -is [float] -or $Value -is [decimal]) {
        return $Value.ToString().Replace(",", ".")  # SQL exige punto
    }
    # 			DATETIME
    # ------------------------------------------    
    if ($Value -is [datetime]) {
        return "'" + $Value.ToString("yyyy-MM-dd HH:mm") + "'"
    }
    # 	STRING — verificar si representa fecha
    #   STRINGS (incluye PSObject → str real)
    # ------------------------------------------
    if ($Value -is [string] -or $Value -is [System.Management.Automation.PSObject]) {
        $str = [string]$Value.trim()        
        # si la cadena está vacía → no es fecha
        if ([string]::IsNullOrWhiteSpace($str)) {
            return "NULL"
        }
        # Write-Host "DEBUG VALUE TYPE = $($str.GetType().FullName)"
        # Write-Host "DEBUG VALUE RAW  = '$str'"
        try {
            <#
            if ([datetime]::TryParse($str, [ref]$parsedDate)) {
                return "'" + $parsedDate.ToString("yyyy-MM-dd HH:mm") + "'"
            }
            #>
            $parsed = [datetime]::Parse($str)
            return "'" + $parsed.ToString("yyyy-MM-dd HH:mm") + "'"
        }
        catch {
            # no es fecha → tratar como texto
            return "'" + $str.Replace("'", "''") + "'"        
        }
        # No es fecha → tratar como texto
        return "'" + $Value.ToString.Replace("'", "''") + "'"
    }
    # Último recurso (otros tipos)
    # ------------------------------------------
    return "'" + $Value.ToString().Replace("'", "''") + "'"
    #return $Value.ToString()
}

Import-Module SqlServer
$asignadosSql = @()     # Acumular los resulados de $asignados

# ================================
# PROGRESO + TIEMPO ESTIMADO
# ================================
$total = $Origenes.count
$startTime = Get-Date
$index = 0

# $ConnProyFidens = "Server=$servSqlFidens; Database=$BdRepo; User ID=$UsrSql; Password=$PassFidens; TrustServerCertificate=True;"
foreach ($r in $Origenes) {

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
        -Activity "Procesando informe de Accesos SQL y RDP Asignadas" `
        -Status "Progreso: $percent% | ETA: $etaText | Base: $r " `
        -PercentComplete $percent


    $accesoSql = "$Serv$($r.Servidor)"
    #$PassAcceso = $r[1]    
    #Write-Host "=================================================================" -foregroundColor Yellow
    #Write-Host "Servidor: $accesoSql :: $Estado SQL $OSql" -foregroundColor Yellow
    $ConnAcceso = "Server=$accesoSql; Database=$BdRepo; User ID=$UsrSql; Password=$($r.Pass); TrustServerCertificate=True;"
    $sqlEstados = @"
EXEC sp_infra_list_asignados_sql
    @Estado = $Estado,
    @SortOp = '$OrdSql',
    @DiasAtras = $DiasAtras
"@
    #Write-Host $sqlEstados
    $asignados = Invoke-Sqlcmd -Query $sqlEstados -ConnectionString $ConnAcceso
    if (-not $asignados) {
        Write-Host "[$accesoSql] No existen accesos ASIGNADOS para SQL." -ForegroundColor Magenta
        continue
    }
    foreach ($a in $asignados) {
        $asignadosSql += [PSCustomObject]@{
            Servidor        = $accesoSql
            Usuario         = ConvertirToValorSql($a["Usuario"])
            BaseDatos       = ConvertirToValorSql($a["BaseDatos"])
            PermisoAsignado = ConvertirToValorSql($a["PermisoAsignado"])
            NumReg          = ConvertirToValorSql($a["NumReg"])
            CodUser         = ConvertirToValorSql($a["CodUser"])
            FechaIni        = ConvertirToValorSql($a["FechaIni"])
            FechaFin        = ConvertirToValorSql($a["FechaFin"])
            IdPermiso       = ConvertirToValorSql($a["IdPermiso"])
            Revocado        = ConvertirToValorSql($a["Revocado"])
            Estado          = ConvertirToValorSql($a["Estado"]).Trim("'")
        }
    }    
    #    Write-Host "================================================================="
    #    $asignados | Select-Object Usuario, BaseDatos, PermisoAsignado, NumReg, CodUser, FechaIni, FechaFin, IdPermiso, Revocado, Estado  | Format-Table
    # $asignados | Format-Table *
}
# Cerrar barra de progreso
Write-Progress -Activity "Procesando informe de Accesos SQL y RDP Asignadas" -Completed -Status "Completado"

#$accSql = "$Serv$($Origenes[0].Servidor)"
#$Pass49 = "L2v2..20&25.#"
$accSql = "10.0.0.49"
$Pass49 = $Origenes[0].Pass
#Write-Host "=================================================================" -foregroundColor Yellow
#Write-Host "Servidor: $accSql Lista conexiones RDP $Estado $ORdu" -foregroundColor Yellow

$Conn49 = "Server=$accSql; Database=$BdRepo; User ID=$UsrSql; Password=$Pass49; TrustServerCertificate=True;"

if ($Estado -eq 'REVOCADO') {
    $orderBy = "Revocado DESC"
}
elseif ($Estado -eq 'ASIGNADO') {
    $orderBy = "Expira DESC"
}
else {
    $orderBy = "Expira DESC, Revocado DESC"
}

$sqlEstadosAzure = @"
    SELECT PARSENAME(Servidor, 4) AS Serv, Usuario, BaseDatos, PermisoAsignado, NumReg, CodUser, 
        CONVERT(VARCHAR(16), Asignacion, 120) AS FechaIni, 
        CONVERT(VARCHAR(16), Expira, 120) AS FechaFin, IdAzure, 
        CONVERT(VARCHAR(16), Revocado, 120) AS Revocado, Estado 
    FROM infraAccesosAzure
    WHERE ('$Estado' NOT IN ('ASIGNADO','REVOCADO') OR Estado = '$Estado')
    AND (
        -- Si el estado es REVOCADO -> filtrar por fecha Revocado
        ('$Estado' = 'REVOCADO' 
        AND CAST(Revocado AS DATE) >= CAST(DATEADD(DAY, -$DiasAtras, GETDATE()) AS DATE)
        )
        OR
        -- Si el estado es SOLICITADO -> filtrar por Expira
        ('$Estado' = 'SOLICITADO'
        AND CAST(Expira AS DATE) >= CAST(DATEADD(DAY, -$DiasAtras, GETDATE()) AS DATE)
        )
        OR
        -- Cualquier otro estado usa Expira
        ('$Estado' NOT IN ('REVOCADO','SOLICITADO')
        AND CAST(Expira AS DATE) >= CAST(DATEADD(DAY, -$DiasAtras, GETDATE()) AS DATE)
        )
    )
    ORDER BY $orderBy;
"@
# Write-Host $sqlEstadosAzure
$asignadosAzure = Invoke-Sqlcmd -Query $sqlEstadosAzure -ConnectionString $Conn49
if (-not $asignadosAzure) {
    Write-Host "[$accSql] No existen accesos ASIGNADOS para SQL AZURE." -ForegroundColor Magenta
    continue
}
foreach ($a in $asignadosAzure) {
    $asignadosSql += [PSCustomObject]@{
        Servidor        = ConvertirToValorSql($a["Serv"])
        Usuario         = ConvertirToValorSql($a["Usuario"])
        BaseDatos       = ConvertirToValorSql($a["BaseDatos"])
        PermisoAsignado = ConvertirToValorSql($a["PermisoAsignado"])
        NumReg          = ConvertirToValorSql($a["NumReg"])
        CodUser         = ConvertirToValorSql($a["CodUser"])
        FechaIni        = ConvertirToValorSql($a["FechaIni"])
        FechaFin        = ConvertirToValorSql($a["FechaFin"])
        IdPermiso       = ConvertirToValorSql($a["IdAzure"])
        Revocado        = ConvertirToValorSql($a["Revocado"])
        Estado          = ConvertirToValorSql($a["Estado"]).Trim("'")
    }
}    

$asignadosRdp = Invoke-Sqlcmd -Query "EXEC dbo.sp_infra_list_asignados_RDU '$Estado', '$OrdRdu', $DiasAtras" -ConnectionString $Conn49
if (-not $asignadosRdp) {
    Write-Host "[$accSql] No existen accesos ASIGNADOS para RDP." -ForegroundColor Magenta	
    return
}
#Write-Host "================================================================="
#$asignadosRdp | Select-Object Usuario, Servidor, Grupo, NumReg, CodUser, FechaIni, FechaFin, Id, Revocado, Estado  | Format-Table
# $asignadosRdp | Format-Table *

$mostrarEstado = $false
if ($Estado -ne 'ASIGNADO' -and $Estado -ne 'REVOCADO') {
    $mostrarEstado = $true
}
$thEstadoSql = ""
$thEstadoRdp = ""
$filterEstadoSql = ""
$filterEstadoRdp = ""
if ($mostrarEstado) {
    $thEstadoSql = "<th onclick=`"sortTable(10,'tablaSql')`">Estado <span class=`"arrow`"></span></th>"
    $thEstadoRdp = "<th onclick=`"sortTable(9,'tablaRdp')`">Estado <span class=`"arrow`"></span></th>"
    $filterEstadoSql = "<th><input class=`"colFilter`" data-col=`"10`" data-table=`"tablaSql`"></th>"
    $filterEstadoRdp = "<th><input class=`"colFilter`" data-col=`"9`" data-table=`"tablaRdp`"></th>"
}

$mostrarRevocado = $false
if ($Estado -ne 'ASIGNADO') {
    $mostrarRevocado = $true
}
$thRevocadoSql = ""
$thRevocadoRdp = ""
$filterRevocadoSql = ""
$filterRevocadoRdp = ""
if ($mostrarRevocado) {
    $thRevocadoSql = "<th onclick=`"sortTable(9,'tablaSql')`">Revocado <span class=`"arrow`"></span></th>"
    $thRevocadoRdp = "<th onclick=`"sortTable(8,'tablaRdp')`">Revocado <span class=`"arrow`"></span></th>"
    $filterRevocadoSql = "<th><input class=`"colFilter`" data-col=`"9`" data-table=`"tablaSql`"></th>"
    $filterRevocadoRdp = "<th><input class=`"colFilter`" data-col=`"8`" data-table=`"tablaRdp`"></th>"
}


$repDir = ".\reportes"
$cssDir = "$repDir\css"
$jsDir = "$repDir\js"

if (!(Test-Path $repDir)) { New-Item -ItemType Directory -Path $repDir | Out-Null }
if (!(Test-Path $cssDir)) { New-Item -ItemType Directory -Path $cssDir | Out-Null }
if (!(Test-Path $jsDir)) { New-Item -ItemType Directory -Path $jsDir | Out-Null }

# Construcción tabla SQL
$rowsSql = ""
foreach ($r in $asignadosSql) {
    $estadoCol = ""
    if ($mostrarEstado) {
        $estadoCol = "<td>$($r.Estado.Trim("'").Trim())</td>"
    }
    $revocadoCol = ""
    if ($mostrarRevocado) {
        $rev = $r.Revocado
        if ($rev) {
            $rev = $rev.Trim("'").Trim().Replace("NULL", "")
        }

        $revocadoCol = "<td>$rev</td>"        
        
        #$revocadoCol = "<td>$($r.Revocado.Trim("'").Trim())</td>"
    }
    $rowsSql += @"
<tr>
<td>$($r.Servidor.Trim("'").Trim())</td>
<td>$($r.Usuario.Trim("'").Trim())</td>
<td>$($r.BaseDatos.Trim("'").Trim())</td>
<td>$($r.PermisoAsignado.Trim("'").Trim())</td>
<td>$($r.NumReg)</td>
<td>$($r.CodUser.Trim("'").Trim())</td>
<td>$($r.FechaIni.Trim("'").Trim())</td>
<td>$($r.FechaFin.Trim("'").Trim())</td>
<td>$($r.IdPermiso)</td>
$revocadoCol
$estadoCol
</tr>
"@
}

# Construcción tabla RDP
$rowsRdp = ""
foreach ($r in $asignadosRdp) {
    $estadoCol = ""
    if ($mostrarEstado) {
        $estadoCol = "<td>$($r.Estado)</td>"
    }
    $revocadoCol = ""
    if ($mostrarRevocado) {
        $revocadoCol = "<td>$($r.Revocado)</td>"
    }
    $rowsRdp += @"
<tr>
<td>$($r.Servidor)</td>
<td>$($r.Usuario)</td>
<td>$($r.Grupo)</td>
<td>$($r.NumReg)</td>
<td>$($r.CodUser)</td>
<td>$($r.FechaIni.Trim("'").Trim())</td>
<td>$($r.FechaFin.Trim("'").Trim())</td>
<td>$($r.Id)</td>
$revocadoCol
$estadoCol
</tr>
"@
}

# Informacion para Dashboard
$totalSql = $asignadosSql.Count
$totalRdp = $asignadosRdp.Count
$totalAccesos = $totalSql + $totalRdp

$servidoresSql = ($asignadosSql.Servidor | Sort-Object -Unique).Count
#$conteoEstadosSql = $asignadosSql | Group-Object Estado | Select-Object Name, Count

$conteoEstadosSql = $asignadosSql |
ForEach-Object {
    $_.Estado.ToString().Trim().Trim("'").ToUpper()
} | Group-Object | Select-Object Name, Count

$estadoAsignadoSql = ($conteoEstadosSql | Where-Object Name -eq "ASIGNADO").Count
$estadoRevocadoSql = ($conteoEstadosSql | Where-Object Name -eq "REVOCADO").Count

$usuariosSql = ($asignadosSql.Usuario | Sort-Object -Unique).Count

Write-Host "Estados $conteoEstadosSql ASIGNADOS $estadoAsignadoSql REVOCADO $estadoRevocadoSql"

$servidoresRdp = ($asignadosRdp.Servidor | Sort-Object -Unique).Count
$conteoEstadosRdp = $asignadosRdp | Group-Object Estado | Select-Object Name, Count
$estadoAsignadoRdp = ($conteoEstadosRdp | Where-Object Name -eq "ASIGNADO").Count
$estadoRevocadoRdp = ($conteoEstadosRdp | Where-Object Name -eq "REVOCADO").Count
$usuariosRdp = ($asignadosRdp.Usuario | Sort-Object -Unique).Count

# Generacion HTML
$fecha = Get-Date -Format "yyyyMMdd"
$finProc = Get-Date
$duracionProc = ($finProc - $inicioProc).ToString("hh\:mm\:ss")
#$htmlFile = "$repDir\asignados_$fecha.html"
$htmlFile = "$repDir\asignados.html"

$html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Accesos SQL y RDP $Estado</title>
<link rel="stylesheet" href="css/asignados.css">
</head>

<body>
<h1>Accesos SQL-<a href="#accesosRdp" class="navLink">RDP</a> [ $Estado ] de los $DiasAtras dias atras respecto a Fin</h1>

<!-- Mini Dashboard -->
<div class="dashboard">
<div class="card">
<div class="cardTitle">Accesos SQL</div>
<div class="cardValue">$totalSql</div>
</div>
<div class="card">
<div class="cardTitle">Servidores SQL</div>
<div class="cardValue">$servidoresSql</div>
</div>
<div class="card">
<div class="cardTitle">Asignado SQL</div>
<div class="cardValue">$estadoAsignadoSql</div>
</div>
<div class="card">
<div class="cardTitle">Revocado SQL</div>
<div class="cardValue">$estadoRevocadoSql</div>
</div>
<div class="card">
<div class="cardTitle">Usuarios SQL</div>
<div class="cardValue">$usuariosSql</div>
</div>
<div class="card">
<div class="cardTitle">Accesos RDP</div>
<div class="cardValue">$totalRdp</div>
</div>
<div class="card">
<div class="cardTitle">Servidores RDP</div>
<div class="cardValue">$servidoresRdp</div>
</div>
<div class="card">
<div class="cardTitle">Asignado RDP</div>
<div class="cardValue">$estadoAsignadoRdp</div>
</div>
<div class="card">
<div class="cardTitle">Revocado RDP</div>
<div class="cardValue">$estadoRevocadoRdp</div>
</div>
<div class="card">
<div class="cardTitle">Usuarios RDP</div>
<div class="cardValue">$usuariosRdp</div>
</div>
<div class="card">
<div class="cardTitle">Total Accesos</div>
<div class="cardValue">$totalAccesos</div>
</div>
</div>

<input type="text" id="globalSearch" placeholder="Buscar en todo el reporte...">
<h2 id="accesosSql">Accesos SQL</h2>
<input type="text" class="groupSearch" data-table="tablaSql" placeholder="Buscar en SQL">

<table id="tablaSql">
<thead>

<!-- Filtros de cabeceras en tablaSql -->
<tr class="filters">
<th><input class="colFilter" data-col="0" data-table="tablaSql"></th>
<th><input class="colFilter" data-col="1" data-table="tablaSql"></th>
<th><input class="colFilter" data-col="2" data-table="tablaSql"></th>
<th><input class="colFilter" data-col="3" data-table="tablaSql"></th>
<th><input class="colFilter" data-col="4" data-table="tablaSql"></th>
<th><input class="colFilter" data-col="5" data-table="tablaSql"></th>
<th><input class="colFilter" data-col="6" data-table="tablaSql"></th>
<th><input class="colFilter" data-col="7" data-table="tablaSql"></th>
<th><input class="colFilter" data-col="8" data-table="tablaSql"></th>
$filterRevocadoSql
$filterEstadoSql
</tr>

<tr>
<th onclick="sortTable(0,'tablaSql')">Servidor <span class="arrow"></span></th>
<th onclick="sortTable(1,'tablaSql')">Usuario <span class="arrow"></span></th>
<th onclick="sortTable(2,'tablaSql')">Base <span class="arrow"></span></th>
<th onclick="sortTable(3,'tablaSql')">Permiso <span class="arrow"></span></th>
<th onclick="sortTable(4,'tablaSql')">NumReg <span class="arrow"></span></th>
<th onclick="sortTable(5,'tablaSql')">CodUser <span class="arrow"></span></th>
<th onclick="sortTable(6,'tablaSql')">Inicio <span class="arrow"></span></th>
<th onclick="sortTable(7,'tablaSql')">Fin <span class="arrow"></span></th>
<th onclick="sortTable(8,'tablaSql')">Id <span class="arrow"></span></th>
$thRevocadoSql
$thEstadoSql
</tr>
</thead>

<tbody>
$rowsSql
</tbody>
</table>

<h2 id="accesosRdp">Accesos RDP</h2>
<input type="text" class="groupSearch" data-table="tablaRdp" placeholder="Buscar en RDP">
<table id="tablaRdp">
<thead>

<!-- Filtros de cabeceras en tablaRdp -->
<tr class="filters">
<th><input class="colFilter" data-col="0" data-table="tablaRdp"></th>
<th><input class="colFilter" data-col="1" data-table="tablaRdp"></th>
<th><input class="colFilter" data-col="2" data-table="tablaRdp"></th>
<th><input class="colFilter" data-col="3" data-table="tablaRdp"></th>
<th><input class="colFilter" data-col="4" data-table="tablaRdp"></th>
<th><input class="colFilter" data-col="5" data-table="tablaRdp"></th>
<th><input class="colFilter" data-col="6" data-table="tablaRdp"></th>
<th><input class="colFilter" data-col="7" data-table="tablaRdp"></th>
$filterRevocadoRdp
$filterEstadoRdp
</tr>

<tr>
<th onclick="sortTable(0,'tablaRdp')">Servidor <span class="arrow"></span></th>
<th onclick="sortTable(1,'tablaRdp')">Usuario <span class="arrow"></span></th>
<th onclick="sortTable(2,'tablaRdp')">Grupo <span class="arrow"></span></th>
<th onclick="sortTable(3,'tablaRdp')">NumReg <span class="arrow"></span></th>
<th onclick="sortTable(4,'tablaRdp')">CodUser <span class="arrow"></span></th>
<th onclick="sortTable(5,'tablaRdp')">Inicio <span class="arrow"></span></th>
<th onclick="sortTable(6,'tablaRdp')">Fin <span class="arrow"></span></th>
<th onclick="sortTable(7,'tablaRdp')">Id <span class="arrow"></span></th>
$thRevocadoRdp
$thEstadoRdp
</tr>
</thead>

<tbody>
$rowsRdp
</tbody>
</table>
<br><br>
<p><strong>Informe generado en: </strong> <span id='totalProceso'>$($duracionProc)</span></p><br><br>
<br><br><br>
<button id="btnSqlTop" onclick="irSql()">Accesos SQL</button>

<script src="js/asignados.js"></script>
</body>
</html>
"@

$html | Out-File $htmlFile -Encoding utf8
Start-Process $htmlFile