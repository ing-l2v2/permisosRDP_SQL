Import-Module SqlServer

$server = New-Object Microsoft.SqlServer.Management.Smo.Server "10.0.0.49"

#  $cred = Get-Credential

$server.ConnectionContext.LoginSecure = $false
$server.ConnectionContext.Login = "lvilla"
$server.ConnectionContext.Password = "L2v2..20&25.#"

#  $server.ConnectionContext.Login = $cred.UserName
#  $server.ConnectionContext.Password = $cred.GetNetworkCredential().Password

$server.Information.Version

$Ruta = "C:\Users\lvill\OneDrive - Fidens Lat\_pasos\20260713\3319\bkPrevPaso"

if (!(Test-Path $Ruta)) {
  New-Item -ItemType Directory -Path $Ruta | Out-Null
}

$db = $server.Databases["Chilena"]

$procedures = @(
  "API_VTA_GET_STEPPER",
  "API_VTA_GET_ESTADO_COTIZACION",
  "API_VTA_CONSULTA_CLIENTE",
  "API_MF_SINIESTRALIDAD_LIST",
  "API_MF_GET_INFORMACION_FLUJO",
  "API_MF_GET_INFORMACION_VEHICULO",
  "API_VTA_VALIDAR_RUT",
  "API_MF_VALIDAR_PATENTE",
  "API_MF_GET_CONFIGURACION",
  "API_VTA_GET_CONFIGURACIONCOMERCIAL",
  "API_MF_GET_PLANES",
  "API_MF_GET_COTIZACION",
  "API_MF_GET_FLOTA",
  "API_MF_GET_RESPALDOSEMISION",
  "API_MF_GET_POLIZA",
  "SYS_VTA_UPSERT_CLIENTE",
  "SYS_MF_INSERT_VEHICULO",
  "SYS_MF_INSERT_TARIFAVEHICULO",
  "SYS_MF_INSERT_COBERTURASVEHICULO",
  "SYS_MF_GET_PRIMA",
  "SYS_MF_INSERT_TARIFASDET",
  "SYS_MF_INSERT_TARIFASCAB",
  "API_MF_PROCESS_TARIFICAR",
  "API_MF_PDF_COTIZACION_V1",
  "API_MF_SEND_COTIZACION",
  "API_VTA_LIST_COTIZACION",
  "API_MF_PROCESS_CONTRATARINDIVIDUAL",
  "API_MF_PROCESS_CONTRATAR",
  "API_MF_UPDATE_VEHICULO",
  "API_MF_UPDATE_VEHICULOINSPECCION",
  "API_VTA_GET_FULL_URL_DOCUMENTO",
  "API_MF_ADD_VEHICULOINSPECCION",
  "API_MF_REMOVE_VEHICULOINSPECCION",
  "API_VTA_GET_FORMAPAGO",
  "API_VTA_INSERT_RESPALDOEMISION",
  "API_VTA_REMOVE_RESPALDOEMISION",
  "SYS_MF_INSERT_POLIZA",
  "SYS_MF_INSERT_COTIZA",
  "SYS_MF_INSERT_PAGOSPOL",
  "SYS_MF_INSERT_CTRLPOL",
  "API_MF_PROCESS_EMITIR",
  "API_MF_PDF_POLIZA_V1",
  "API_MF_SEND_POLIZA",
  "API_MF_ACTIVATE_POLIZA",
  "API_VTA_UPDATE_DOCUMENTOPOLIZA",
  "API_VTA_UPDATE_DOCUMENTOCOTIZACION",
  "API_MF_SEND_ENROLAMIENTO",
  "SYS_VTA_OBTIENE_SIMULACION_MINIFLOTA",
  "API_VTA_UPDATE_DOCUMENTOCOTIZACION",
  "API_VTA_UPDATE_DOCUMENTOPOLIZA",
  "API_MF_GET_CARGA_HEADERS",
  "API_MF_GET_CARGA_ITEMS"
)

foreach ($sp in $procedures) {
  $obj = $db.StoredProcedures |
  Where-Object {
    $_.Name -eq $sp -and -not $_.IsSystemObject
  }

  if ($obj) {    
    $obj.Script() | Out-File "$Ruta\$sp.sql" -Encoding UTF8
  }
}