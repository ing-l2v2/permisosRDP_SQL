Import-Module SqlServer

$server = New-Object Microsoft.SqlServer.Management.Smo.Server "10.0.0.102"

#  $cred = Get-Credential

$server.ConnectionContext.LoginSecure = $false
$server.ConnectionContext.Login = "lvilla"
#$server.ConnectionContext.Password = "L2v2..20&25.#"
$server.ConnectionContext.Password = "lv..2021"

#  $server.ConnectionContext.Login = $cred.UserName
#  $server.ConnectionContext.Password = $cred.GetNetworkCredential().Password

# Mostrar versión de SQL Server
$server.Information.Version

$Ruta = "C:\Users\lvill\OneDrive - Fidens Lat\_pasos\20260812\3349\bkPrevPaso"
#$Ruta = "C:\Users\lvill\OneDrive - Fidens Lat\_pasos\20260812\3349\bkPrevPaso"

# Crear directorio si no existe
if (!(Test-Path -LiteralPath $Ruta)) {
  New-Item -ItemType Directory -Path $Ruta -Force | Out-Null
}

$db = $server.Databases["DERCO_CORREDOR"]

$procedures = @(
  "GEN_CANCELAR_POLIZA_INT_ZURICH",
  "GEN_HOMOLOGAR_MOTIVO_CANCELACION_ZURICH",
  "SP_REGISTRAR_BITACORA_EXCEPCION_ENVIO_POLIZAS",
  "DERCO_REENVIAR_POLIZAS_PROCESS_NOCTURNO"
)

foreach ($sp in $procedures) {
  Write-Host "Buscando procedimiento: $sp"

  $obj = $db.StoredProcedures |
  Where-Object {
    $_.Name -eq $sp -and -not $_.IsSystemObject
  }

  if ($obj) {    
    $archivo = Join-Path $Ruta "$sp.sql"
    Write-Host "Respaldando en: $archivo"

    $obj.Script() | Out-File -FilePath $archivo -Encoding UTF8

    Write-Host "OK: $sp"

    #$obj.Script() | Out-File "$Ruta\$sp.sql" -Encoding UTF8
  }
}