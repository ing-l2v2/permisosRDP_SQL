#requires -version 2.0

<#
===============================================================================
 SCRIPT : BkSiteIIS_webConfigs.ps1
 FASE   : Identificacion de web.config con cadenas de conexion SQL

 OBJETIVO
 --------
 Leer el archivo aplicaciones.txt generado en la FASE 1 y:

 1. Obtener solamente las APPLICATION_xxx.
 2. Obtener su PhysicalPath.
 3. Buscar archivos web.config dentro de cada aplicacion.
 4. Revisar si contienen cadenas de conexion SQL.
 5. Generar un archivo con el detalle encontrado.

 IMPORTANTE
 ----------
 Este script NO modifica ningun web.config.

 No modifica:
   - IIS
   - archivos
   - permisos
   - connectionStrings
   - aplicaciones

 Solo realiza lectura y genera un informe.

 RESULTADO
 ---------
 C:\Infraestructura\Site\<SITE>_<ddMMyyyy>_webconfigs.txt

 EJEMPLO
 --------
 C:\Infraestructura\Site\DERCO_CORREDOR_14082026_webconfigs.txt

 NOTA
 ----
 El usuario FIDENSLAT\leonel.villa debe tener permisos de lectura
 sobre las rutas de las aplicaciones.
===============================================================================
#>

# ---------------------------------------------------------------------------
# CONFIGURACION
# ---------------------------------------------------------------------------
$ServidorDestino = "10.0.0.201"
$Usuario = "FIDENSLAT\leonel.villa"
$SiteName = "zenitdesa"
$FechaInventario = Get-Date -Format "ddMMyyyy"
$Inventario = "C:\Infraestructura\Site\aplicaciones_{0}_{1}.txt" -f $SiteName, $FechaInventario

# Si el archivo tiene otro nombre, modificar solamente esta variable.
#
# Ejemplo:
# $Inventario = "C:\Infraestructura\Site\aplicaciones_DERCO_CORREDOR_12082026.txt"


# ---------------------------------------------------------------------------
# FUNCIONES
# ---------------------------------------------------------------------------

function Write-Section {
  param(
    [string]$Titulo
  )

  Write-Host ""
  Write-Host ("=" * 78)
  Write-Host $Titulo
  Write-Host ("=" * 78)
}


function Get-ValueFromBlock {
  param(
    [string[]]$Block,
    [string]$Key
  )

  foreach ($line in $Block) {

    if ($line -match ("^\s*" + [regex]::Escape($Key) + "\s*=\s*(.*)$")) {
      return $matches[1].Trim()
    }
  }

  return $null
}


function Test-SqlConnectionString {
  param(
    [string]$FilePath
  )

  # -----------------------------------------------------------------------
  # Indicadores habituales de connection strings SQL Server.
  #
  # No buscamos solamente "connectionStrings", porque puede existir:
  #
  # <add name="..." connectionString="Data Source=..."
  #
  # o:
  #
  # Server=...
  #
  # Data Source=...
  # Initial Catalog=...
  # Integrated Security=...
  # User ID=...
  # Password=...
  # -----------------------------------------------------------------------

  $patterns = @(
    '(?i)<connectionStrings\b',
    '(?i)\bconnectionString\s*=',
    '(?i)\bData\s+Source\s*=',
    '(?i)\bServer\s*=',
    '(?i)\bInitial\s+Catalog\s*=',
    '(?i)\bIntegrated\s+Security\s*=',
    '(?i)\bUser\s+ID\s*=',
    '(?i)\bUserID\s*=',
    '(?i)\bPassword\s*=',
    '(?i)\bPersist\s+Security\s+Info\s*=',
    '(?i)\bTrusted_Connection\s*='
  )

  try {

    $content = Get-Content `
      -LiteralPath $FilePath `
      -Raw `
      -ErrorAction Stop

    foreach ($pattern in $patterns) {

      if ($content -match $pattern) {
        return $true
      }
    }

    return $false
  }
  catch {
    return $false
  }
}


function Get-ConnectionStringLines {
  param(
    [string]$FilePath
  )

  $resultado = @()

  try {

    $lineNumber = 0

    foreach ($line in Get-Content -LiteralPath $FilePath -ErrorAction Stop) {

      $lineNumber++

      if (
        ($line -match '(?i)<connectionStrings\b') -or
        ($line -match '(?i)\bconnectionString\s*=') -or
        ($line -match '(?i)\bData\s+Source\s*=') -or
        ($line -match '(?i)\bServer\s*=') -or
        ($line -match '(?i)\bInitial\s+Catalog\s*=') -or
        ($line -match '(?i)\bIntegrated\s+Security\s*=') -or
        ($line -match '(?i)\bUser\s+ID\s*=') -or
        ($line -match '(?i)\bUserID\s*=') -or
        ($line -match '(?i)\bTrusted_Connection\s*=')
      ) {

        $resultado += ("Linea {0}: {1}" -f $lineNumber, $line.Trim())
      }
    }
  }
  catch {
    # No detenemos el proceso por un archivo que no pueda leerse.
  }

  return $resultado
}


# ---------------------------------------------------------------------------
# INICIO
# ---------------------------------------------------------------------------

Clear-Host

Write-Section "IDENTIFICACION DE WEBCONFIG CON CONNECTION STRING SQL"

Write-Host ""
Write-Host "Usuario esperado : FIDENSLAT\leonel.villa"
Write-Host "Equipo           : $env:COMPUTERNAME"
Write-Host "Fecha             : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
Write-Host ""

# ---------------------------------------------------------------------------
# VALIDAR INVENTARIO
# ---------------------------------------------------------------------------

Write-Section "VALIDANDO ARCHIVO DE INVENTARIO"

Write-Host "Archivo:"
Write-Host $Inventario
Write-Host ""

if (-not (Test-Path -LiteralPath $Inventario -PathType Leaf)) {

  Write-Host "[ERROR] No existe el archivo de inventario." -ForegroundColor Red
  Write-Host ""
  Write-Host "Verifique la variable:"
  Write-Host '$Inventario'
  Write-Host ""

  exit 1
}

Write-Host "[OK] Archivo encontrado."

# ---------------------------------------------------------------------------
# LEER INVENTARIO
# ---------------------------------------------------------------------------

Write-Section "LEYENDO APLICACIONES"

$lineas = Get-Content -LiteralPath $Inventario -ErrorAction Stop

$applications = @()

$currentBlock = @()
$currentName = $null

foreach ($line in $lineas) {

  # Inicio de una APPLICATION
  if ($line -match '^\[APPLICATION_\d+\]$') {

    # Procesar bloque anterior
    if ($currentName -ne $null) {

      $physicalPath = Get-ValueFromBlock `
        -Block $currentBlock `
        -Key "PhysicalPath"

      if ($physicalPath) {

        $applications += [PSCustomObject]@{
          Name         = $currentName
          PhysicalPath = $physicalPath
        }
      }
    }

    $currentBlock = @($line)
    $currentName = $null

    continue
  }

  # Mientras estamos dentro de una APPLICATION
  if ($currentBlock.Count -gt 0) {

    # Si llegamos a otra seccion, cerrar bloque
    if (
      ($line -match '^\[.*\]$') -or
      ($line -match '^={5,}$')
    ) {

      $physicalPath = Get-ValueFromBlock `
        -Block $currentBlock `
        -Key "PhysicalPath"

      if (
        ($currentName -ne $null) -and
        ($physicalPath)
      ) {

        $applications += [PSCustomObject]@{
          Name         = $currentName
          PhysicalPath = $physicalPath
        }
      }

      $currentBlock = @()
      $currentName = $null

      # Si es otra APPLICATION se procesara en la siguiente iteracion
      if ($line -match '^\[APPLICATION_\d+\]$') {
        $currentBlock = @($line)
      }

      continue
    }

    $currentBlock += $line

    if ($line -match '^\s*Name\s*=\s*(.*)$') {
      $currentName = $matches[1].Trim()
    }
  }
}

# Procesar ultimo bloque
if ($currentName -ne $null) {

  $physicalPath = Get-ValueFromBlock `
    -Block $currentBlock `
    -Key "PhysicalPath"

  if ($physicalPath) {

    $applications += [PSCustomObject]@{
      Name         = $currentName
      PhysicalPath = $physicalPath
    }
  }
}

# ---------------------------------------------------------------------------
# VALIDAR APLICACIONES
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host ("Aplicaciones encontradas : {0}" -f $applications.Count)

if ($applications.Count -eq 0) {

  Write-Host ""
  Write-Host "[ERROR] No se encontraron aplicaciones en el inventario." `
    -ForegroundColor Red

  exit 1
}

# ---------------------------------------------------------------------------
# OBTENER NOMBRE DEL SITE
#
# Se intenta obtener desde el nombre del archivo.
#
# aplicaciones_DERCO_CORREDOR_12082026.txt
#
# -> DERCO_CORREDOR
#
# Si no coincide, se utiliza el nombre de la carpeta o se solicita.
# ---------------------------------------------------------------------------

$inventarioName = [System.IO.Path]::GetFileNameWithoutExtension($Inventario)

$siteName = $null

if ($inventarioName -match '^aplicaciones_(.+?)_\d{8}$') {
  $siteName = $matches[1]
}
elseif ($inventarioName -match '^aplicaciones_(.+)$') {
  $siteName = $matches[1]
}
else {
  $siteName = Read-Host "Ingrese el nombre del SITE"
}

if ([string]::IsNullOrWhiteSpace($siteName)) {

  Write-Host "[ERROR] No fue posible determinar el nombre del SITE." `
    -ForegroundColor Red

  exit 1
}

$fecha = Get-Date -Format "ddMMyyyy"

$baseOutput = "C:\Infraestructura\Site"

$outputFile = Join-Path `
  $baseOutput `
("{0}_{1}_webconfigs.txt" -f $siteName, $fecha)


# ---------------------------------------------------------------------------
# CREAR DIRECTORIO DE RESULTADO
# ---------------------------------------------------------------------------

Write-Section "PREPARANDO RESULTADO"

if (-not (Test-Path -LiteralPath $baseOutput)) {

  Write-Host "Creando:"
  Write-Host $baseOutput

  New-Item `
    -ItemType Directory `
    -Path $baseOutput `
    -Force `
  | Out-Null
}

Write-Host ""
Write-Host "Resultado:"
Write-Host $outputFile


# ---------------------------------------------------------------------------
# INICIAR ARCHIVO DE RESULTADO
# ---------------------------------------------------------------------------

$result = @()

$result += "=============================================================================="
$result += "INFORME DE WEBCONFIG CON CONNECTION STRING SQL"
$result += "=============================================================================="
$result += ""
$result += ("Servidor       : {0}" -f $env:COMPUTERNAME)
$result += ("Usuario        : {0}" -f ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name))
$result += ("Site           : {0}" -f $siteName)
$result += ("Fecha          : {0}" -f (Get-Date -Format "dd/MM/yyyy HH:mm:ss"))
$result += ("Inventario     : {0}" -f $Inventario)
$result += ""
$result += "=============================================================================="
$result += ""


# ---------------------------------------------------------------------------
# ANALIZAR APLICACIONES
# ---------------------------------------------------------------------------

$total = $applications.Count
$contador = 0
$encontrados = 0
$errores = 0

foreach ($app in $applications) {

  $contador++

  Write-Host ""
  Write-Host ("[{0}/{1}] {2}" -f $contador, $total, $app.Name)

  Write-Host ("     PhysicalPath : {0}" -f $app.PhysicalPath)

  # -----------------------------------------------------------------------
  # Validar PhysicalPath
  # -----------------------------------------------------------------------

  if (-not (Test-Path -LiteralPath $app.PhysicalPath -PathType Container)) {

    Write-Host "     [OMITIDO] Directorio no encontrado." `
      -ForegroundColor Yellow

    $errores++

    continue
  }

  # -----------------------------------------------------------------------
  # Buscar web.config
  #
  # Se busca recursivamente porque algunas aplicaciones pueden tener
  # configuraciones dentro de subdirectorios.
  # -----------------------------------------------------------------------

  try {

    $webConfigs = Get-ChildItem `
      -LiteralPath $app.PhysicalPath `
      -Filter "web.config" `
      -Recurse `
      -File `
      -Force `
      -ErrorAction Stop
  }
  catch {

    Write-Host "     [ERROR] No fue posible recorrer el directorio." `
      -ForegroundColor Red

    $errores++

    continue
  }

  if ($webConfigs.Count -eq 0) {

    Write-Host "     [OK] No contiene web.config."

    continue
  }

  Write-Host ("     web.config encontrados : {0}" -f $webConfigs.Count)


  # -----------------------------------------------------------------------
  # ANALIZAR CADA WEBCONFIG
  # -----------------------------------------------------------------------

  foreach ($webConfig in $webConfigs) {

    Write-Host ("       Analizando: {0}" -f $webConfig.FullName)

    if (Test-SqlConnectionString -FilePath $webConfig.FullName) {

      $encontrados++

      Write-Host "       [ENCONTRADO] Contiene referencia a SQL/connectionString." `
        -ForegroundColor Green

      $result += "=============================================================================="
      $result += "APLICACION"
      $result += "=============================================================================="
      $result += ("Nombre aplicacion : {0}" -f $app.Name)
      $result += ("PhysicalPath      : {0}" -f $app.PhysicalPath)
      $result += ("Web.config        : {0}" -f $webConfig.FullName)
      $result += ""

      $connectionLines = Get-ConnectionStringLines `
        -FilePath $webConfig.FullName

      if ($connectionLines.Count -gt 0) {

        $result += "REFERENCIAS DETECTADAS:"
        $result += ""

        foreach ($connectionLine in $connectionLines) {
          $result += ("  {0}" -f $connectionLine)
        }

        $result += ""
      }

      $result += ""
    }
    else {

      Write-Host "       [OK] No se detecto connection string SQL."
    }
  }
}


# ---------------------------------------------------------------------------
# RESUMEN
# ---------------------------------------------------------------------------

$result += "=============================================================================="
$result += "RESUMEN"
$result += "=============================================================================="
$result += ("Aplicaciones analizadas              : {0}" -f $total)
$result += ("Aplicaciones/web.config con SQL      : {0}" -f $encontrados)
$result += ("Errores de lectura                   : {0}" -f $errores)
$result += ""
$result += "IMPORTANTE:"
$result += "Este informe solamente identifica archivos web.config que contienen"
$result += "referencias compatibles con cadenas de conexion SQL."
$result += ""
$result += "Los web.config NO fueron modificados."
$result += "=============================================================================="

# ---------------------------------------------------------------------------
# GUARDAR RESULTADO
# ---------------------------------------------------------------------------

Write-Section "GENERANDO ARCHIVO DE RESULTADO"

try {

  $result | Out-File `
    -FilePath $outputFile `
    -Encoding UTF8 `
    -Force `
    -ErrorAction Stop

  Write-Host ""
  Write-Host "[OK] Archivo generado correctamente." `
    -ForegroundColor Green

  Write-Host ""
  Write-Host "Archivo:"
  Write-Host $outputFile

}
catch {

  Write-Host ""
  Write-Host "[ERROR] No fue posible generar el archivo." `
    -ForegroundColor Red

  Write-Host $_.Exception.Message

  exit 1
}


# ---------------------------------------------------------------------------
# RESULTADO FINAL
# ---------------------------------------------------------------------------

Write-Section "PROCESO FINALIZADO"

Write-Host ""
Write-Host ("Aplicaciones analizadas          : {0}" -f $total)
Write-Host ("Con referencias SQL              : {0}" -f $encontrados)
Write-Host ("Errores                          : {0}" -f $errores)
Write-Host ""
Write-Host "Archivo generado:"
Write-Host $outputFile
Write-Host ""

Write-Host "Presione ENTER para finalizar..."
Read-Host