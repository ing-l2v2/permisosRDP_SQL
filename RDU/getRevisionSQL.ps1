param(
    [string]$SqlUser,
    [string]$SqlPass,
    [switch]$Registrar
)

$Origenes = @(
    [pscustomobject]@{ Servidor = "10.0.0.49"; User = "lvilla"; Pass = "L2v2..20&25.#" },
    [pscustomobject]@{ Servidor = "10.0.0.56"; User = "lvilla"; Pass = "L2v2..20&25.#" },
    [pscustomobject]@{ Servidor = "10.0.0.61"; User = "lvilla"; Pass = "lv..2021" },
    [pscustomobject]@{ Servidor = "10.0.0.80"; User = "lvilla"; Pass = "lv..2021" },
    [pscustomobject]@{ Servidor = "10.0.0.86"; User = "lvilla"; Pass = "lv..2021" },
    [pscustomobject]@{ Servidor = "10.0.0.102"; User = "lvilla"; Pass = "lv..2021" }
)

function Exec-Sql {
    param(
        [string]$Servidor,
        [string]$Base,
        [string]$Query,
        [string]$User,
        [string]$Pass
    )

    if ($User -and $Pass) {
        $connStr = "Server=$Servidor; Database=$Base; User ID=$User; Password=$Pass;"
    }
    else {        
        $connStr = "Server=$Servidor; Database=$Base; Integrated Security=True;"
    }

    $conn = New-Object System.Data.SqlClient.SqlConnection $connStr
    $cmd = New-Object System.Data.SqlClient.SqlCommand $Query, $conn
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
    $dt = New-Object System.Data.DataTable

    try {
        $conn.Open()
        $adapter.Fill($dt) | Out-Null
    }
    catch {
        Write-Host "Error en $Servidor / $Base - $_" -ForegroundColor Red
    }
    finally {
        $conn.Close()
    }
    return $dt
}

Write-Host "Iniciando revision..." -ForegroundColor Cyan
$inicioProc = Get-Date
$resultadoFinal = @()

# ================================
# PROGRESO + TIEMPO ESTIMADO
# ================================
$total = $Origenes.count
$startTime = Get-Date
$index = 0
foreach ($srv in $Origenes) {
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
        -Activity "Procesando Servidores SQL Locales" `
        -Status "Progreso: $percent% | ETA: $etaText | Base: $db " `
        -PercentComplete $percent

    # 1. Obtener estado del login los habilitados
    $qLogin = "
        SELECT 
            name AS Usuario,
            type_desc AS Tipo,
            CASE WHEN is_disabled = 1 THEN 'NO' ELSE 'SI' END AS LoginHabilitado
        FROM sys.server_principals
        WHERE type IN ('S')
        ORDER BY Usuario, Tipo;
    "
    $loginStates = Exec-Sql -Servidor $($srv.servidor) -Base "master" -Query $qLogin -User $($srv.User) -Pass $($srv.Pass)

    # 2. Obtener bases de usuario
    $qDB = "
        SELECT name 
        FROM sys.databases 
        WHERE database_id > 4 AND state = 0
        ORDER BY name;
    "
    $bases = Exec-Sql -Servidor $($srv.servidor) -Base "master" -Query $qDB -User $($srv.User) -Pass $($srv.Pass)

    foreach ($db in $bases.name) {

        $qRoles = "
            SELECT 
                DB_NAME() AS BaseDatos,
                m.name AS Usuario,
                r.name AS Rol
            FROM sys.database_role_members rm
            INNER JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
            INNER JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
            WHERE m.type IN ('S')
            ORDER BY m.name, r.name;
        "

        $roles = Exec-Sql -Servidor $($srv.servidor) -Base $db -Query $qRoles -User $($srv.User) -Pass $($srv.Pass)

        foreach ($r in $roles) {
            
            # Buscar estado del login
            $loginState = $loginStates | Where-Object { $_.Usuario -eq $r.Usuario }

            $resultadoFinal += [PSCustomObject]@{
                Servidor        = $srv.servidor
                BaseDatos       = $r.BaseDatos
                Usuario         = $r.Usuario
                Rol             = $r.Rol
                LoginHabilitado = $loginState.LoginHabilitado
            }
        }
    }
}
# Cerrar barra de progreso
Write-Progress -Activity "Procesando Servidores SQL Locales" -Completed -Status "Completado"

Write-Host "`nConsulta finalizada." -ForegroundColor Cyan

# Mostrar
# $resultadoFinal | Format-Table -AutoSize

# Crear carpetas
$dirBase = ".\reportes"
$dirCSS = "$dirBase/css"
$dirJS = "$dirBase/js"

foreach ($d in @($dirBase, $dirCSS, $dirJS)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}

# Nombre del archivo
# $fecha = Get-Date -Format "yyyyMMdd_HHmmss"
# $archivoHTML = Join-Path $dirBase "RevisionSQL-$fecha.html"
# $archivoHTML = Join-Path $dirBase "RevisionConexionesLocalesSQL_$fecha.html"
$archivoHTML = Join-Path $dirBase "RevisionConexionesLocalesSQL.html"

# Crear combos dinámicos
$fServ = ($resultadoFinal.Servidor | Sort-Object -Unique)
$fUsr = ($resultadoFinal.Usuario | Sort-Object -Unique)
$fBD = ($resultadoFinal.BaseDatos | Sort-Object -Unique)
$fRol = ($resultadoFinal.Rol | Sort-Object -Unique)
$fLog = ($resultadoFinal.LoginHabilitado | Sort-Object -Unique)

function Combo($id, $data, $label) {
    $h = "<label>$label :</label> <select id='$id' class='filtro-columna'><option value=''>Todos</option>"
    foreach ($i in $data) { $h += "<option value='$i'>$i</option>" }
    $h += "</select>"
    return $h
}

# Encabezado HTML
$head = @"
<link rel='stylesheet' href='css/reporte-sql.css'>
<script src='js/reporte-sql.js'></script>
"@

$finProceso = Get-Date
$duracionProceso = ($finProceso - $inicioProc).ToString("hh\:mm\:ss")

$pre = @"
<h2>Reporte Usuarios y Roles :: FIDENS SQL Local. </h2>

<input type='text' id='searchBox' placeholder='Buscar...'><br><br>

<div id='filtros'>
$(Combo "fServ" $fServ "Servidor")
$(Combo "fUsr"  $fUsr  "Usuario")
$(Combo "fBD"   $fBD   "BaseDatos")
$(Combo "fRol"  $fRol  "Rol")
$(Combo "fLogin" $fLog "Login")
</div>
"@

$post = @"
<p><strong>Total:</strong> <span id='totalVisible'>$($resultadoFinal.Count)</span> de $($resultadoFinal.Count)</p>
<p><strong>Informe generado en: </strong> <span id='totalProceso'>$($duracionProceso)</span></p><br><br>
"@

# Convertir a HTML
$html = $resultadoFinal | ConvertTo-Html `
    -Property Servidor, BaseDatos, Usuario, Rol, LoginHabilitado `
    -Head $head `
    -PreContent $pre `
    -PostContent $post `
    -Title "Reporte SQL"

# FIX tabla
$html = $html -replace "<table>", "<table id='tablaDatos'>"
$html = $html -replace "<tr><th>", "<thead><tr><th>"
$html = $html -replace "</th></tr>", "</th></tr></thead><tbody>"
$html = $html -replace "</table>", "</tbody></table>"

# Guardar
$html | Out-File -FilePath $archivoHTML -Encoding UTF8

Write-Host "Reporte generado en: $archivoHTML" -ForegroundColor Green

# Abrir en navegador por defecto
Start-Process $archivoHTML

