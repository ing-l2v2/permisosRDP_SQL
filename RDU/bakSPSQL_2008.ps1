Import-Module SqlServer

$serverName = "10.0.0.102"
$databaseName = "DERCO_CORREDOR"
$login = "lvilla"
$password = "lv..2021"

$Ruta = "C:\Users\lvill\OneDrive - Fidens Lat\_pasos\20260812\3349\bkPrevPaso"

$procedures = @(
  "GEN_CANCELAR_POLIZA_INT_ZURICH",
  "GEN_HOMOLOGAR_MOTIVO_CANCELACION_ZURICH",
  "SP_REGISTRAR_BITACORA_EXCEPCION_ENVIO_POLIZAS",
  "DERCO_REENVIAR_POLIZAS_PROCESS_NOCTURNO"
)

Write-Host ""
Write-Host "==================================================" 
Write-Host "CONEXION SQL SERVER"
Write-Host "==================================================" 
Write-Host "Servidor : $serverName"
Write-Host "Base     : $databaseName"

# Crear directorio
if (!(Test-Path -LiteralPath $Ruta)) {
  New-Item -ItemType Directory -Path $Ruta -Force | Out-Null
}

Write-Host ""
Write-Host "Destino:"
Write-Host $Ruta

# --------------------------------------------------
# CONEXION DIRECTA
# --------------------------------------------------

$connectionString = "Server=$serverName;Database=$databaseName;User ID=$login;Password=$password;Connection Timeout=30;"

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

try {

  Write-Host ""
  Write-Host "Abriendo conexión..."

  $connection.Open()

  Write-Host "Conexion SQL OK." -ForegroundColor Green

}
catch {

  Write-Host ""
  Write-Host "ERROR DE CONEXION SQL" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  exit
}

# --------------------------------------------------
# PROCESAR PROCEDIMIENTOS
# --------------------------------------------------

foreach ($sp in $procedures) {

  Write-Host ""
  Write-Host "==================================================" 
  Write-Host "Buscando procedimiento: $sp"

  $query = @"
SELECT OBJECT_DEFINITION(OBJECT_ID(N'$sp')) AS Definicion
FROM sys.procedures
WHERE name = N'$sp'
"@

  try {

    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $command.CommandTimeout = 60

    $definicion = $command.ExecuteScalar()

    if ($null -eq $definicion) {

      Write-Host ""
      Write-Host "NO ENCONTRADO O SIN DEFINICION: $sp" -ForegroundColor Yellow

      continue
    }

    $definicion = $definicion.ToString()

    if ([string]::IsNullOrWhiteSpace($definicion)) {

      Write-Host ""
      Write-Host "El procedimiento existe pero no tiene definición disponible." -ForegroundColor Yellow

      continue
    }

    # Nombre del archivo
    $archivo = Join-Path $Ruta "$sp.sql"

    Write-Host ""
    Write-Host "Guardando:"
    Write-Host $archivo

    # Guardar archivo
    $definicion | Out-File -FilePath $archivo -Encoding UTF8

    # Verificar archivo
    if (Test-Path -LiteralPath $archivo) {

      $info = Get-Item -LiteralPath $archivo

      Write-Host ""
      Write-Host "RESPALDO OK" -ForegroundColor Green
      Write-Host "Archivo : $($info.FullName)"
      Write-Host "Tamaño  : $($info.Length) bytes"
    }
    else {

      Write-Host ""
      Write-Host "ERROR: No se pudo crear el archivo." -ForegroundColor Red
    }

  }
  catch {

    Write-Host ""
    Write-Host "ERROR PROCESANDO: $sp" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    if ($_.Exception.InnerException) {
      Write-Host "Detalle:"
      Write-Host $_.Exception.InnerException.Message -ForegroundColor Red
    }
  }
}

# --------------------------------------------------
# CERRAR CONEXION
# --------------------------------------------------

if ($connection.State -eq "Open") {
  $connection.Close()
}

Write-Host ""
Write-Host "==================================================" 
Write-Host "PROCESO FINALIZADO"
Write-Host "=================================================="