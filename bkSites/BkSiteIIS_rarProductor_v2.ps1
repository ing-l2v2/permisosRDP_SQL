#requires -version 3.0

# ============================================================================
# BkSiteIIS_rarProductor_v3.ps1
#
# FASE 2 - PRODUCTOR DE RAR DE APLICACIONES IIS
#
# Objetivo:
#   Leer el inventario generado por la FASE 1 y generar un RAR independiente
#   por cada APPLICATION IIS.
#
# IMPORTANTE:
#   SOLO se procesan bloques:
#
#       [APPLICATION_xxx]
#       Type = APPLICATION
#
#   NO se procesan:
#       VIRTUAL DIRECTORIES
#       BINDINGS
#       APPLICATION POOLS
#
# ============================================================================

Clear-Host

# ============================================================================
# CONFIGURACION
# ============================================================================

$ServidorOrigen = "10.0.0.59"

$Usuario = "FIDENSLAT\leonel.villa"

$NombreSite = "DERCO_CORREDOR"

$ArchivoAplicaciones = "C:\Infraestructura\Site\aplicaciones_DERCO_CORREDOR_12082026.txt"

$RepositorioBase = "\\10.0.0.179\Backup_BD_APP"

#$Fecha = Get-Date -Format "ddMMyyyy"
$Fecha = Get-Date -Format "12082026"

$RepositorioDestino = Join-Path `
  $RepositorioBase `
  "$ServidorOrigen\$NombreSite"

# Archivo de log
$ArchivoLog = Join-Path `
  $RepositorioDestino `
  "BkSiteIIS_rarProductor_$Fecha.csv"


# ============================================================================
# FUNCION TITULO
# ============================================================================

function Mostrar-Titulo {

  param(
    [string]$Texto
  )

  Write-Host ""
  Write-Host ("=" * 70) -ForegroundColor Cyan
  Write-Host $Texto -ForegroundColor Cyan
  Write-Host ("=" * 70) -ForegroundColor Cyan
  Write-Host ""
}


# ============================================================================
# FUNCION LIMPIAR NOMBRE
# ============================================================================

function Limpiar-NombreArchivo {

  param(
    [string]$Nombre
  )

  # Caracteres no permitidos en Windows
  $Nombre = $Nombre -replace '[\\/:*?"<>|]', '_'

  return $Nombre
}


# ============================================================================
# CREDENCIALES
# ============================================================================

Mostrar-Titulo "CREDENCIALES"

Write-Host "Servidor origen :" -NoNewline
Write-Host " $ServidorOrigen" -ForegroundColor Yellow

Write-Host ""

$Credencial = Get-Credential `
  -UserName $Usuario `
  -Message "Ingrese las credenciales para conectarse a $ServidorOrigen"


# ============================================================================
# VALIDAR ARCHIVO DE INVENTARIO
# ============================================================================

Mostrar-Titulo "VALIDANDO ARCHIVO DE INVENTARIO"

Write-Host "Archivo:"
Write-Host $ArchivoAplicaciones -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $ArchivoAplicaciones)) {

  Write-Host "ERROR:" -ForegroundColor Red
  Write-Host "No existe el archivo de inventario."

  exit 1
}

Write-Host "Archivo encontrado." -ForegroundColor Green


# ============================================================================
# LEER INVENTARIO
# ============================================================================

Mostrar-Titulo "LEYENDO INVENTARIO IIS"

$Lineas = Get-Content -LiteralPath $ArchivoAplicaciones


# ============================================================================
# VARIABLES PARA EL PARSEO
# ============================================================================

$Aplicaciones = @()

$AplicacionActual = $null


# ============================================================================
# PARSEAR BLOQUES APPLICATION
# ============================================================================

foreach ($Linea in $Lineas) {

  $LineaTrim = $Linea.Trim()

  # ------------------------------------------------------------
  # Detectar inicio de APPLICATION
  # ------------------------------------------------------------

  if ($LineaTrim -match '^\[APPLICATION_\d+\]$') {

    # Guardar aplicacion anterior
    if ($null -ne $AplicacionActual) {

      if ($AplicacionActual.Type -eq "APPLICATION") {

        $Aplicaciones += [PSCustomObject]$AplicacionActual
      }
    }

    # Crear nueva aplicacion
    $AplicacionActual = [ordered]@{

      Section          = $LineaTrim
      Type             = ""
      Name             = ""
      IISPath          = ""
      PhysicalPath     = ""
      ApplicationPool  = ""
      EnabledProtocols = ""
    }

    continue
  }


  # ------------------------------------------------------------
  # Si no estamos dentro de APPLICATION, ignorar
  # ------------------------------------------------------------

  if ($null -eq $AplicacionActual) {

    continue
  }


  # ------------------------------------------------------------
  # Type
  # ------------------------------------------------------------

  if ($LineaTrim -match '^Type\s*=\s*(.*)$') {

    $AplicacionActual.Type = $matches[1].Trim()

    continue
  }


  # ------------------------------------------------------------
  # Name
  # ------------------------------------------------------------

  if ($LineaTrim -match '^Name\s*=\s*(.*)$') {

    $AplicacionActual.Name = $matches[1].Trim()

    continue
  }


  # ------------------------------------------------------------
  # IISPath
  # ------------------------------------------------------------

  if ($LineaTrim -match '^IISPath\s*=\s*(.*)$') {

    $AplicacionActual.IISPath = $matches[1].Trim()

    continue
  }


  # ------------------------------------------------------------
  # PhysicalPath
  # ------------------------------------------------------------

  if ($LineaTrim -match '^PhysicalPath\s*=\s*(.*)$') {

    $AplicacionActual.PhysicalPath = $matches[1].Trim()

    continue
  }


  # ------------------------------------------------------------
  # ApplicationPool
  # ------------------------------------------------------------

  if ($LineaTrim -match '^ApplicationPool\s*=\s*(.*)$') {

    $AplicacionActual.ApplicationPool = $matches[1].Trim()

    continue
  }


  # ------------------------------------------------------------
  # EnabledProtocols
  # ------------------------------------------------------------

  if ($LineaTrim -match '^EnabledProtocols\s*=\s*(.*)$') {

    $AplicacionActual.EnabledProtocols = $matches[1].Trim()

    continue
  }
}


# ============================================================================
# GUARDAR ULTIMA APPLICATION
# ============================================================================

if ($null -ne $AplicacionActual) {

  if ($AplicacionActual.Type -eq "APPLICATION") {

    $Aplicaciones += [PSCustomObject]$AplicacionActual
  }
}


# ============================================================================
# VALIDAR APLICACIONES
# ============================================================================

Mostrar-Titulo "RESULTADO DEL INVENTARIO"

Write-Host "Aplicaciones encontradas : " -NoNewline
Write-Host $Aplicaciones.Count -ForegroundColor Green

Write-Host ""

if ($Aplicaciones.Count -eq 0) {

  Write-Host "ERROR: No se encontraron aplicaciones IIS." `
    -ForegroundColor Red

  exit 1
}


# ============================================================================
# MOSTRAR APLICACIONES DETECTADAS
# ============================================================================

$Numero = 0

foreach ($App in $Aplicaciones) {

  $Numero++

  Write-Host ("[{0:D2}] {1}" -f $Numero, $App.Name) `
    -ForegroundColor Green

  Write-Host "     IISPath      : $($App.IISPath)"
  Write-Host "     PhysicalPath : $($App.PhysicalPath)"
  Write-Host "     AppPool      : $($App.ApplicationPool)"
  Write-Host ""
}


# ============================================================================
# VALIDAR WINRM
# ============================================================================

Mostrar-Titulo "VALIDANDO WINRM"

try {

  Test-WSMan `
    -ComputerName $ServidorOrigen `
    -ErrorAction Stop | Out-Null

  Write-Host "WinRM disponible." -ForegroundColor Green
}
catch {

  Write-Host "ERROR: WinRM no esta disponible." `
    -ForegroundColor Red

  Write-Host $_.Exception.Message

  exit 1
}


# ============================================================================
# VALIDAR REPOSITORIO
# ============================================================================

Mostrar-Titulo "VALIDANDO REPOSITORIO DE BACKUP"

Write-Host "Destino:"
Write-Host $RepositorioDestino -ForegroundColor Yellow
Write-Host ""


try {

  if (-not (Test-Path $RepositorioDestino)) {

    Write-Host "Directorio no existe."
    Write-Host "Creando directorio..."

    New-Item `
      -ItemType Directory `
      -Path $RepositorioDestino `
      -Force `
      -ErrorAction Stop | Out-Null

    Write-Host "Directorio creado." `
      -ForegroundColor Green
  }
  else {

    Write-Host "Directorio existente." `
      -ForegroundColor Green
  }
}
catch {

  Write-Host "ERROR accediendo al repositorio." `
    -ForegroundColor Red

  Write-Host $_.Exception.Message

  exit 1
}


# ============================================================================
# CREAR SESION REMOTA
# ============================================================================

Mostrar-Titulo "ESTABLECIENDO SESION REMOTA"

try {

  $Sesion = New-PSSession `
    -ComputerName $ServidorOrigen `
    -Credential $Credencial `
    -ErrorAction Stop

  Write-Host "Sesion remota establecida." `
    -ForegroundColor Green
}
catch {

  Write-Host "ERROR creando sesion remota." `
    -ForegroundColor Red

  Write-Host $_.Exception.Message

  exit 1
}


# ============================================================================
# BUSCAR WINRAR
# ============================================================================

Mostrar-Titulo "BUSCANDO WINRAR"

try {

  $WinRAR = Invoke-Command `
    -Session $Sesion `
    -ScriptBlock {

    $Rutas = @(
      "C:\Program Files\WinRAR\WinRAR.exe",
      "C:\Program Files (x86)\WinRAR\WinRAR.exe",
      "C:\infraestructura\WinRAR.exe"
    )

    foreach ($Ruta in $Rutas) {

      if (Test-Path $Ruta) {

        return $Ruta
      }
    }

    # Buscar mediante registro
    $Registros = @(
      "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
      "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($RegPath in $Registros) {

      $Programas = Get-ItemProperty `
        $RegPath `
        -ErrorAction SilentlyContinue

      foreach ($Programa in $Programas) {

        if ($Programa.DisplayName -like "WinRAR*") {

          if ($Programa.InstallLocation) {

            $Posible = Join-Path `
              $Programa.InstallLocation `
              "WinRAR.exe"

            if (Test-Path $Posible) {

              return $Posible
            }
          }
        }
      }
    }

    return $null
  }

  if ([string]::IsNullOrWhiteSpace($WinRAR)) {

    Write-Host "ERROR: WinRAR no encontrado." `
      -ForegroundColor Red

    Remove-PSSession $Sesion

    exit 1
  }

  Write-Host "WinRAR encontrado:"
  Write-Host $WinRAR -ForegroundColor Green
}
catch {

  Write-Host "ERROR buscando WinRAR." `
    -ForegroundColor Red

  Write-Host $_.Exception.Message

  Remove-PSSession $Sesion

  exit 1
}


# ============================================================================
# PREPARAR LOG
# ============================================================================

$Resultados = @()


# ============================================================================
# PROCESAR APLICACIONES
# ============================================================================

Mostrar-Titulo "INICIANDO PRODUCCION DE RAR"

Write-Host "Servidor origen : $ServidorOrigen"
Write-Host "Site            : $NombreSite"
Write-Host "Destino         : $RepositorioDestino"
Write-Host "Aplicaciones    : $($Aplicaciones.Count)"
Write-Host ""


$Indice = 0


foreach ($App in $Aplicaciones) {

  $Indice++

  $NombreAplicacion = $App.Name

  $PhysicalPath = $App.PhysicalPath

  $NombreSeguro = Limpiar-NombreArchivo $NombreAplicacion

  $NombreRAR = "${NombreSeguro}_${Fecha}.rar"

  $DestinoRAR = Join-Path `
    $RepositorioDestino `
    $NombreRAR


  # ------------------------------------------------------------------------
  # CABECERA
  # ------------------------------------------------------------------------

  Write-Host ""
  Write-Host ("=" * 70) -ForegroundColor DarkCyan

  Write-Host "APLICACION $Indice DE $($Aplicaciones.Count)" `
    -ForegroundColor Cyan

  Write-Host ("=" * 70) -ForegroundColor DarkCyan

  Write-Host "Nombre IIS      : $NombreAplicacion"
  Write-Host "IIS Path        : $($App.IISPath)"
  Write-Host "Physical Path   : $PhysicalPath"
  Write-Host "ApplicationPool : $($App.ApplicationPool)"
  Write-Host "RAR             : $NombreRAR"
  Write-Host ""


  # ------------------------------------------------------------------------
  # VALIDAR PHYSICAL PATH
  # ------------------------------------------------------------------------

  Write-Host "Validando directorio remoto..."

  try {

    $Existe = Invoke-Command `
      -Session $Sesion `
      -ScriptBlock {

      param($Path)

      Test-Path -LiteralPath $Path

    } `
      -ArgumentList $PhysicalPath `
      -ErrorAction Stop


    if (-not $Existe) {

      Write-Host "ERROR: El directorio no existe." `
        -ForegroundColor Red

      $Resultados += [PSCustomObject]@{

        Aplicacion   = $NombreAplicacion
        PhysicalPath = $PhysicalPath
        ArchivoRAR   = $DestinoRAR
        Estado       = "ERROR"
        Detalle      = "PhysicalPath no existe"
      }

      continue
    }

    Write-Host "Directorio encontrado." `
      -ForegroundColor Green
  }
  catch {

    Write-Host "ERROR validando PhysicalPath." `
      -ForegroundColor Red

    Write-Host $_.Exception.Message

    $Resultados += [PSCustomObject]@{

      Aplicacion   = $NombreAplicacion
      PhysicalPath = $PhysicalPath
      ArchivoRAR   = $DestinoRAR
      Estado       = "ERROR"
      Detalle      = $_.Exception.Message
    }

    continue
  }


  # ------------------------------------------------------------------------
  # VALIDAR SI YA EXISTE RAR
  # ------------------------------------------------------------------------

  if (Test-Path $DestinoRAR) {

    Write-Host ""
    Write-Host "ADVERTENCIA: El RAR ya existe." `
      -ForegroundColor Yellow

    Write-Host $DestinoRAR

    Write-Host "Se reemplazara."

    Remove-Item `
      -LiteralPath $DestinoRAR `
      -Force `
      -ErrorAction SilentlyContinue
  }


  # ------------------------------------------------------------------------
  # PRODUCIR RAR
  # ------------------------------------------------------------------------

  Write-Host ""
  Write-Host "Iniciando compresion..." `
    -ForegroundColor Yellow

  $TiempoInicio = Get-Date


  try {

    $ResultadoRemoto = Invoke-Command `
      -Session $Sesion `
      -ScriptBlock {

      param(
        $WinRARPath,
        $SourcePath,
        $DestinoRAR
      )


      Write-Output "INICIO_COMPRESION"

      Write-Output "Origen : $SourcePath"

      Write-Output "Destino: $DestinoRAR"


      # ------------------------------------------------------------
      # OPCIONES WINRAR
      #
      # a  = Add
      # -r = recursive
      #
      # -x*.rar
      # -x*.zip
      #
      # -x*\temp\*
      # -x*\upload\*
      #
      # -ep1 = excluir ruta raiz del archivo
      # ------------------------------------------------------------

      $Argumentos = @(
        "a"
        "-r"
        "-ep1"
        "-x*.rar"
        "-x*.zip"
        "-x*\temp\*"
        "-x*\upload\*"
        "`"$DestinoRAR`""
        "`"$SourcePath\*`""
      )


      Write-Output "EJECUTANDO_WINRAR"

      Write-Output "$WinRARPath $($Argumentos -join ' ')"


      $Proceso = Start-Process `
        -FilePath $WinRARPath `
        -ArgumentList $Argumentos `
        -Wait `
        -PassThru `
        -NoNewWindow


      Write-Output "EXITCODE=$($Proceso.ExitCode)"


      if ($Proceso.ExitCode -eq 0) {

        Write-Output "RESULTADO=OK"
      }
      else {

        Write-Output "RESULTADO=ERROR"
      }


    } `
      -ArgumentList `
      $WinRAR,
    $PhysicalPath,
    $DestinoRAR `
      -ErrorAction Stop


    # ------------------------------------------------------------
    # MOSTRAR RESULTADO REMOTO
    # ------------------------------------------------------------

    foreach ($LineaResultado in $ResultadoRemoto) {

      Write-Host $LineaResultado
    }


    # ------------------------------------------------------------
    # VALIDAR RAR EN DESTINO
    # ------------------------------------------------------------

    if (Test-Path $DestinoRAR) {

      $InfoRAR = Get-Item $DestinoRAR

      $TiempoFin = Get-Date

      $Duracion = $TiempoFin - $TiempoInicio

      Write-Host ""
      Write-Host "RAR GENERADO CORRECTAMENTE." `
        -ForegroundColor Green

      Write-Host "Archivo : $($InfoRAR.FullName)"
      Write-Host "Tamano  : $([math]::Round($InfoRAR.Length / 1MB,2)) MB"
      Write-Host "Tiempo  : $($Duracion.ToString())"


      $Resultados += [PSCustomObject]@{

        Aplicacion   = $NombreAplicacion
        PhysicalPath = $PhysicalPath
        ArchivoRAR   = $DestinoRAR
        Estado       = "OK"
        Detalle      = "RAR generado correctamente"
        TamanoMB     = [math]::Round(
          $InfoRAR.Length / 1MB,
          2
        )
        Duracion     = $Duracion.ToString()
      }
    }
    else {

      Write-Host ""
      Write-Host "ERROR: WinRAR termino pero el archivo no existe." `
        -ForegroundColor Red


      $Resultados += [PSCustomObject]@{

        Aplicacion   = $NombreAplicacion
        PhysicalPath = $PhysicalPath
        ArchivoRAR   = $DestinoRAR
        Estado       = "ERROR"
        Detalle      = "WinRAR termino pero no se encontro el RAR"
      }
    }

  }
  catch {

    Write-Host ""
    Write-Host "ERROR generando RAR." `
      -ForegroundColor Red

    Write-Host $_.Exception.Message


    $Resultados += [PSCustomObject]@{

      Aplicacion   = $NombreAplicacion
      PhysicalPath = $PhysicalPath
      ArchivoRAR   = $DestinoRAR
      Estado       = "ERROR"
      Detalle      = $_.Exception.Message
    }
  }
}


# ============================================================================
# CERRAR SESION
# ============================================================================

Write-Host ""

Mostrar-Titulo "CERRANDO SESION REMOTA"

Remove-PSSession $Sesion

Write-Host "Sesion cerrada." -ForegroundColor Green


# ============================================================================
# GENERAR LOG
# ============================================================================

Mostrar-Titulo "GENERANDO LOG"

try {

  $Resultados |
  Export-Csv `
    -LiteralPath $ArchivoLog `
    -NoTypeInformation `
    -Encoding UTF8

  Write-Host "Log generado:"
  Write-Host $ArchivoLog -ForegroundColor Green
}
catch {

  Write-Host "No fue posible generar el log." `
    -ForegroundColor Yellow

  Write-Host $_.Exception.Message
}


# ============================================================================
# RESUMEN
# ============================================================================

Mostrar-Titulo "RESUMEN FASE 2"

$Total = $Resultados.Count

$Correctos = @(
  $Resultados |
  Where-Object {
    $_.Estado -eq "OK"
  }
).Count

$Errores = @(
  $Resultados |
  Where-Object {
    $_.Estado -eq "ERROR"
  }
).Count


Write-Host "Aplicaciones detectadas : $($Aplicaciones.Count)"
Write-Host "Aplicaciones procesadas : $Total"
Write-Host "Correctas               : " -NoNewline
Write-Host $Correctos -ForegroundColor Green

Write-Host "Errores                 : " -NoNewline
Write-Host $Errores -ForegroundColor Red

Write-Host ""

foreach ($Resultado in $Resultados) {

  if ($Resultado.Estado -eq "OK") {

    Write-Host "[OK]    " -ForegroundColor Green -NoNewline
    Write-Host $Resultado.Aplicacion
  }
  else {

    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Resultado.Aplicacion

    Write-Host "        $($Resultado.Detalle)" `
      -ForegroundColor Yellow
  }
}


# ============================================================================
# INFORMACION FINAL
# ============================================================================

Write-Host ""

Write-Host ("=" * 70) -ForegroundColor Cyan

Write-Host "FASE 2 FINALIZADA" `
  -ForegroundColor Cyan

Write-Host ("=" * 70) -ForegroundColor Cyan

Write-Host ""

Write-Host "Repositorio:"
Write-Host $RepositorioDestino -ForegroundColor Green

Write-Host ""

Write-Host "Log:"
Write-Host $ArchivoLog -ForegroundColor Green

Write-Host ""

Write-Host "Presione ENTER para finalizar..."

Read-Host