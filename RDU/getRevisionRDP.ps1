<# 
 Script: get-accesos-multiples.ps1
 Obtiene miembros de Administrators y Remote Desktop Users
 en múltiples servidores Windows Server (2008–2019).
 Exporta resultados a un CSV.
#>

<# ================================================================
  Script: monitoreo_accesos.ps1
  Objetivo:
     1. Consultar Administrators y Remote Desktop Users 
        de múltiples servidores Windows (2008 → 2019+)
     2. Diagnosticar por qué un servidor falla
     3. Exportar dos reportes CSV:
        - accesos_servidores.csv
        - diagnostico_servidores.csv
================================================================ #>
param(
    [string[]]$Servidores = @(
        "10.0.0.49", "10.0.0.56", "10.0.0.61", "10.0.0.80",
        "10.0.0.86", "10.0.0.102", "10.0.0.103", "10.0.0.201",
        "10.0.0.53", "10.0.0.203", "10.0.0.48"
    )
)

function Get-WinRMAuth {
    param([string]$Servidor)

    $result = [ordered]@{
        Servidor   = $Servidor
        Puerto5985 = $false
        Puerto5986 = $false
        Basic      = $false
        Negotiate  = $false
        Usar       = "None"
    }

    # Probar puertos
    function Test-Port($ip, $port) {
        try {
            $c = New-Object System.Net.Sockets.TcpClient
            $iar = $c.BeginConnect($ip, $port, $null, $null)
            $wait = $iar.AsyncWaitHandle.WaitOne(800, $false)
            if (!$wait) { return $false }
            $c.EndConnect($iar)
            $c.Close()
            return $true
        }
        catch { return $false }
    }

    $result.Puerto5985 = Test-Port $Servidor 5985
    $result.Puerto5986 = Test-Port $Servidor 5986

    if (-not $result.Puerto5985 -and -not $result.Puerto5986) {
        return $result  # WinRM no disponible
    }

    # Intentar consulta WinRM sin credenciales explícitas (usa cmdkey)
    try {
        $info = winrm get winrm/config/service/auth -r:$Servidor 2>$null

        if ($info -match "Basic\s+=\s+true") { $result.Basic = $true }
        if ($info -match "Negotiate\s+=\s+true") { $result.Negotiate = $true }
    }
    catch {
        # Si falla, probablemente solo permite Negotiate
        $result.Negotiate = $true
    }

    if ($result.Negotiate) { $result.Usar = "Negotiate" }
    elseif ($result.Basic) { $result.Usar = "Basic" }

    return $result
}

function Invoke-CommandSmart {
    param(
        [string]$Servidor,
        [scriptblock]$Script,
        $ArgumentList
    )

    $auth = Get-WinRMAuth -Servidor $Servidor

    if ($auth.Usar -eq "None") {
        throw "WinRM no disponible en $Servidor"
    }

    try {
        return Invoke-Command -ComputerName $Servidor -ScriptBlock $Script `
            -ArgumentList $ArgumentList -Authentication $auth.Usar -ErrorAction Stop
    }
    catch {
        throw "WinRM error en $Servidor usando $($auth.Usar): $($_.Exception.Message)"
    }
}


### =========================================================
### FUNCION: TEST-DE-SERVIDOR (DIAGNÓSTICO COMPLETO)
### =========================================================
function Test-Servidor {
    param([string]$Servidor)

    $diag = [ordered]@{
        Servidor         = $Servidor
        Ping             = "?"
        Puerto445_SMB    = "?"
        Puerto135_RPC    = "?"
        WinRM_5985_HTTP  = "?"
        WinRM_5986_HTTPS = "?"
        RemoteRegistry   = "?"
        Acceso_WinNT     = "?"
        Acceso_WMI       = "?"
        # WinRM_Auth       = "?"
    }

    # --- Ping ---
    $ping = Test-Connection -Count 1 -Quiet -ComputerName $Servidor
    $diag.Ping = if ($ping) { "OK" } else { "Falla" }

    if (-not $ping) { return [PSCustomObject]$diag }

    # --- Prueba de puertos TCP ---
    function Test-Port($ip, $port) {
        try {
            $c = New-Object System.Net.Sockets.TcpClient
            $iar = $c.BeginConnect($ip, $port, $null, $null)
            $wait = $iar.AsyncWaitHandle.WaitOne(1000, $false)
            if (!$wait) { return $false }
            $c.EndConnect($iar)
            $c.Close()
            return $true
        }
        catch { return $false }
    }

    $diag.Puerto445_SMB = if (Test-Port $Servidor 445) { "OK" } else { "Bloqueado" }
    $diag.Puerto135_RPC = if (Test-Port $Servidor 135) { "OK" } else { "Bloqueado" }
    $diag.WinRM_5985_HTTP = if (Test-Port $Servidor 5985) { "OK" } else { "No" }
    $diag.WinRM_5986_HTTPS = if (Test-Port $Servidor 5986) { "OK" } else { "No" }

    # --- Servicio Remote Registry ---
    try {
        $svc = Get-Service -ComputerName $Servidor -Name RemoteRegistry -ErrorAction Stop
        $diag.RemoteRegistry = $svc.Status
    }
    catch { $diag.RemoteRegistry = "No accesible" }

    # --- Prueba WinNT ---
    try {
        $diag.Acceso_WinNT = "OK"
    }
    catch { $diag.Acceso_WinNT = $_.Exception.Message }

    # --- Prueba WMI ---
    try {        
        $diag.Acceso_WMI = "OK"
    }
    catch { $diag.Acceso_WMI = $_.Exception.Message }

    $auth = Get-WinRMAuth -Servidor $Servidor
    $diag.WinRM_Auth = $auth.Usar

    return [PSCustomObject]$diag
}

### =========================================================
### FUNCION: CONSULTA DE GRUPOS (3 MÉTODOS)
### =========================================================
function Get-LocalGroupMembersSmart {
    param(
        [string]$Servidor,
        [string]$Grupo
    )

    $result = @()

    # -------- MÉTODO 1: WinNT (ADSI) --------
    try {
        $group = [ADSI]"WinNT://$Servidor/$Grupo,group"
        $members = $group.psbase.Invoke("Members")

        foreach ($m in $members) {
            $name = $m.GetType().InvokeMember("Name", 'GetProperty', $null, $m, $null)
            $result += [PSCustomObject]@{
                Servidor = $Servidor
                Grupo    = $Grupo
                Miembro  = $name
                Metodo   = "WinNT"
            }
        }

        if ($result.Count -gt 0) { return $result }
    }
    catch {}
    <#
    # -------- MÉTODO 2: PowerShell Remoting (WinRM) --------
    try {
        if (Test-WSMan $Servidor -ErrorAction Stop) {
            $cmd = {
                param($g)
                (Get-LocalGroupMember -Group $g).Name
            }

            $members = Invoke-Command -ComputerName $Servidor -ScriptBlock $cmd -ArgumentList $Grupo

            foreach ($m in $members) {
                $result += [PSCustomObject]@{
                    Servidor = $Servidor
                    Grupo    = $Grupo
                    Miembro  = $m
                    Metodo   = "WinRM"
                }
            }

            if ($result.Count -gt 0) { return $result }
        }
    }
    catch {}
    #>

    # -------- MÉTODO 2: PowerShell Remoting (WINRM INTELIGENTE) --------
    try {
        $cmd = {
            param($g)
            (Get-LocalGroupMember -Group $g).Name
        }

        $members = Invoke-CommandSmart -Servidor $Servidor -Script $cmd -ArgumentList $Grupo

        foreach ($m in $members) {
            $result += [PSCustomObject]@{
                Servidor = $Servidor
                Grupo    = $Grupo
                Miembro  = $m
                Metodo   = "WinRM"
            }
        }

        if ($result.Count -gt 0) { return $result }
    }
    catch {}    

    # -------- MÉTODO 3: WMI --------
    try {
        $query = Get-WmiObject Win32_GroupUser -ComputerName $Servidor

        foreach ($obj in $query) {
            if ($obj.GroupComponent -like "*$Grupo*") {
                $parts = $obj.PartComponent -split '"'
                $user = $parts[-2]

                $result += [PSCustomObject]@{
                    Servidor = $Servidor
                    Grupo    = $Grupo
                    Miembro  = $user
                    Metodo   = "WMI"
                }
            }
        }

        return $result
    }
    catch {
        return [PSCustomObject]@{
            Servidor = $Servidor
            Grupo    = $Grupo
            Miembro  = "ERROR: $_"
            Metodo   = "ERROR"
        }
    }
}

### =========================================================
### LOOP PRINCIPAL – CONSULTA + DIAGNÓSTICO
### =========================================================
$inicioProc = Get-Date
$Accesos = @()
$DiagFinal = @()

foreach ($srv in $Servidores) {

    Write-Host "→ Consultando $srv ..." -ForegroundColor Cyan

    # Accesos
    $Accesos += Get-LocalGroupMembersSmart -Servidor $srv -Grupo "Administrators"
    $Accesos += Get-LocalGroupMembersSmart -Servidor $srv -Grupo "Remote Desktop Users"

    # Diagnóstico
    $DiagFinal += Test-Servidor -Servidor $srv
}

### =========================================================
### EXPORTAR 2 REPORTES
### =========================================================

# Crear carpeta si no existe
$RutaAccesos = ".\reportes\accesosservidoresRDP.csv"
$RutaDiag = ".\reportes\diagnostico_servidoresRDP.csv"

# Crear carpetas
$dirBase = ".\reportes"
$dirCSS = "$dirBase/css"
$dirJS = "$dirBase/js"
foreach ($d in @($dirBase, $dirCSS, $dirJS)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}


$fileCsvAccesosRDP = "$dirBase/accesosservidoresRDP.csv"
$fileCsvDiagnostico = "$dirBase/diagnostico_servidoresRDP.csv"

foreach ($d in @($dirBase, $dirCSS, $dirJS)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}

$Accesos   | Export-Csv $fileCsvAccesosRDP -Delimiter ";" -NoTypeInformation -Encoding UTF8
$DiagFinal | Export-Csv $fileCsvDiagnostico   -Delimiter ";" -NoTypeInformation -Encoding UTF8

# Nombre del archivo
$fecha = Get-Date -Format "yyyyMMdd_HHmmss"
# $archivoHTML = Join-Path $dirBase "revisionRDP-$fecha.html"
$archivoHTML = Join-Path $dirBase "revisionRDP.html"


Write-Host "`nReportes generados:"
Write-Host "$RutaAccesos"
Write-Host "$RutaDiag"

$finProceso = Get-Date
$duracionProceso = $finProceso - $inicioProc

# ============================
# ENCABEZADO HTML
# ============================
$head = @"
<link rel='stylesheet' href='css/getRevision.css'>
<script src='js/getRevision.js'></script>
"@

# Filtros dinámicos Accesos mediante Combos Dinámicos
$fServA = ($Accesos.Servidor | Sort-Object -Unique)
$fGrupo = ($Accesos.Grupo | Sort-Object -Unique)
$fMetodo = ($Accesos.Metodo | Sort-Object -Unique)

# Filtros dinámicos Diagnóstico mediante Combos Dinámicos
$fServD = ($DiagFinal.Servidor | Sort-Object -Unique)
$fPing = ($DiagFinal.Ping | Sort-Object -Unique)
$fAuth = ($DiagFinal.WinRM_Auth | Sort-Object -Unique)

function Combo($id, $data, $label, $clase) {
    $h = "<label>$label :</label> <select id='$id' class='$clase'><option value=''>Todos</option>"
    foreach ($i in $data) { $h += "<option value='$i'>$i</option>" }
    $h += "</select>"
    return $h
}

# ============================
# BLOQUE ACCESOS
# ============================
$preAccesos = @"
<h2>Reporte de Accesos a Servidores RDP. Duracion: $duracionProceso</h2>

<input type='text' id='searchAccesos' class='searchBox' placeholder='Buscar...'><br><br>

<div id='filtrosAccesos'>
$(Combo "fServA" $fServA "Servidor", "filtro-columna")
$(Combo "fGrupo" $fGrupo "Grupo", "filtro-columna")
$(Combo "fMetodoA" $fMetodo "Método", "filtro-columna")
</div>

<p><strong>Total registros:</strong> 
<span id='totalAccesos'>$($Accesos.Count)</span></p>
"@

$tablaAccesos = $Accesos | ConvertTo-Html `
    -Property Servidor, Grupo, Miembro, Metodo `
    -Fragment

# ============================
# BLOQUE DIAGNÓSTICO
# ============================
$preDiag = @"
<h2>Diagnóstico de Servidores</h2>

<input type='text' id='searchDiag' class='searchBox' placeholder='Buscar...'><br><br>

<div id='filtrosDiag'>
$(Combo "fServD" $fServD "Servidor", "filtro-columna-d")
$(Combo "fPing"  $fPing  "Ping", "filtro-columna-d")
$(Combo "fAuth"  $fAuth  "WinRM Auth", "filtro-columna-d")
</div>

<p><strong>Total registros:</strong> 
<span id='totalDiag'>$($DiagFinal.Count)</span></p>
"@

$tablaDiag = $DiagFinal | ConvertTo-Html `
    -Property Servidor, Ping, Puerto445_SMB, Puerto135_RPC, WinRM_5985_HTTP, WinRM_5986_HTTPS, RemoteRegistry, Acceso_WinNT, Acceso_WMI, WinRM_Auth `
    -Fragment

# ============================
# FORMAR HTML FINAL
# ============================
$head = @"
<meta charset='UTF-8'>
<link rel='stylesheet' href='/css/getRevisionRDP.css'>
<script src='/js/getRevisionRDP.js'></script>
"@
$body = @"
<header class='header-fixed'>
    <h2>Reporte Revisión RDP</h2>
    <div class='search-panel'>
        <input type='text' id='searchGlobal' placeholder='Buscar en todo el reporte…'>
    </div>
</header>

<div class='table-container'>
    $preAccesos
    <table id='tablaAccesos'>$tablaAccesos</table>

    <br><hr><br>

    $preDiag
    <table id='tablaDiag'>$tablaDiag</table>
</div>
"@

$html = ConvertTo-Html -Head $head -Body $body -Title "Revision RDP"

# Agregar THEAD/TBODY solo a tablas con encabezado
$html = $html -replace "<table([^>]*)>\s*<tr><th", "<table$1><thead><tr><th"
$html = $html -replace "</th></tr>\s*</table>", "</th></tr></thead><tbody></tbody></table>"
$html = $html -replace "</thead><tbody></tbody>", "</thead><tbody>"

# GUARDAR HTML
$html | Out-File $archivoHTML -Encoding UTF8


Start-Process $archivoHTML

Write-Host "HTML generado: $archivoHTML" -ForegroundColor Green