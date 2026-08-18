<#
===============================================================================
 FASE 3 - RESTAURACION DE APLICACIONES IIS DESDE RAR
===============================================================================
 OBJETIVO
 --------
 Este script restaura las aplicaciones IIS a partir de los archivos RAR
 generados previamente durante la FASE 2.

 IMPORTANTE
 ----------
 ANTES DE EJECUTAR ESTE SCRIPT:
 1. Los archivos RAR DEBEN HABER SIDO DEPOSITADOS PREVIAMENTE
    en el servidor DESTINO:

    C:\Infraestructura\Site\DERCO_CORREDOR_12082026\
 2. Los nombres de los RAR deben corresponder con los nombres de las
    aplicaciones registrados en el archivo de inventario.

    Ejemplo:
    DERCO_CORREDOR_ADMIN_12082026.rar
    DERCO_CORREDOR_CHI_TAR_12082026.rar
    DERCO_CORREDOR_FIRMA_DIGITAL_12082026.rar

 3. Este script NO crea ni modifica todavía:
       - IIS Site
       - Application Pool
       - Bindings
       - Virtual Directories
       - Certificados
       - Configuración IIS
    Esta fase solamente RESTAURA LOS ARCHIVOS FISICOS DE LAS APLICACIONES.

 4. Los archivos existentes serán SOBREESCRITOS.

 5. El script trabaja EXCLUSIVAMENTE con las aplicaciones
    [APPLICATION_xxx] del inventario.
    Los [VIRTUAL_DIRECTORY_xxx] NO serán procesados.

 SERVIDOR DESTINO
 ----------------
 10.0.0.201

 USUARIO
 -------
 FIDENSLAT\leonel.villa

 INVENTARIO
 ----------
 C:\Infraestructura\Site\aplicaciones_DERCO_CORREDOR_12082026.txt

 RAR
 ---
 C:\Infraestructura\Site\DERCO_CORREDOR_12082026\

 DESTINO DE LAS APLICACIONES
 ---------------------------
 Se utilizará PhysicalPath de cada [APPLICATION_xxx].

 EJEMPLO
 -------
 RAR:
 DERCO_CORREDOR_ADMIN_12082026.rar

 PhysicalPath:
 D:\WEBSERVER\DERCO_CORREDOR_ADMIN

 Resultado:
 D:\WEBSERVER\DERCO_CORREDOR_ADMIN\...
===============================================================================
#>

# ============================================================================
# CONFIGURACION
# ============================================================================
$ServidorDestino = "10.0.0.201"
$Usuario = "FIDENSLAT\leonel.villa"
$SiteName = "zenitdesa"
$FechaInventario = Get-Date -Format "ddMMyyyy"
#$FechaInventario = "12082026"

$ArchivoInventario =
"C:\Infraestructura\Site\aplicaciones_${SiteName}_${FechaInventario}.txt"

$DirectorioRAR =
"C:\Infraestructura\Site\${SiteName}_${FechaInventario}"

# ============================================================================
# FUNCIONES
# ============================================================================

function Write-Section {
  param(
    [string]$Titulo
  )

  Write-Host ""
  Write-Host ("=" * 78)
  Write-Host $Titulo
  Write-Host ("=" * 78)
}

function Write-Info {
  param(
    [string]$Texto
  )

  Write-Host $Texto
}

function Write-OK {
  param(
    [string]$Texto
  )

  Write-Host "[OK] $Texto"
}

function Write-WarningMsg {
  param(
    [string]$Texto
  )

  Write-Host "[ADVERTENCIA] $Texto"
}

function Write-ErrorMsg {
  param(
    [string]$Texto
  )

  Write-Host "[ERROR] $Texto"
}

# ============================================================================
# INICIO
# ============================================================================

Clear-Host

Write-Section "FASE 3 - RESTAURACION DE APLICACIONES IIS"

Write-Host ""
Write-Host "Servidor destino : $ServidorDestino"
Write-Host "Usuario          : $Usuario"
Write-Host "Site             : $SiteName"
Write-Host "Inventario       : $ArchivoInventario"
Write-Host "Directorio RAR   : $DirectorioRAR"
Write-Host ""

Write-Host "IMPORTANTE:"
Write-Host ""
Write-Host "Los archivos RAR deben estar previamente depositados en:"
Write-Host ""
Write-Host "    $DirectorioRAR"
Write-Host ""
Write-Host "Antes de continuar verifique que los RAR correspondientes"
Write-Host "a las aplicaciones se encuentren en dicho directorio."
Write-Host ""

$Confirmacion = Read-Host "Escriba CONTINUAR para iniciar la restauracion"

if ($Confirmacion -ne "CONTINUAR") {

  Write-Host ""
  Write-WarningMsg "Proceso cancelado por el usuario."
  exit
}

# ============================================================================
# CREDENCIALES
# ============================================================================

Write-Section "CREDENCIALES"

Write-Host ""
Write-Host "Ingrese las credenciales para conectarse a:"
Write-Host $ServidorDestino
Write-Host ""

$Credential = Get-Credential -UserName $Usuario `
  -Message "Credenciales para conectarse al servidor $ServidorDestino"

if ($null -eq $Credential) {

  Write-ErrorMsg "No se proporcionaron credenciales."
  exit
}

# ============================================================================
# VALIDACION WINRM
# ============================================================================

Write-Section "VALIDANDO WINRM"

try {

  Test-WSMan -ComputerName $ServidorDestino -ErrorAction Stop | Out-Null

  Write-OK "WinRM disponible en $ServidorDestino."
}
catch {

  Write-ErrorMsg "No fue posible establecer comunicacion WinRM."

  Write-Host ""
  Write-Host $_.Exception.Message

  exit
}

# ============================================================================
# VALIDACION DEL INVENTARIO LOCAL
# ============================================================================

Write-Section "VALIDANDO ARCHIVO DE INVENTARIO"

Write-Host ""
Write-Host "Archivo:"
Write-Host $ArchivoInventario
Write-Host ""

if (-not (Test-Path -LiteralPath $ArchivoInventario)) {

  Write-ErrorMsg "No existe el archivo de inventario."

  exit
}

Write-OK "Archivo de inventario encontrado."

# ============================================================================
# LECTURA DEL INVENTARIO
# ============================================================================

Write-Section "LEYENDO INVENTARIO IIS"

$Lineas = Get-Content -LiteralPath $ArchivoInventario -Encoding Default

$Aplicaciones = @()

$AplicacionActual = $null

foreach ($Linea in $Lineas) {

  $Texto = $Linea.Trim()

  # ------------------------------------------------------------
  # Inicio de una APPLICATION
  # ------------------------------------------------------------

  if ($Texto -match '^\[APPLICATION_\d+\]$') {

    if ($null -ne $AplicacionActual) {

      $Aplicaciones += [PSCustomObject]$AplicacionActual
    }

    $AplicacionActual = @{
      Name             = ""
      IISPath          = ""
      PhysicalPath     = ""
      ApplicationPool  = ""
      EnabledProtocols = ""
      PathExists       = ""
    }

    continue
  }

  # ------------------------------------------------------------
  # Si no estamos dentro de una APPLICATION
  # ------------------------------------------------------------

  if ($null -eq $AplicacionActual) {

    continue
  }

  # ------------------------------------------------------------
  # Detectar inicio de otra seccion
  # ------------------------------------------------------------

  if ($Texto -match '^\[') {

    $Aplicaciones += [PSCustomObject]$AplicacionActual

    $AplicacionActual = $null

    continue
  }

  # ------------------------------------------------------------
  # Procesar propiedades
  # ------------------------------------------------------------

  if ($Texto -match '^Name\s*=\s*(.*)$') {

    $AplicacionActual.Name = $matches[1].Trim()

    continue
  }

  if ($Texto -match '^IISPath\s*=\s*(.*)$') {

    $AplicacionActual.IISPath = $matches[1].Trim()

    continue
  }

  if ($Texto -match '^PhysicalPath\s*=\s*(.*)$') {

    $AplicacionActual.PhysicalPath = $matches[1].Trim()

    continue
  }

  if ($Texto -match '^ApplicationPool\s*=\s*(.*)$') {

    $AplicacionActual.ApplicationPool = $matches[1].Trim()

    continue
  }

  if ($Texto -match '^EnabledProtocols\s*=\s*(.*)$') {

    $AplicacionActual.EnabledProtocols = $matches[1].Trim()

    continue
  }

  if ($Texto -match '^PathExists\s*=\s*(.*)$') {

    $AplicacionActual.PathExists = $matches[1].Trim()

    continue
  }
}

# Agregar última aplicación

if ($null -ne $AplicacionActual) {

  $Aplicaciones += [PSCustomObject]$AplicacionActual
}

# ============================================================================
# VALIDACION DEL INVENTARIO
# ============================================================================

Write-Section "RESULTADO DEL INVENTARIO"

Write-Host ""
Write-Host "Aplicaciones encontradas : $($Aplicaciones.Count)"
Write-Host ""

if ($Aplicaciones.Count -eq 0) {

  Write-ErrorMsg "No se encontraron aplicaciones [APPLICATION_xxx]."

  exit
}

$Numero = 0

foreach ($App in $Aplicaciones) {

  $Numero++

  Write-Host ""
  Write-Host ("[{0:D2}] {1}" -f $Numero, $App.Name)
  Write-Host "     IISPath      : $($App.IISPath)"
  Write-Host "     PhysicalPath : $($App.PhysicalPath)"
  Write-Host "     AppPool      : $($App.ApplicationPool)"
}

# ============================================================================
# CREAR SESION REMOTA
# ============================================================================

Write-Section "ESTABLECIENDO SESION REMOTA"

try {

  $Session = New-PSSession `
    -ComputerName $ServidorDestino `
    -Credential $Credential `
    -ErrorAction Stop

  Write-OK "Sesion remota establecida."
}
catch {

  Write-ErrorMsg "No fue posible establecer la sesion remota."

  Write-Host $_.Exception.Message

  exit
}

# ============================================================================
# VALIDAR DIRECTORIO DE RAR
# ============================================================================

Write-Section "VALIDANDO DIRECTORIO DE RAR"

try {

  $RARDirectoryExists = Invoke-Command `
    -Session $Session `
    -ScriptBlock {

    param($Path)

    Test-Path -LiteralPath $Path -PathType Container

  } `
    -ArgumentList $DirectorioRAR `
    -ErrorAction Stop

  if (-not $RARDirectoryExists) {

    Write-ErrorMsg "No existe el directorio de RAR:"
    Write-Host $DirectorioRAR

    Remove-PSSession $Session

    exit
  }

  Write-OK "Directorio de RAR encontrado."
}
catch {

  Write-ErrorMsg "No fue posible validar el directorio de RAR."

  Write-Host $_.Exception.Message

  Remove-PSSession $Session

  exit
}

# ============================================================================
# BUSCAR WINRAR
# ============================================================================

Write-Section "BUSCANDO WINRAR"

$WinRAR = Invoke-Command `
  -Session $Session `
  -ScriptBlock {

  $Rutas = @(
    "C:\Program Files\WinRAR\WinRAR.exe",
    "C:\Program Files (x86)\WinRAR\WinRAR.exe",
    "C:\infraestructura\WinRAR.exe"
  )

  foreach ($Ruta in $Rutas) {

    if (Test-Path -LiteralPath $Ruta -PathType Leaf) {

      return $Ruta
    }
  }

  $Command = Get-Command WinRAR.exe `
    -ErrorAction SilentlyContinue

  if ($null -ne $Command) {

    return $Command.Source
  }

  return $null

}

if ([string]::IsNullOrWhiteSpace($WinRAR)) {

  Write-ErrorMsg "WinRAR no fue encontrado en el servidor destino."

  Remove-PSSession $Session

  exit
}

Write-OK "WinRAR encontrado:"
Write-Host $WinRAR

# ============================================================================
# PRODUCCION DE RESTAURACION
# ============================================================================

Write-Section "INICIANDO RESTAURACION"

Write-Host ""
Write-Host "Servidor destino : $ServidorDestino"
Write-Host "Site             : $SiteName"
Write-Host "Aplicaciones     : $($Aplicaciones.Count)"
Write-Host "Directorio RAR   : $DirectorioRAR"
Write-Host ""

$Resultados = @()

$InicioGeneral = Get-Date

$Indice = 0

foreach ($App in $Aplicaciones) {

  $Indice++

  Write-Host ""
  Write-Section ("APLICACION {0} DE {1}" -f $Indice, $Aplicaciones.Count)

  $NombreAplicacion = $App.Name
  $PhysicalPath = $App.PhysicalPath

  # ------------------------------------------------------------
  # Nombre esperado del RAR
  # ------------------------------------------------------------

  $RARName = "${NombreAplicacion}_${FechaInventario}.rar"

  $RARPath = Join-Path `
    $DirectorioRAR `
    $RARName

  Write-Host ""
  Write-Host "Nombre IIS      : $NombreAplicacion"
  Write-Host "IIS Path        : $($App.IISPath)"
  Write-Host "Physical Path   : $PhysicalPath"
  Write-Host "ApplicationPool : $($App.ApplicationPool)"
  Write-Host ""
  Write-Host "RAR             : $RARName"
  Write-Host "Origen RAR      : $RARPath"
  Write-Host "Destino         : $PhysicalPath"

  # ------------------------------------------------------------
  # Validar RAR
  # ------------------------------------------------------------

  Write-Host ""
  Write-Host "Validando RAR..."

  try {

    $RARInfo = Invoke-Command `
      -Session $Session `
      -ScriptBlock {

      param($Path)

      if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {

        return $null
      }

      Get-Item -LiteralPath $Path

    } `
      -ArgumentList $RARPath `
      -ErrorAction Stop

    if ($null -eq $RARInfo) {

      Write-ErrorMsg "No existe el RAR."

      Write-Host "Esperado:"
      Write-Host $RARPath

      $Resultados += [PSCustomObject]@{
        Aplicacion   = $NombreAplicacion
        PhysicalPath = $PhysicalPath
        RAR          = $RARName
        Estado       = "ERROR - RAR NO ENCONTRADO"
        Tiempo       = ""
      }

      continue
    }

    Write-OK "RAR encontrado."

    $TamanoMB = [math]::Round(
      $RARInfo.Length / 1MB,
      2
    )

    Write-Host "Tamano RAR     : $TamanoMB MB"
  }
  catch {

    Write-ErrorMsg "Error validando el RAR."

    Write-Host $_.Exception.Message

    $Resultados += [PSCustomObject]@{
      Aplicacion   = $NombreAplicacion
      PhysicalPath = $PhysicalPath
      RAR          = $RARName
      Estado       = "ERROR - VALIDACION RAR"
      Tiempo       = ""
    }

    continue
  }

  # ------------------------------------------------------------
  # Crear directorio destino si no existe
  # ------------------------------------------------------------

  Write-Host ""
  Write-Host "Validando directorio destino..."

  try {

    $DestinoCreado = Invoke-Command `
      -Session $Session `
      -ScriptBlock {

      param($Path)

      if (-not (Test-Path -LiteralPath $Path -PathType Container)) {

        New-Item `
          -ItemType Directory `
          -Path $Path `
          -Force `
          -ErrorAction Stop |
        Out-Null

        return "CREATED"
      }

      return "EXISTS"

    } `
      -ArgumentList $PhysicalPath `
      -ErrorAction Stop

    if ($DestinoCreado -eq "CREATED") {

      Write-OK "Directorio creado."
    }
    else {

      Write-OK "Directorio existente."
    }
  }
  catch {

    Write-ErrorMsg "No fue posible crear/acceder al directorio destino."

    Write-Host $_.Exception.Message

    $Resultados += [PSCustomObject]@{
      Aplicacion   = $NombreAplicacion
      PhysicalPath = $PhysicalPath
      RAR          = $RARName
      Estado       = "ERROR - DIRECTORIO"
      Tiempo       = ""
    }

    continue
  }

  # ------------------------------------------------------------
  # Restauracion
  # ------------------------------------------------------------

  Write-Host ""
  Write-Host "Iniciando descompresion..."
  Write-Host ""
  Write-Host "Los archivos existentes seran SOBREESCRITOS."
  Write-Host ""

  $InicioApp = Get-Date

  try {

    $ResultadoRAR = Invoke-Command `
      -Session $Session `
      -ScriptBlock {

      param(
        $WinRARPath,
        $RAR,
        $Destino
      )

      $Argumentos = @(
        "x"
        "-y"
        $RAR
        "$Destino\"
      )

      $Proceso = Start-Process `
        -FilePath $WinRARPath `
        -ArgumentList $Argumentos `
        -Wait `
        -PassThru `
        -WindowStyle Hidden

      return $Proceso.ExitCode

    } `
      -ArgumentList `
      $WinRAR,
    $RARPath,
    $PhysicalPath `
      -ErrorAction Stop

    $FinApp = Get-Date

    $Duracion = $FinApp - $InicioApp

    Write-Host ""
    Write-Host "Proceso WinRAR finalizado."
    Write-Host "Codigo de retorno : $ResultadoRAR"
    Write-Host "Tiempo            : $Duracion"

    # --------------------------------------------------------
    # WinRAR retorna 0 cuando la operacion fue correcta
    # --------------------------------------------------------

    if ($ResultadoRAR -eq 0) {

      Write-OK "Aplicacion restaurada correctamente."

      $Resultados += [PSCustomObject]@{
        Aplicacion   = $NombreAplicacion
        PhysicalPath = $PhysicalPath
        RAR          = $RARName
        Estado       = "OK"
        Tiempo       = $Duracion.ToString()
      }
    }
    else {

      Write-ErrorMsg "WinRAR retorno codigo $ResultadoRAR."

      $Resultados += [PSCustomObject]@{
        Aplicacion   = $NombreAplicacion
        PhysicalPath = $PhysicalPath
        RAR          = $RARName
        Estado       = "ERROR WINRAR $ResultadoRAR"
        Tiempo       = $Duracion.ToString()
      }
    }
  }
  catch {

    $FinApp = Get-Date
    $Duracion = $FinApp - $InicioApp

    Write-ErrorMsg "Error ejecutando WinRAR."

    Write-Host $_.Exception.Message

    $Resultados += [PSCustomObject]@{
      Aplicacion   = $NombreAplicacion
      PhysicalPath = $PhysicalPath
      RAR          = $RARName
      Estado       = "ERROR EXCEPCION"
      Tiempo       = $Duracion.ToString()
    }

    continue
  }

  Write-Host ""
  Write-Host "Finalizada aplicacion $Indice de $($Aplicaciones.Count)."
}

# ============================================================================
# CERRAR SESION
# ============================================================================

Write-Section "CERRANDO SESION REMOTA"

if ($null -ne $Session) {

  Remove-PSSession $Session

  Write-OK "Sesion remota cerrada."
}

# ============================================================================
# RESUMEN
# ============================================================================

$FinGeneral = Get-Date

$DuracionGeneral = $FinGeneral - $InicioGeneral

$OK = @(
  $Resultados |
  Where-Object {
    $_.Estado -eq "OK"
  }
).Count

$Errores = $Resultados.Count - $OK

Write-Section "RESUMEN FINAL"

Write-Host ""
Write-Host "Servidor destino : $ServidorDestino"
Write-Host "Site             : $SiteName"
Write-Host "Aplicaciones     : $($Aplicaciones.Count)"
Write-Host "Correctas        : $OK"
Write-Host "Errores          : $Errores"
Write-Host "Tiempo total     : $DuracionGeneral"
Write-Host ""

Write-Host ("-" * 78)

foreach ($Resultado in $Resultados) {

  if ($Resultado.Estado -eq "OK") {

    Write-Host (
      "[OK]     {0} -> {1}" -f
      $Resultado.Aplicacion,
      $Resultado.PhysicalPath
    )
  }
  else {

    Write-Host (
      "[ERROR]  {0} -> {1}" -f
      $Resultado.Aplicacion,
      $Resultado.Estado
    )
  }
}

Write-Host ("-" * 78)

Write-Host ""

if ($Errores -eq 0) {

  Write-Host "FASE 3 FINALIZADA CORRECTAMENTE."
}
else {

  Write-Host "FASE 3 FINALIZADA CON ERRORES."
  Write-Host "Revise el detalle mostrado anteriormente."
}

Write-Host ""
Write-Host "Presione ENTER para finalizar..."

Read-Host