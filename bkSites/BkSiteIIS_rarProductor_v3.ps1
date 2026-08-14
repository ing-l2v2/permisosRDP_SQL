#requires -version 3.0

<#
===========================================================================
 BkSiteIIS_rarProductor_v4.ps1

 FASE 2 - PRODUCCION DE RAR EN EL SERVIDOR ORIGEN

 Objetivo:
   1. Conectarse mediante WinRM al servidor IIS origen.
   2. Leer el inventario IIS generado en FASE 1.
   3. Tomar SOLO las secciones [APPLICATION_xxx].
   4. Generar un RAR por cada aplicación.
   5. Generar los RAR EN EL MISMO SERVIDOR ORIGEN.
   6. NO copiar RAR al repositorio 10.0.0.179 en esta fase.

 Exclusiones:
   - *.rar
   - *.zip
   - directorio temp
   - directorio upload

 Ejemplo:

   Servidor origen:
       10.0.0.59

   Inventario:
       C:\Infraestructura\Site\aplicaciones_DERCO_CORREDOR_12082026.txt

   Destino remoto:
       C:\Infraestructura\Site\DERCO_CORREDOR_12082026\

   Resultado:
       DERCO_CORREDOR_ADMIN_12082026.rar
       DERCO_CORREDOR_CHI_TAR_12082026.rar
       ...
===========================================================================#>


# ==========================================================================
# CONFIGURACION
# ==========================================================================

$ServidorOrigen = "10.0.0.59"

$NombreSite = "DERCO_CORREDOR"

#$FechaBackup = Get-Date -Format "ddMMyyyy"
$FechaBackup = "12082026"


# Usuario utilizado para WinRM
$Usuario = "FIDENSLAT\leonel.villa"

# Inventario generado por FASE 1
# $ArchivoInventario = "C:\Infraestructura\Site\aplicaciones_$NombreSite_$FechaBackup.txt"
$ArchivoInventario = "C:\Infraestructura\Site\aplicaciones_{0}_{1}.txt" -f $NombreSite, $FechaBackup

# Directorio donde se generaran los RAR EN EL SERVIDOR ORIGEN
# $DirectorioRAR = "C:\Infraestructura\Site\$NombreSite_$FechaBackup"
$DirectorioRAR = "C:\Infraestructura\Site\{0}_{1}" -f $NombreSite, $FechaBackup

# Nombre esperado de WinRAR
$WinRARNombre = "WinRAR.exe"


# ==========================================================================
# FUNCIONES
# ==========================================================================

function Mostrar-Linea {
  Write-Host ("=" * 70)
}

function Mostrar-Titulo {
  param(
    [string]$Texto
  )

  Write-Host ""
  Mostrar-Linea
  Write-Host $Texto
  Mostrar-Linea
  Write-Host ""
}

function Mostrar-Info {
  param(
    [string]$Texto
  )

  Write-Host $Texto
}

function Mostrar-OK {
  param(
    [string]$Texto
  )

  Write-Host "[OK] $Texto"
}

function Mostrar-ERROR {
  param(
    [string]$Texto
  )

  Write-Host "[ERROR] $Texto" -ForegroundColor Red
}

function Mostrar-WARN {
  param(
    [string]$Texto
  )

  Write-Host "[WARN] $Texto" -ForegroundColor Yellow
}


# ==========================================================================
# INICIO
# ==========================================================================

Clear-Host

Mostrar-Titulo "BkSiteIIS_rarProductor_v4.ps1"

Write-Host "FASE 2 - PRODUCCION DE RAR"
Write-Host ""
Write-Host "Los RAR se generaran EN EL SERVIDOR ORIGEN $ServidorOrigen ."
Write-Host "NO se copiara ningun archivo al repositorio 10.0.0.179."
Write-Host ""

Mostrar-Linea

Write-Host "Servidor origen : $ServidorOrigen"
Write-Host "Usuario         : $Usuario"
Write-Host "Site            : $NombreSite"
Write-Host "Fecha           : $FechaBackup"
Write-Host ""
Write-Host "Inventario local:"
Write-Host $ArchivoInventario
Write-Host ""
Write-Host "Directorio RAR remoto:"
Write-Host $DirectorioRAR

Mostrar-Linea


# ==========================================================================
# VALIDAR INVENTARIO
# ==========================================================================

Mostrar-Titulo "VALIDANDO ARCHIVO DE INVENTARIO"

if (-not (Test-Path -LiteralPath $ArchivoInventario)) {

  Mostrar-ERROR "No existe el archivo de inventario."

  Write-Host ""
  Write-Host "Archivo:"
  Write-Host $ArchivoInventario

  exit 1
}

Mostrar-OK "Archivo de inventario encontrado."

$TamanoInventario = (Get-Item -LiteralPath $ArchivoInventario).Length

Write-Host "Tamano: $TamanoInventario bytes"


# ==========================================================================
# LEER INVENTARIO
# ==========================================================================

Mostrar-Titulo "LEYENDO INVENTARIO IIS"

try {

  $LineasInventario = Get-Content -LiteralPath $ArchivoInventario -ErrorAction Stop

}
catch {

  Mostrar-ERROR "No fue posible leer el archivo de inventario."
  Write-Host $_.Exception.Message

  exit 1
}


# ==========================================================================
# PARSEAR SOLAMENTE APPLICATION_xxx
#
# IMPORTANTE:
#
# NO se procesan:
#
# [VIRTUAL_DIRECTORY_xxx]
#
# solamente:
#
# [APPLICATION_xxx]
# ==========================================================================

$Aplicaciones = @()

$AplicacionActual = $null
$ProcesandoAplicacion = $false

foreach ($Linea in $LineasInventario) {

  $LineaTrim = $Linea.Trim()

  # ---------------------------------------------------------------
  # Detectar inicio de APPLICATION
  # ---------------------------------------------------------------

  if ($LineaTrim -match '^\[APPLICATION_[0-9]+\]$') {

    # Guardar aplicacion anterior
    if ($null -ne $AplicacionActual) {

      $Aplicaciones += [PSCustomObject]$AplicacionActual
    }

    $AplicacionActual = @{
      Name             = ""
      IISPath          = ""
      PhysicalPath     = ""
      ApplicationPool  = ""
      EnabledProtocols = ""
    }

    $ProcesandoAplicacion = $true

    continue
  }


  # ---------------------------------------------------------------
  # Detectar inicio de cualquier otra seccion
  # ---------------------------------------------------------------

  if ($LineaTrim -match '^\[[A-Z_0-9]+\]$') {

    if ($null -ne $AplicacionActual) {

      $Aplicaciones += [PSCustomObject]$AplicacionActual

      $AplicacionActual = $null
    }

    $ProcesandoAplicacion = $false

    continue
  }


  # ---------------------------------------------------------------
  # Procesar propiedades de APPLICATION
  # ---------------------------------------------------------------

  if ($ProcesandoAplicacion -and $null -ne $AplicacionActual) {

    if ($LineaTrim -match '^Name\s*=\s*(.*)$') {

      $AplicacionActual.Name = $Matches[1].Trim()
      continue
    }

    if ($LineaTrim -match '^IISPath\s*=\s*(.*)$') {

      $AplicacionActual.IISPath = $Matches[1].Trim()
      continue
    }

    if ($LineaTrim -match '^PhysicalPath\s*=\s*(.*)$') {

      $AplicacionActual.PhysicalPath = $Matches[1].Trim()
      continue
    }

    if ($LineaTrim -match '^ApplicationPool\s*=\s*(.*)$') {

      $AplicacionActual.ApplicationPool = $Matches[1].Trim()
      continue
    }

    if ($LineaTrim -match '^EnabledProtocols\s*=\s*(.*)$') {

      $AplicacionActual.EnabledProtocols = $Matches[1].Trim()
      continue
    }
  }
}


# Guardar ultima aplicacion

if ($null -ne $AplicacionActual) {

  $Aplicaciones += [PSCustomObject]$AplicacionActual
}


# ==========================================================================
# VALIDAR INVENTARIO
# ==========================================================================

Mostrar-Titulo "RESULTADO DEL INVENTARIO"

if ($Aplicaciones.Count -eq 0) {

  Mostrar-ERROR "No se encontraron aplicaciones IIS."

  exit 1
}

Write-Host "Aplicaciones encontradas : $($Aplicaciones.Count)"
Write-Host ""

$Numero = 0

foreach ($App in $Aplicaciones) {

  $Numero++

  Write-Host ("[{0:D2}] {1}" -f $Numero, $App.Name)
  Write-Host "     IISPath      : $($App.IISPath)"
  Write-Host "     PhysicalPath : $($App.PhysicalPath)"
  Write-Host "     AppPool      : $($App.ApplicationPool)"
  Write-Host ""
}


# ==========================================================================
# CREDENCIALES
# ==========================================================================

Mostrar-Titulo "CREDENCIALES"

Write-Host "Servidor origen : $ServidorOrigen"
Write-Host "Usuario         : $Usuario"
Write-Host ""

$Credencial = Get-Credential -UserName $Usuario -Message "Ingrese el password para conectarse a $ServidorOrigen"


# ==========================================================================
# VALIDAR WINRM
# ==========================================================================

Mostrar-Titulo "VALIDANDO WINRM"

try {

  $SesionTest = New-PSSession `
    -ComputerName $ServidorOrigen `
    -Credential $Credencial `
    -ErrorAction Stop

  Mostrar-OK "WinRM disponible."

}
catch {

  Mostrar-ERROR "No fue posible establecer WinRM."

  Write-Host $_.Exception.Message

  exit 1
}


# ==========================================================================
# VALIDAR / CREAR DIRECTORIO RAR EN SERVIDOR ORIGEN
# ==========================================================================

Mostrar-Titulo "PREPARANDO DIRECTORIO DE RAR"

Write-Host "Servidor : $ServidorOrigen"
Write-Host "Ruta     : $DirectorioRAR"
Write-Host ""

try {

  $ResultadoDirectorio = Invoke-Command `
    -Session $SesionTest `
    -ScriptBlock {

    param(
      $Ruta
    )

    if (-not (Test-Path -LiteralPath $Ruta)) {

      New-Item `
        -ItemType Directory `
        -Path $Ruta `
        -Force `
        -ErrorAction Stop | Out-Null

      return "CREATED"
    }

    return "EXISTS"

  } `
    -ArgumentList $DirectorioRAR `
    -ErrorAction Stop


  if ($ResultadoDirectorio -eq "CREATED") {

    Mostrar-OK "Directorio creado en el servidor origen."

  }
  else {

    Mostrar-OK "Directorio existente en el servidor origen."
  }

}
catch {

  Mostrar-ERROR "No fue posible preparar el directorio remoto."

  Write-Host $_.Exception.Message

  Remove-PSSession $SesionTest -ErrorAction SilentlyContinue

  exit 1
}


# ==========================================================================
# BUSCAR WINRAR
# ==========================================================================

Mostrar-Titulo "BUSCANDO WINRAR EN SERVIDOR ORIGEN"

try {

  $RutaWinRAR = Invoke-Command `
    -Session $SesionTest `
    -ScriptBlock {

    $PosiblesRutas = @(
      "C:\Program Files\WinRAR\WinRAR.exe",
      "C:\Program Files (x86)\WinRAR\WinRAR.exe",
      "C:\infraestructura\WinRAR.exe",
      "C:\Infraestructura\WinRAR\WinRAR.exe"
    )

    foreach ($Ruta in $PosiblesRutas) {

      if (Test-Path -LiteralPath $Ruta -PathType Leaf) {

        return $Ruta
      }
    }

    # Buscar en PATH

    try {

      $Comando = Get-Command WinRAR.exe -ErrorAction SilentlyContinue

      if ($null -ne $Comando) {

        return $Comando.Source
      }
    }
    catch {
    }

    return $null

  } `
    -ErrorAction Stop


  if ([string]::IsNullOrWhiteSpace($RutaWinRAR)) {

    Mostrar-ERROR "WinRAR no fue encontrado en el servidor origen."

    Remove-PSSession $SesionTest -ErrorAction SilentlyContinue

    exit 1
  }


  Mostrar-OK "WinRAR encontrado:"
  Write-Host $RutaWinRAR

}
catch {

  Mostrar-ERROR "Error buscando WinRAR."

  Write-Host $_.Exception.Message

  Remove-PSSession $SesionTest -ErrorAction SilentlyContinue

  exit 1
}


# ==========================================================================
# PRODUCCION DE RAR
# ==========================================================================

Mostrar-Titulo "INICIANDO PRODUCCION DE RAR"

Write-Host "Servidor origen : $ServidorOrigen"
Write-Host "Site            : $NombreSite"
Write-Host "Destino RAR     : $DirectorioRAR"
Write-Host "Aplicaciones    : $($Aplicaciones.Count)"
Write-Host ""

Mostrar-Linea


$Resultados = @()

$NumeroAplicacion = 0

foreach ($App in $Aplicaciones) {

  $NumeroAplicacion++

  Mostrar-Titulo ("APLICACION {0} DE {1}" -f $NumeroAplicacion, $Aplicaciones.Count)

  $NombreAplicacion = $App.Name
  $PhysicalPath = $App.PhysicalPath

  Write-Host "Nombre IIS      : $NombreAplicacion"
  Write-Host "IIS Path        : $($App.IISPath)"
  Write-Host "Physical Path   : $PhysicalPath"
  Write-Host "ApplicationPool : $($App.ApplicationPool)"
  Write-Host ""

  # ----------------------------------------------------------------------
  # Validar datos
  # ----------------------------------------------------------------------

  if ([string]::IsNullOrWhiteSpace($NombreAplicacion)) {

    Mostrar-ERROR "La aplicacion no tiene Name."

    $Resultados += [PSCustomObject]@{
      Numero       = $NumeroAplicacion
      Aplicacion   = $NombreAplicacion
      PhysicalPath = $PhysicalPath
      RAR          = ""
      Estado       = "ERROR - NAME VACIO"
      TamanoMB     = 0
    }

    continue
  }


  if ([string]::IsNullOrWhiteSpace($PhysicalPath)) {

    Mostrar-ERROR "La aplicacion no tiene PhysicalPath."

    $Resultados += [PSCustomObject]@{
      Numero       = $NumeroAplicacion
      Aplicacion   = $NombreAplicacion
      PhysicalPath = $PhysicalPath
      RAR          = ""
      Estado       = "ERROR - PHYSICALPATH VACIO"
      TamanoMB     = 0
    }

    continue
  }


  # ----------------------------------------------------------------------
  # Nombre seguro para archivo
  # ----------------------------------------------------------------------

  $NombreArchivo = $NombreAplicacion

  $NombreArchivo = $NombreArchivo -replace '[\\/:*?"<>|]', '_'

  $NombreRAR = "{0}_{1}.rar" -f $NombreArchivo, $FechaBackup

  $RutaRAR = Join-Path $DirectorioRAR $NombreRAR


  Write-Host "RAR             : $NombreRAR"
  Write-Host "Destino         : $RutaRAR"
  Write-Host ""


  # ----------------------------------------------------------------------
  # Validar PhysicalPath
  # ----------------------------------------------------------------------

  Write-Host "Validando directorio de origen..."

  try {

    $ExisteOrigen = Invoke-Command `
      -Session $SesionTest `
      -ScriptBlock {

      param(
        $Ruta
      )

      Test-Path -LiteralPath $Ruta -PathType Container

    } `
      -ArgumentList $PhysicalPath `
      -ErrorAction Stop


    if (-not $ExisteOrigen) {

      Mostrar-ERROR "El PhysicalPath no existe."

      $Resultados += [PSCustomObject]@{
        Numero       = $NumeroAplicacion
        Aplicacion   = $NombreAplicacion
        PhysicalPath = $PhysicalPath
        RAR          = $NombreRAR
        Estado       = "ERROR - DIRECTORIO NO EXISTE"
        TamanoMB     = 0
      }

      continue
    }


    Mostrar-OK "Directorio de origen encontrado."

  }
  catch {

    Mostrar-ERROR "Error validando PhysicalPath."

    Write-Host $_.Exception.Message

    $Resultados += [PSCustomObject]@{
      Numero       = $NumeroAplicacion
      Aplicacion   = $NombreAplicacion
      PhysicalPath = $PhysicalPath
      RAR          = $NombreRAR
      Estado       = "ERROR - VALIDACION PATH"
      TamanoMB     = 0
    }

    continue
  }


  # ----------------------------------------------------------------------
  # Eliminar RAR anterior
  #
  # SOLO se elimina el RAR que este script va a generar.
  # NO se toca el contenido de la aplicacion.
  # ----------------------------------------------------------------------

  Write-Host "Validando RAR anterior..."

  try {

    $RARAnterior = Invoke-Command `
      -Session $SesionTest `
      -ScriptBlock {

      param(
        $Ruta
      )

      if (Test-Path -LiteralPath $Ruta -PathType Leaf) {

        Remove-Item `
          -LiteralPath $Ruta `
          -Force `
          -ErrorAction Stop

        return $true
      }

      return $false

    } `
      -ArgumentList $RutaRAR `
      -ErrorAction Stop


    if ($RARAnterior) {

      Mostrar-WARN "Se elimino el RAR anterior de la misma fecha."
    }
    else {

      Mostrar-OK "No existia RAR anterior."
    }

  }
  catch {

    Mostrar-ERROR "No fue posible eliminar el RAR anterior."

    Write-Host $_.Exception.Message

    $Resultados += [PSCustomObject]@{
      Numero       = $NumeroAplicacion
      Aplicacion   = $NombreAplicacion
      PhysicalPath = $PhysicalPath
      RAR          = $NombreRAR
      Estado       = "ERROR - ELIMINANDO RAR ANTERIOR"
      TamanoMB     = 0
    }

    continue
  }


  # ----------------------------------------------------------------------
  # PRODUCIR RAR
  #
  # IMPORTANTE:
  #
  # -r      = recursivo
  # -ep1    = elimina el path base de los archivos almacenados
  #
  # Exclusiones:
  #
  # -x*.rar
  # -x*.zip
  # -x*\temp\*
  # -x*\upload\*
  #
  # Se ejecuta WinRAR DIRECTAMENTE EN EL SERVIDOR ORIGEN.
  # ----------------------------------------------------------------------

  Write-Host ""
  Write-Host "Iniciando compresion..."
  Write-Host "Esto puede tardar dependiendo del tamano de la aplicacion."
  Write-Host ""

  $InicioRAR = Get-Date

  try {

    $ResultadoRAR = Invoke-Command `
      -Session $SesionTest `
      -ScriptBlock {

      param(
        $WinRAR,
        $RutaRAR,
        $PhysicalPath
      )


      # ----------------------------------------------------------
      # Verificar nuevamente WinRAR
      # ----------------------------------------------------------

      if (-not (Test-Path -LiteralPath $WinRAR -PathType Leaf)) {

        return [PSCustomObject]@{
          ExitCode = -999
          Output   = "WinRAR no existe: $WinRAR"
        }
      }


      # ----------------------------------------------------------
      # Argumentos
      #
      # Usamos la carpeta como origen con \*
      # ----------------------------------------------------------

      $Argumentos = @(
        "a"
        "-r"
        "-ep1"
        "-x*.rar"
        "-x*.zip"
        "-x*\temp\*"
        "-x*\upload\*"
        $RutaRAR
        ($PhysicalPath.TrimEnd('\') + "\*")
      )


      # ----------------------------------------------------------
      # Ejecutar WinRAR
      #
      # RedirectStandardOutput/Error evita perder informacion.
      # ----------------------------------------------------------

      $OutputTemp = Join-Path $env:TEMP ("WinRAR_" + [guid]::NewGuid().ToString() + ".log")

      $ErrorTemp = Join-Path $env:TEMP ("WinRAR_" + [guid]::NewGuid().ToString() + ".err")


      try {

        $Proceso = Start-Process `
          -FilePath $WinRAR `
          -ArgumentList $Argumentos `
          -Wait `
          -PassThru `
          -NoNewWindow `
          -RedirectStandardOutput $OutputTemp `
          -RedirectStandardError $ErrorTemp


        $Codigo = $Proceso.ExitCode


        $Salida = ""

        if (Test-Path -LiteralPath $OutputTemp) {

          $Salida = Get-Content `
            -LiteralPath $OutputTemp `
            -Raw `
            -ErrorAction SilentlyContinue
        }


        $ErrorSalida = ""

        if (Test-Path -LiteralPath $ErrorTemp) {

          $ErrorSalida = Get-Content `
            -LiteralPath $ErrorTemp `
            -Raw `
            -ErrorAction SilentlyContinue
        }


        return [PSCustomObject]@{
          ExitCode = $Codigo
          Output   = $Salida
          Error    = $ErrorSalida
        }

      }
      finally {

        Remove-Item `
          -LiteralPath $OutputTemp `
          -Force `
          -ErrorAction SilentlyContinue

        Remove-Item `
          -LiteralPath $ErrorTemp `
          -Force `
          -ErrorAction SilentlyContinue
      }

    } `
      -ArgumentList $RutaWinRAR, $RutaRAR, $PhysicalPath `
      -ErrorAction Stop


    $FinRAR = Get-Date

    $Duracion = New-TimeSpan -Start $InicioRAR -End $FinRAR


    Write-Host ""
    Write-Host "Proceso WinRAR finalizado."
    Write-Host "Codigo de retorno : $($ResultadoRAR.ExitCode)"
    Write-Host "Tiempo            : $($Duracion.ToString())"


    # ------------------------------------------------------------------
    # Mostrar salida si existe
    # ------------------------------------------------------------------

    if (-not [string]::IsNullOrWhiteSpace($ResultadoRAR.Output)) {

      Write-Host ""
      Write-Host "SALIDA WINRAR:"
      Write-Host $ResultadoRAR.Output
    }


    if (-not [string]::IsNullOrWhiteSpace($ResultadoRAR.Error)) {

      Write-Host ""
      Write-Host "SALIDA ERROR WINRAR:"
      Write-Host $ResultadoRAR.Error
    }


    # ------------------------------------------------------------------
    # VALIDACION FISICA DEL RAR
    # ------------------------------------------------------------------

    Write-Host ""
    Write-Host "Validando existencia del RAR..."

    $InfoRAR = Invoke-Command `
      -Session $SesionTest `
      -ScriptBlock {

      param(
        $Ruta
      )

      if (-not (Test-Path -LiteralPath $Ruta -PathType Leaf)) {

        return [PSCustomObject]@{
          Exists   = $false
          Length   = 0
          FullName = $Ruta
        }
      }


      $Archivo = Get-Item `
        -LiteralPath $Ruta `
        -Force `
        -ErrorAction Stop


      return [PSCustomObject]@{
        Exists   = $true
        Length   = $Archivo.Length
        FullName = $Archivo.FullName
      }

    } `
      -ArgumentList $RutaRAR `
      -ErrorAction Stop


    # ------------------------------------------------------------------
    # Evaluar resultado
    # ------------------------------------------------------------------

    if ($InfoRAR.Exists -and $InfoRAR.Length -gt 0) {

      $TamanoMB = [math]::Round(
        ($InfoRAR.Length / 1MB),
        2
      )


      Mostrar-OK "RAR generado correctamente."

      Write-Host "Archivo : $($InfoRAR.FullName)"
      Write-Host "Tamano  : $TamanoMB MB"


      $Estado = "OK"


      $Resultados += [PSCustomObject]@{
        Numero       = $NumeroAplicacion
        Aplicacion   = $NombreAplicacion
        PhysicalPath = $PhysicalPath
        RAR          = $NombreRAR
        Estado       = $Estado
        TamanoMB     = $TamanoMB
      }

    }
    else {

      Mostrar-ERROR "WinRAR termino pero no se encontro un RAR valido."

      Write-Host "Ruta esperada:"
      Write-Host $RutaRAR

      $Resultados += [PSCustomObject]@{
        Numero       = $NumeroAplicacion
        Aplicacion   = $NombreAplicacion
        PhysicalPath = $PhysicalPath
        RAR          = $NombreRAR
        Estado       = "ERROR - RAR NO GENERADO"
        TamanoMB     = 0
      }
    }

  }
  catch {

    Mostrar-ERROR "Error durante la produccion del RAR."

    Write-Host $_.Exception.Message

    $Resultados += [PSCustomObject]@{
      Numero       = $NumeroAplicacion
      Aplicacion   = $NombreAplicacion
      PhysicalPath = $PhysicalPath
      RAR          = $NombreRAR
      Estado       = "ERROR - EXCEPCION"
      TamanoMB     = 0
    }
  }


  # ----------------------------------------------------------------------
  # Pausa visual breve entre aplicaciones
  # ----------------------------------------------------------------------

  Write-Host ""
  Write-Host "Finalizada aplicacion $NumeroAplicacion de $($Aplicaciones.Count)."
  Write-Host ""

}


# ==========================================================================
# CERRAR SESION
# ==========================================================================

Mostrar-Titulo "FINALIZANDO SESION REMOTA"

Remove-PSSession `
  -Session $SesionTest `
  -ErrorAction SilentlyContinue

Mostrar-OK "Sesion WinRM cerrada."


# ==========================================================================
# RESUMEN
# ==========================================================================

Mostrar-Titulo "RESUMEN DE PRODUCCION"

$Total = $Resultados.Count

$Correctos = @(
  $Resultados |
  Where-Object {
    $_.Estado -eq "OK"
  }
).Count

$Errores = $Total - $Correctos


Write-Host "Servidor origen : $ServidorOrigen"
Write-Host "Site            : $NombreSite"
Write-Host "Fecha           : $FechaBackup"
Write-Host ""
Write-Host "Aplicaciones    : $($Aplicaciones.Count)"
Write-Host "Procesadas      : $Total"
Write-Host "Correctas       : $Correctos"
Write-Host "Errores         : $Errores"
Write-Host ""
Write-Host "Directorio RAR:"
Write-Host $DirectorioRAR

Mostrar-Linea


# ==========================================================================
# DETALLE
# ==========================================================================

Write-Host ""
Write-Host "DETALLE"
Write-Host ""

foreach ($Resultado in $Resultados) {

  $Texto = "[{0:D2}] {1} | {2} | {3} MB" -f `
    $Resultado.Numero,
  $Resultado.Aplicacion,
  $Resultado.Estado,
  $Resultado.TamanoMB

  if ($Resultado.Estado -eq "OK") {

    Write-Host $Texto -ForegroundColor Green

  }
  else {

    Write-Host $Texto -ForegroundColor Red
  }

  Write-Host "     PhysicalPath : $($Resultado.PhysicalPath)"
  Write-Host "     RAR          : $($Resultado.RAR)"
  Write-Host ""
}


# ==========================================================================
# LISTAR RAR GENERADOS
# ==========================================================================

Mostrar-Titulo "RAR GENERADOS EN EL SERVIDOR ORIGEN"

try {

  $ListaRAR = Invoke-Command `
    -ComputerName $ServidorOrigen `
    -Credential $Credencial `
    -ScriptBlock {

    param(
      $Ruta
    )

    if (-not (Test-Path -LiteralPath $Ruta)) {

      return @()
    }


    Get-ChildItem `
      -LiteralPath $Ruta `
      -Filter "*.rar" `
      -File `
      -Force `
      -ErrorAction SilentlyContinue |
    Sort-Object Name |
    Select-Object `
      Name,
    FullName,
    Length,
    LastWriteTime

  } `
    -ArgumentList $DirectorioRAR `
    -ErrorAction Stop


  if ($null -eq $ListaRAR -or $ListaRAR.Count -eq 0) {

    Mostrar-WARN "No se encontraron RAR en el directorio de destino."

  }
  else {

    foreach ($RAR in $ListaRAR) {

      $MB = [math]::Round(
        ($RAR.Length / 1MB),
        2
      )

      Write-Host "$($RAR.Name)"
      Write-Host "    Ruta   : $($RAR.FullName)"
      Write-Host "    Tamano : $MB MB"
      Write-Host ""
    }
  }

}
catch {

  Mostrar-WARN "No fue posible obtener el listado final de RAR."

  Write-Host $_.Exception.Message
}


# ==========================================================================
# FIN
# ==========================================================================

Mostrar-Titulo "FASE 2 FINALIZADA"

Write-Host "IMPORTANTE:"
Write-Host ""
Write-Host "Los RAR fueron generados en el servidor origen:"
Write-Host ""
Write-Host "$DirectorioRAR"
Write-Host ""
Write-Host "NO se realizo ninguna copia hacia:"
Write-Host ""
Write-Host "\\10.0.0.179\Backup_BD_APP"
Write-Host ""
Write-Host "La transferencia al repositorio se realizara en una fase posterior."
Write-Host ""

Mostrar-Linea

Write-Host ""
Write-Host "Presione ENTER para finalizar..."
Read-Host