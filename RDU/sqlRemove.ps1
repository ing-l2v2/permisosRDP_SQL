param(
  [string]$Serv,
  [string]$Usr,
  [ValidateSet("R", "W", "RW", "SP", "SM", "RWSP", "RWSM", "JOB", "SYS", "PRF", "ALL")]
  [string]$TipoAcceso,
  [Nullable[int]]$BaseDato
)

#$servidoresVerificados = @("10.0.0.102")
$servidoresVerificados = @("10.0.0.56")

$TipoAcceso = $TipoAcceso.ToUpper()
$servSqlFidens = "10.0.0.56"
$accesoSql = "10.0.0.$Serv"
$servidoresVerificados = ($servidoresVerificados + $accesosSql) | Sort-Object -Unique
. "$PSScriptRoot\ServidoresCredenciales.ps1"
foreach ($cmdServ in $servidoresVerificados) {    
  $accCreds = $Global:ServidoresCredenciales[$cmdServ]
  $accUsr = $accCreds.User
  $accPass = $accCreds.Password
  Write-Host "Validando $cmdServ..."
  # Start-Process cmdkey -ArgumentList "/add:$cmdServ", "/user:$accUsr", "/pass:$accPass" -NoNewWindow -Wait
  Start-Process cmdkey -ArgumentList "/add:$cmdServ", "/user:$accUsr", "/pass:$accPass" -NoNewWindow -Wait -RedirectStandardOutput "NUL"
}

$BdRepo = "master"
$UsrSql = "lvilla"
$PassFidens = "L2v2..20&25.#"   # Para acceso a ProyFidens 10.0.0.56
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
$LogFileSqlAdd = "$LogDirSqlAdd\accesosREVOCADOS.txt"
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
function EsNulo {
  param (
    [Parameter(Mandatory = $false)]
    $Value
  )
  if ($Value -is [System.DBNull] -or $null -eq $Value -or $Value -eq "") { return "NULL" }
}
# ==================================================================
# INFO
# ==================================================================
Write-Host "---------------------------------------------------------------------------------"
Write-Host "Usuario a gestionar: $Usr	                     Servidor: $Serv" -ForegroundColor Cyan
Write-Host "Tipo de acceso: $TipoAcceso                      BaseDato: $BaseDato" -ForegroundColor Cyan
Write-Host "---------------------------------------------------------------------------------"
Import-Module SqlServer
$ConnAcceso = "Server=$accesoSql; Database=$BdRepo; User ID=$UsrSql; Password=$Pass; TrustServerCertificate=True;"
$ConnProyFidens = "Server=$servSqlFidens; Database=$BdRepo; User ID=$UsrSql; Password=$PassFidens; TrustServerCertificate=True;"

$BaseDatoSql = ConvertirToValorSql($BaseDato)
if (-not (Test-Connection -ComputerName $accesoSql -Count 1 -Quiet)) {
  Write-Host "[$Server] No responde al ping [$Server]" -ForegroundColor Magenta
  Write-ServerLog -Server $Server -Message "No responde al ping $Server "
  return
}
$query = @"
EXEC sp_infra_ini_revocar_permiso_unitario 
  @Usuario = '$Usr',
  @TipoAcceso = '$TipoAcceso',
  @BaseDatos = $BaseDatoSql;
"@
Write-Host $query -foregroundColor Cyan
$revocoPermisoTemporal = Invoke-Sqlcmd -Query $query -ConnectionString $ConnAcceso
if (-not $revocoPermisoTemporal) {
  Write-Host "Error SQL revisar revocoPermisoTemporal en sqlRemove, No se encontro nada para revocar con estos parametros: $($revocoPermisoTemporal.ErrorMsg)" -ForegroundColor Red
  exit 1
}
else {
  # Write-Host "[$accesoSql sqlRemove] Permiso asignado. NumRef = $NumReg" -ForegroundColor Green
  # Write-Host "[$servSqlFidens sqlRemove] Actualiza  en 102 NumReg: $NumReg, Estado: 2 :: rdu_infraProyectoFidensRegistrarEstado" -ForegroundColor Green
  $refBD = @()
  foreach ($filaTemporal in $revocoPermisoTemporal) {
    $IdPermiso = ConvertirToValorSql($filaTemporal["Id"])
    $UsrRevocado = ConvertirToValorSql($filaTemporal["Usuario"])
    $PermisoRevocado = ConvertirToValorSql($filaTemporal["PermisoAsignado"])
    $BDRevocado = ConvertirToValorSql($filaTemporal["BaseDatos"])
    $FechaUpd = ConvertirToValorSql($filaTemporal["Expira"])
    $Estado = ConvertirToValorSql($filaTemporal["Estado"])
    $NumReg = ConvertirToValorSql($filaTemporal["NumReg"])
    $CodUser = ConvertirToValorSql($filaTemporal["CodUser"])
    $refBD += $BDRevocado
  }
  $lineaBdRevocado = ($refBD -join "; ")
  if ($NumReg -is [System.DBNull] -or $null -eq $NumReg -or $NumReg -eq "" -or $NumReg -eq "NULL" ) {
    Write-Host "---------------------------------------------------------------------------------" -ForegroundColor Green
    Write-Host "PermisoTemp::[$IdPermiso]    NumReg: $NumReg | $CodUser    Estado: $Estado" -ForegroundColor Green
    Write-Host "FechaFin: $FechaUpd         Base de datos: $lineaBdRevocado    Permiso: $PermisoRevocado" -ForegroundColor Green
    Write-Host "Usuario: $UsrRevocado       CodUser: $CodUser           Servidor: $accesoSql" -ForegroundColor Green
    Write-Host "---------------------------------------------------------------------------------" -ForegroundColor Green
    Write-Host "[$servSqlFidens sqlRemove] No se modificará estado REVOCADO en ProyFidens por NumReg NULL " -ForegroundColor Magenta
    Write-AzureLog ".\sqlRemove -Serv `"$Serv`" -Usr `"$Usr`" -TipoAcceso `"$TipoAcceso`" -BaseDato $BaseDato "
  }
  else {
    Write-Host "[$servSqlFidens sqlRemove] Asignando estado REVOCADO en NumReg $NumReg " -ForegroundColor Green
    $queryProyFidens = @"
EXEC rdu_infraProyectoFidensRegistrarEstado
	@NumReg = $NumReg,
	@Estado = 3,
	@CodUser = $CodUser,
	@FechaFin = NULL;
"@

    Write-Host $queryProyFidens -ForegroundColor Cyan
    try {
      $proyFidens = Invoke-Sqlcmd -Query $queryProyFidens -ConnectionString $ConnProyFidens
      if (-not $proyFidens) {
        Write-Host "Sin referencias para actualizar ESTADO $Estado en ProyFidens 102." -ForegroundColor Red
      }
      else {
        $NumRegPry = ConvertirToValorSql($proyFidens["NumReg"])
        $EstadoPry = ConvertirToValorSql($proyFidens["Estado"])
        $FFIN = ConvertirToValorSql($proyFidens["FFIN"])
        $HFIN = ConvertirToValorSql($proyFidens["HFIN"])
        $dt = [datetime]::Parse( $FFIN.Trim("'") )
        $FechaPry = $dt.Date;
        $dt = [datetime]::Parse( $HFIN.Trim("'") )
        $HoraPry = $dt.ToString("HH:mm")
        Write-Host "---------------------------------------------------------------------------------" -ForegroundColor Yellow
        Write-Host "Informe:: [$IdPermiso]   NumReg: $NumRegPry       Estado: $EstadoPry" -ForegroundColor Yellow
        Write-Host "FechaFin: $FechaPry       HFIN: $HoraPry         Base de datos: $lineaBdRevocado    Permiso: $PermisoRevocado" -ForegroundColor Yellow
        Write-Host "Usuario: $Usr       CodUser: $CodUser           Servidor: $accesoSql" -ForegroundColor Yellow
        Write-Host "---------------------------------------------------------------------------------" -ForegroundColor Yellow
        Write-AzureLog ".\sqlRemove -Serv `"$Serv`" -Usr `"$Usr`" -TipoAcceso `"$TipoAcceso`" -BaseDato $BaseDato "
      }
    }
    catch {
      Write-Host "[$servSqlFidens sqlRemove] Advertencia: No se pudo registrar en ProyFidens" -ForegroundColor Yellow
      Write-ServerLog -Server $Server -Message "[$servSqlFidens sqlRemove] Advertencia: No se registró ProyFidens [$Usuario] [$accesoSQL] [$BaseDato] [$TipoAcceso]"
    }
  }
}