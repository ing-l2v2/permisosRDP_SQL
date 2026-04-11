# sql-ginger.database.windows.net
param(
  [string]$Servidor,
  [Parameter(Mandatory = $true)]
  [string]$BaseDatoIn,
  [string]$Usr,
  [ValidateSet("R", "W", "RW", "SP", "SM", "PRF", "ALL")]
  [string]$TipoAcceso
)

$BaseDato = $BaseDatoIn -split ","
Import-Module SqlServer

Write-Host "== Removiendo permisos en Azure SQL ==" -ForegroundColor Red
Write-Host "Servidor: $Servidor    Bases: $($BaseDato -join ", ")" -ForegroundColor Red
Write-Host "Usuario: $Usr     Tipo: $TipoAcceso" -ForegroundColor Red
Write-Host "--------------------------------------" -ForegroundColor Red

$roles = switch ($TipoAcceso) {
  "R" { @("db_datareader") }
  "W" { @("db_datawriter") }
  "RW" { @("db_datareader", "db_datawriter") }
  "SP" { @("EXECUTE") }
  "SM" { @("ALTER", "CREATE TABLE", "VIEW DEFINITION") }
  "PRF" { @("VIEW DATABASE STATE") }
  "ALL" { @("db_owner") }
}

# ==========================================================
# CONFIGURACION LOG
# ==========================================================
$LogDir = ".\reportes\azure"
$LogFile = "$LogDir\sqlAzAdd.txt"
if (!(Test-Path $LogDir)) {
  New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
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
      if (!(Test-Path $LogFile)) {
        Set-Content -Path $LogFile -Value $linea
        return
      }
      # leer contenido actual
      $contenido = Get-Content $LogFile -ErrorAction Stop
      # insertar arriba
      $nuevo = @($linea) + $contenido
      # escribir nuevamente
      Set-Content -Path $LogFile -Value $nuevo -ErrorAction Stop
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
Write-AzureLog ".\sqlAzRemove.ps1 -Servidor `"$Servidor`" -BaseDato `"$($BaseDato -join '","')`" -Usr `"$Usr`" -TipoAcceso `"$TipoAcceso`""
Write-AzureLog  "`$Lista = `@( `"$($BaseDato -join '","')`" )" 

#====================================================
#  PROCESAR UNA O VARIAS BASES DE DATOS
#====================================================
foreach ($bd in $BaseDato) {
  Write-Host "`n>>> Procesando base: $bd" -ForegroundColor Magenta
  # Conexión
  $Conn = "Server=tcp:$Servidor,1433;Database=$bd;User ID=csilva;Password=Ohdef_1007;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

  foreach ($r in $roles) {
    if ($r -eq "EXECUTE") {
      $sql = "REVOKE EXECUTE FROM [$Usr]"
    }
    elseif ($r -in @("ALTER", "CREATE TABLE", "VIEW DEFINITION")) {
      $sql = "REVOKE $r FROM [$Usr]"
    }
    else {
      $sql = "EXEC sp_droprolemember '$r', '$Usr'"
    }
    Write-Host "Revocando: $sql" -ForegroundColor Yellow
    Invoke-Sqlcmd -Query $sql -ConnectionString $Conn
  }
  Write-AzureLog "Ejecucion .\sqlAzRemove.ps1 -Servidor `"$Servidor`" -BaseDato `"$bd`" -Usr `"$Usr`" -TipoAcceso `"$TipoAcceso`""
}
Write-Host "Permisos removidos correctamente." -ForegroundColor Green