param(
  [ValidateSet("49", "56", "61", "77", "80", "86", "102")]  
  [string]$Serv,
  [string]$Usr,
  [ValidateSet("R", "W", "RW", "SP", "SM", "RWSP", "RWSM", "JOB", "SYS", "PRF", "ALL")]
  [string]$TipoAcceso,
  [Nullable[int]]$BaseDato,
  [Nullable[int]]$DuracionHoras,
  [Nullable[datetime]]$Expira
)
$TipoAcceso = $TipoAcceso.ToUpper()
$servSqlFidens = "10.0.0.102"
$accesoSql = "10.0.0.$Serv"
$BdRepo = "master"
$UsrSql = "lvilla"
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
$LogDate = (Get-Date -Format "yyyyMMdd")
$LogDay = $LogDir + "_" + $LogDate
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
if (!(Test-Path $LogDay)) { New-Item -ItemType Directory -Path $LogDay | Out-Null }
function Write-ServerLog {
  param(
    [string]$Server,
    [string]$Message
  )
  $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  $line = "$timestamp | $Message"
  $path = "$LogDay\$Server.log"
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

$BaseDatoSql = ConvertirToValorSql($BaseDato)
if ($null -eq $DuracionHoras) { 
  $DuraHorasSql = 48
}
else { 
  $DuraHorasSql = $DuracionHoras
}
$ExpiraSql = ConvertirToValorSql($Expira)

# 1 Toma informacion de AdminFidens 102
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
  Write-Host "[$servSqlFidens addSql] No hay referencias en 102.ProyFidens. Puede ser por fecha de inicio." -ForegroundColor Yellow
  $FechaFin = $ExpiraSql
  $NumReg = "NULL"
  $CodUser = "NULL"
  # Revisar si no existe un estado ASIGNADO en servidor 49
}
else {

}