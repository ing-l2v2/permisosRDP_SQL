param(
    [string]$Serv,
    [string]$Usr,
    [ValidateSet("R", "W", "RW", "SP", "SM", "RWSP", "RWSM", "JOB", "SYS", "PRF", "ALL")]
    [string]$TipoAcceso,
    [Nullable[int]]$BaseDato,
    [Nullable[int]]$DuracionHoras,
    [Nullable[datetime]]$Expira
)
. "$PSScriptRoot\ServidoresCredenciales.ps1"
$servidoresVerificados = @("10.0.0.102")
# Sync-RemoteCredencialGrupo -Servidores $servidoresVerificados

$TipoAcceso = $TipoAcceso.ToUpper()
#$servSql = "10.0.0.49"
$servSqlFidens = "10.0.0.102"
$accesoSql = "10.0.0.$Serv"

$servidoresVerificados = ($servidoresVerificados + $accesoSql) | Sort-Object -Unique
#Sync-RemoteCredencialGrupo -Servidores $($accesoSql)
. "$PSScriptRoot\ServidoresCredenciales.ps1"
foreach ($cmdServ in $servidoresVerificados) {    
    $accCreds = $Global:ServidoresCredenciales[$cmdServ]
    $accUsr = $accCreds.User
    $accPass = $accCreds.Password
    Write-Host "Validando $cmdServ..."
    Start-Process cmdkey -ArgumentList "/add:$cmdServ", "/user:$accUsr", "/pass:$accPass" -NoNewWindow -Wait
}


$BdRepo = "master"
$UsrSql = "lvilla"
#$Pass49 = "L2v2..20&25.#"
$PassFidens = "lv..2021"
switch ($Serv) {
    { $_ -in "49", "56" } { $Pass = "L2v2..20&25.#" }
    { $_ -in "61", "77", "80", "86", "102" } { $Pass = "lv..2021" }
    { $_ -in "15", "36", "40", "48", "54", "60", "84", "87", "101", "186", "198", "203" } { $Pass = "lv..2021" }
}

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
                Write-Host "[$Server] ERROR: No se pudo escribir en el log después de $maxRetry intentos" -ForegroundColor Red
                return
            }
            Start-Sleep -Milliseconds $delay
        }
    }
}

# ==========================================================
# CONFIGURACION LOG
# ==========================================================
$LogDirSqlAdd = ".\reportes\accesosGestionados"
$LogFileSqlAdd = "$LogDirSqlAdd\accesosASIGNADOS.txt"
if (!(Test-Path $LogDirSqlAdd)) {
    New-Item -ItemType Directory -Path $LogDirSqlAdd -Force | Out-Null
}
function Write-AzureLog {
    param(
        [string]$Mensaje
    )
    $timestamp = (Get-Date -Format "yyyyMMdd HH:mm:ss")
    $linea = "$timestamp $Mensaje"
    $maxRetry = 6
    $delay = 250
    for ($i = 1; $i -le $maxRetry; $i++) {
        try {
            if (!(Test-Path $LogFileSqlAdd)) {
                Set-Content -Path $LogFileSqlAdd -Value $linea
                return
            }
            # leer contenido actual
            $contenido = Get-Content $LogFileSqlAdd -ErrorAction Stop
            # insertar arriba
            $nuevo = @($linea) + $contenido
            # escribir nuevamente
            Set-Content -Path $LogFileSqlAdd -Value $nuevo -ErrorAction Stop
            return
        }
        catch {
            if ($i -eq $maxRetry) {
                Write-Host "ERROR: No se pudo escribir en el log después de $maxRetry intentos." -ForegroundColor Red
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
# ==================================================================
# INFO
# ==================================================================
Write-Host "---------------------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Usuario a gestionar: $Usr    Servidor: $Serv    Tipo de acceso: $TipoAcceso    BaseDato: $BaseDato" -ForegroundColor Cyan
Write-Host "---------------------------------------------------------------------------------" -ForegroundColor Cyan


Import-Module SqlServer
$ConnAcceso = "Server=$accesoSql; Database=$BdRepo; User ID=$UsrSql; Password=$Pass; TrustServerCertificate=True;"
$ConnProyFidens = "Server=$servSqlFidens; Database=$BdRepo; User ID=$UsrSql; Password=$PassFidens; TrustServerCertificate=True;"

if ($null -eq $BaseDato) {
    $BaseDatoSql = "NULL"
}
else { 
    $BaseDatoSql = $BaseDato
}
if ($null -eq $DuracionHoras) { 
    $DuraHorasSql = 48
}
else { 
    $DuraHorasSql = $DuracionHoras
}
if ($null -eq $Expira) { 
    $ExpiraSql = "NULL"
}
else { 
    $ExpiraSql = "'" + $Expira.ToString("yyyy-MM-dd HH:mm:ss") + "'"
}

# Write-Host "[DEBUG::$servSqlFidens sqlAdd] Procediendo en 102 Usr: $Usr, accesoSql: $accesoSql, BaseDatoSql: $BaseDatoSql :: rdu_infraProyFidensSolicitadosRDU"
# Toma informacion de AdminFidens 102
$QuerySqlFidens = @"
EXEC dbo.rdu_infraProyFidensSolicitadosRDU
	@User = '$Usr',
	@Serv = '$accesoSql',
	@Grup = 'SQL',
	@SubPry = $BaseDatoSql;
"@
Write-Host $QuerySqlFidens -foregroundColor White
$solicitados = Invoke-Sqlcmd -Query $QuerySqlFidens -ConnectionString $ConnProyFidens
if (-not $solicitados) {
    Write-Host "[$servSqlFidens sqlAdd] No hay referencias 102.ProyFidens. Puede ser por fecha de inicio." -ForegroundColor Yellow
    $FechaFin = $ExpiraSql
    $NumReg = "NULL"
    $CodUser = "NULL"
}
else {
    $NumReg = ConvertirToValorSql($solicitados["NumReg"])
    $CodUser = ConvertirToValorSql($solicitados["CodUser"])
    $FechaFin = ConvertirToValorSql($solicitados["FechaFin"])
    # Write-Host "[$servSqlFidens sqlAdd] Hubo referencias desde ProyFidens 102. fechaFin = $FechaFin ( $FechaFin.GetType().name ), NumReg = $NumReg ( $NumReg.GetType().name ), CodUser = $CodUser ( $CodUser.GetType().name )" -ForegroundColor Yellow 
}

# Write-Host "[DEBUG $accesoSql sqlAdd] Procediendo en 49 Usuario: $Usr, TipoAcceso: $TipoAcceso, BaseDatoSql: $BaseDatoSql, DuraHorasSql: $DuraHorasSql, ExpiraSql: $ExpiraSql, NumReg: $NumReg :: sp_infra_ini_asignar_permiso_temporal" -ForegroundColor Green
$query = @"
EXEC dbo.sp_infra_ini_asignar_permiso_temporal 
    @Usuario = '$Usr',
    @TipoAcceso = '$TipoAcceso',
    @BaseDatos = $BaseDatoSql,
    @DuracionHoras = $DuraHorasSql,
    @Expira = $FechaFin, 
    @NumReg = $NumReg,
    @CodUser = $CodUser;
"@

# Write-Host "[$accesoSQL] QUERY SQL EJECUTADO:" -Foreground Green
Write-Host $query -foregroundColor Cyan
# Registrar asignación de permiso
# Write-Host "[DEBUG::$accesoSql] Procesando sp_infra_ini_asignar_permiso_temporal. Usuario = $Usr" -ForegroundColor Green
$asignoPermisoTemporal = Invoke-Sqlcmd -Query $query -ConnectionString $ConnAcceso
if (-not $asignoPermisoTemporal) {
    #  -or !$asignoPermisoTemporal.Count
    Write-Host "Error SQL revisar asignoPermisoTemporal en sqlAdd, error en sp_infra_ini_asignar_permiso_temporal : $($asignoPermisoTemporal.ErrorMsg)" -ForegroundColor Red
    exit 1
}
else {
    # Write-Host "[$accesoSql sqlAdd] Permiso asignado. NumRef = $NumReg" -ForegroundColor Green
    # Write-Host "[$servSqlFidens sqlAdd] Actualiza  en 102 NumReg: $NumReg, Estado: 2 :: rdu_infraProyectoFidensRegistrarEstado" -ForegroundColor Green
    $refBD = @()
    foreach ($filaTemporal in $asignoPermisoTemporal) {
        $FechaUpd = ConvertirToValorSql($filaTemporal["FechaFin"])
        $srvBD = ConvertirToValorSql($filaTemporal["BaseDatos"])
        $refBD += $srvBD
        $refIdPermiso = ConvertirToValorSql($filaTemporal["IdPermiso"])
        #$srvNumReg = ConvertirToValorSql($filaTemporal["NumReg"])
        #$srvCodUser = ConvertirToValorSql($filaTemporal["CodUser"])
        #$srvEstado = ConvertirToValorSql($filaTemporal["Est"])
    }
    $lineaBd = ($refBD -join ";")
    # Write-Host("[DEBUG] FechaUpd $FechaUpd") -foregroundColor Red
    #    if ($NumReg -eq $null -or $NumReg -eq "" -or $NumReg -eq "NULL" -or $solicitados.NumReg -is [System.DBNull] -or  $Cod_User -eq $null -or $Cod_User -eq "" -or $CodUser -eq "NULL" -or $solicitados.CodUser -is [System.DBNull] ) {
    if ($NumReg -is [System.DBNull] -or $null -eq $NumReg -or $NumReg -eq "" -or $NumReg -eq "NULL" ) {
        Write-Host "[$servSqlFidens sqlAdd] No se modifico estado EJECUTADO en ProyFidens por NumReg $NumReg " -ForegroundColor Magenta
        Write-Host "-----------------------------------------------------------------------------------------------------------" -ForegroundColor Green
        Write-Host "    Permisos::[$refIdPermiso] Usuario: $Usr    Servidor: $accesoSql    BD: $lineaBd    Estado: $EstadoPry" -ForegroundColor Green
        Write-Host "    NumReg: $NumRegPry    CodUser: $CodUser    FechaFin: $FFIN    HFIN: $HFIN" -ForegroundColor Green
        Write-Host "-----------------------------------------------------------------------------------------------------------" -ForegroundColor Green
        Write-AzureLog ".\sqlAdd -Serv `"$Serv`" -Usr `"$Usr`" -TipoAcceso `"$TipoAcceso`" -BaseDato $BaseDato -DuracionHoras $DuracionHoras -Expira `"$Expira`" "
    }
    else {
        Write-Host "[$servSqlFidens sqlAdd] Asignando estado EJECUTADO en NumReg $NumReg " -ForegroundColor Green
        $queryProyFidens = @"
EXEC dbo.rdu_infraProyectoFidensRegistrarEstado
	@NumReg = $NumReg,
	@Estado = 2,
	@CodUser = $CodUser,
	@FechaFin = $FechaUpd;
"@
        # Write-Host "[$servProyFidens] QUERY SQL EJECUTADO:" -Foreground Green
        Write-Host $queryProyFidens
        try {
            $proyFidens = Invoke-Sqlcmd -Query $queryProyFidens -ConnectionString $ConnProyFidens
            if (-not $proyFidens) {
                Write-Host "Sin  referencias para actualizar ESTADO $Estado en ProyFidens 102." -ForegroundColor Red
            }
            else {
                $NumRegPry = ConvertirToValorSql($proyFidens["NumReg"])
                $EstadoPry = ConvertirToValorSql($proyFidens["Estado"])
                $FFIN = ConvertirToValorSql($proyFidens["FFIN"])
                $HFIN = ConvertirToValorSql($proyFidens["HFIN"])
                $limpiaFFin = $FFIN.Trim("'").Trim()
                $limpiaHFin = $HFIN.Trim("'").Trim()
                $dt = [datetime]::Parse($limpiaFFin)
                $FechaPry = $dt.Date
                $dt = [datetime]::Parse($limpiaHFin)
                $HoraPry = $dt.ToString("HH:mm")
                Write-Host "-----------------------------------------------------------------------------------------------------------" -ForegroundColor Yellow
                Write-Host "    Exito ProyFidens::[$refIdPermiso] Usuario: $Usr    Servidor: $accesoSql    BD: $lineaBd    Estado: $EstadoPry" -ForegroundColor Yellow    
                Write-Host "    NumReg: $NumRegPry    CodUser: $CodUser    FechaFin: $FechaPry    HFIN: $HoraPry" -ForegroundColor Yellow
                Write-Host "-----------------------------------------------------------------------------------------------------------" -ForegroundColor Yellow
                Write-AzureLog ".\sqlAdd -Serv `"$Serv`" -Usr `"$Usr`" -TipoAcceso `"$TipoAcceso`" -BaseDato $BaseDato -DuracionHoras $DuracionHoras -Expira `"$Expira`" "
                #                Write-Output "Resgistro ProyFidens:: Usuario: $Usr    Servidor: $accesoSql    BD: $srvBD    "
                #                Write-Output "NumReg: $NumRegPry    CodUser: $CodUser    Estado: $EstadoPry    FechaFin: $FFIN    HFIN: $HFIN"
            }
        }
        catch {
            Write-Host "[$servSqlFidens sqlAdd] Advertencia: No se pudo registrar en ProyFidens" -ForegroundColor Cyan
            Write-ServerLog -Server $Server -Message "[$servSqlFidens sqlAdd] Advertencia: No se registró ProyFidens [$Usuario] [$accesoSQL] [$BaseDato] [$TipoAcceso]"
        }
    }
}
