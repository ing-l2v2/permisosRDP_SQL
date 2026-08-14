#Requires -Version 5.1

<#
===============================================================================
 FASE 2 - PRODUCTOR DE ARCHIVOS RAR DE APLICACIONES IIS
===============================================================================

 Nombre:
    BkSiteIIS_rarProductor.ps1

 OBJETIVO:
    Leer el inventario generado por FASE 1 y generar un RAR independiente
    para cada APPLICATION IIS.

 IMPORTANTE:
    - NO consulta IIS.
    - NO procesa Virtual Directories.
    - NO modifica IIS.
    - NO elimina archivos del servidor origen.
    - Los RAR se generan desde el servidor origen.
    - El destino de los RAR es un recurso UNC.

 ORIGEN:
    Servidor IIS:
        10.0.0.59

 DESTINO:
    \\10.0.0.179\Backup_BD_APP\10.0.0.59\<SITE>\

 EXCLUSIONES:
    *.rar
    *.zip
    directorio temp
    directorio upload

 EJEMPLO:
    DERCO_CORREDOR_ADMIN_12082026.rar

===============================================================================
#>

Clear-Host

#==============================================================================
# 1. VARIABLES
#==============================================================================

$ServidorOrigen = "10.0.0.59"

$Usuario = "FIDENSLAT\leonel.villa"

$NombreSite = "DERCO_CORREDOR"

#==============================================================================
# 2. REPOSITORIO DEL INVENTARIO
#==============================================================================

$RepositorioInventario = "C:\Infraestructura\Site"

$Fecha = Get-Date -Format "ddMMyyyy"

$ArchivoInventario = Join-Path `
  $RepositorioInventario `
  "aplicaciones_${NombreSite}_${Fecha}.txt"

#==============================================================================
# 3. REPOSITORIO DE BACKUP
#==============================================================================

$RepositorioBackup = "\\10.0.0.179\Backup_BD_APP"

$DestinoSite = Join-Path `
  $RepositorioBackup `
  "$ServidorOrigen\$NombreSite"

#==============================================================================
# 4. ARCHIVO LOG
#==============================================================================

$ArchivoLog = Join-Path `
  $RepositorioInventario `
  "BkSiteIIS_rarProductor_${NombreSite}_${Fecha}.log"

#==============================================================================
# 5. CONFIGURACION
#==============================================================================

$ErrorActionPreference = "Stop"

#==============================================================================
# 6. FUNCIONES
#==============================================================================

function Write-Log {

  param(
    [string]$Mensaje
  )

  $FechaLog = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

  $Linea = "$FechaLog | $Mensaje"

  Add-Content `
    -LiteralPath $ArchivoLog `
    -Value $Linea `
    -Encoding UTF8

  Write-Host $Mensaje
}

function Write-Separator {

  Write-Host ""
  Write-Host "============================================================"
}

#==============================================================================
# 7. VALIDAR ARCHIVO DE INVENTARIO
#==============================================================================

Write-Separator

Write-Host "FASE 2 - PRODUCTOR DE RAR"
Write-Host "Site : $NombreSite"

Write-Separator

Write-Host ""
Write-Host "Archivo de inventario:"
Write-Host $ArchivoInventario

if (-not (Test-Path -LiteralPath $ArchivoInventario)) {

  Write-Host ""
  Write-Host "ERROR: No existe el archivo de inventario." `
    -ForegroundColor Red

  Write-Host $ArchivoInventario `
    -ForegroundColor Yellow

  exit 1
}

#==============================================================================
# 8. INICIALIZAR LOG
#==============================================================================

if (Test-Path -LiteralPath $ArchivoLog) {

  Remove-Item `
    -LiteralPath $ArchivoLog `
    -Force
}

Write-Log "INICIO FASE 2"
Write-Log "Servidor origen: $ServidorOrigen"
Write-Log "Usuario: $Usuario"
Write-Log "Site: $NombreSite"
Write-Log "Inventario: $ArchivoInventario"
Write-Log "Destino: $DestinoSite"

#==============================================================================
# 9. LEER INVENTARIO
#==============================================================================

Write-Separator

Write-Host "Leyendo inventario..."

$Lineas = Get-Content `
  -LiteralPath $ArchivoInventario `
  -Encoding UTF8

#==============================================================================
# 10. EXTRAER SOLAMENTE LA SECCION BACKUP
#==============================================================================

$Aplicaciones = @()

$EnSeccionBackup = $false

$RegistroActual = $null

foreach ($Linea in $Lineas) {

  $LineaTrim = $Linea.Trim()

  #----------------------------------------------------------------------
  # Inicio de BACKUP
  #----------------------------------------------------------------------

  if ($LineaTrim -match '^\[BACKUP_\d+\]$') {

    # Guardar registro anterior
    if ($null -ne $RegistroActual) {

      if ($RegistroActual["Type"] -eq "APPLICATION") {

        $Aplicaciones += [pscustomobject]$RegistroActual
      }
    }

    $EnSeccionBackup = $true

    $RegistroActual = @{}

    continue
  }

  #----------------------------------------------------------------------
  # Si estamos dentro de BACKUP y aparece otra seccion
  #----------------------------------------------------------------------

  if (
    $EnSeccionBackup -and
    $LineaTrim.StartsWith("[") -and
    $LineaTrim -notmatch '^\[BACKUP_\d+\]$'
  ) {

    if ($null -ne $RegistroActual) {

      if ($RegistroActual["Type"] -eq "APPLICATION") {

        $Aplicaciones += [pscustomobject]$RegistroActual
      }
    }

    $RegistroActual = $null

    $EnSeccionBackup = $false

    continue
  }

  #----------------------------------------------------------------------
  # Leer propiedades
  #----------------------------------------------------------------------

  if ($EnSeccionBackup -and $null -ne $RegistroActual) {

    if ($LineaTrim -match '^([^=]+?)\s*=\s*(.*)$') {

      $Clave = $Matches[1].Trim()

      $Valor = $Matches[2].Trim()

      $RegistroActual[$Clave] = $Valor
    }
  }
}

#==============================================================================
# 11. GUARDAR ULTIMO REGISTRO
#==============================================================================

if ($null -ne $RegistroActual) {

  if ($RegistroActual["Type"] -eq "APPLICATION") {

    $Aplicaciones += [pscustomobject]$RegistroActual
  }
}

#==============================================================================
# 12. VALIDAR APLICACIONES
#==============================================================================

Write-Host ""

Write-Host "Aplicaciones encontradas: $($Aplicaciones.Count)" `
  -ForegroundColor Cyan

Write-Log "Aplicaciones encontradas: $($Aplicaciones.Count)"

if ($Aplicaciones.Count -eq 0) {

  Write-Host ""
  Write-Host "ERROR: No se encontraron aplicaciones." `
    -ForegroundColor Red

  Write-Log "ERROR: No se encontraron aplicaciones."

  exit 1
}

#==============================================================================
# 13. MOSTRAR APLICACIONES
#==============================================================================

Write-Separator

Write-Host "APLICACIONES QUE SERAN PROCESADAS"
Write-Separator

$Indice = 0

foreach ($App in $Aplicaciones) {

  $Indice++

  Write-Host ""
  Write-Host "[$Indice]"
  Write-Host "Nombre       : $($App.Name)"
  Write-Host "IIS Path     : $($App.IISPath)"
  Write-Host "PhysicalPath : $($App.PhysicalPath)"
  Write-Host "ApplicationPool : $($App.ApplicationPool)"
  Write-Host "RAR          : $($App.BackupFileName)"
}

#==============================================================================
# 14. SOLICITAR CREDENCIALES
#==============================================================================

Write-Separator

Write-Host "Credenciales para conectarse a:"
Write-Host $ServidorOrigen

$Credential = Get-Credential `
  -UserName $Usuario `
  -Message "Ingrese el password de $Usuario"

#==============================================================================
# 15. VALIDAR WINRM
#==============================================================================

Write-Separator

Write-Host "Validando WinRM..."

try {

  Test-WSMan `
    -ComputerName $ServidorOrigen `
    -ErrorAction Stop |
  Out-Null

  Write-Host "WinRM disponible." `
    -ForegroundColor Green

}
catch {

  Write-Host ""
  Write-Host "ERROR: WinRM no disponible." `
    -ForegroundColor Red

  Write-Host $_.Exception.Message `
    -ForegroundColor Red

  Write-Log "ERROR WinRM: $($_.Exception.Message)"

  exit 1
}

#==============================================================================
# 16. VALIDAR REPOSITORIO DESTINO
#==============================================================================

Write-Separator

Write-Host "Validando repositorio de backup..."
Write-Host $DestinoSite

try {

  if (-not (Test-Path -LiteralPath $DestinoSite)) {

    New-Item `
      -ItemType Directory `
      -Path $DestinoSite `
      -Force |
    Out-Null

    Write-Host ""
    Write-Host "Directorio creado." `
      -ForegroundColor Green
  }
  else {

    Write-Host ""
    Write-Host "Directorio existente." `
      -ForegroundColor Green
  }

}
catch {

  Write-Host ""
  Write-Host "ERROR accediendo al repositorio de backup." `
    -ForegroundColor Red

  Write-Host $_.Exception.Message `
    -ForegroundColor Red

  Write-Log "ERROR repositorio: $($_.Exception.Message)"

  exit 1
}

#==============================================================================
# 17. SERIALIZAR A JSON
#
# ESTA ES LA CORRECCION PRINCIPAL
#
# No enviamos directamente los objetos PowerShell por Invoke-Command.
# Los convertimos a JSON y los reconstruimos remotamente.
#==============================================================================

Write-Separator

Write-Host "Preparando inventario para transferencia remota..."

try {

  $AplicacionesJson = $Aplicaciones |
  ConvertTo-Json -Depth 10

}
catch {

  Write-Host ""
  Write-Host "ERROR serializando aplicaciones." `
    -ForegroundColor Red

  Write-Host $_.Exception.Message `
    -ForegroundColor Red

  exit 1
}

Write-Host "Inventario serializado correctamente." `
  -ForegroundColor Green

#==============================================================================
# 18. SCRIPT REMOTO
#==============================================================================

$ScriptRemoto = {

  param(
    [string]$AplicacionesJson,
    [string]$DestinoSite,
    [string]$Fecha
  )

  $ErrorActionPreference = "Stop"

  #==========================================================================
  # RECONSTRUIR APLICACIONES
  #==========================================================================

  try {

    $Aplicaciones = ConvertFrom-Json `
      -InputObject $AplicacionesJson `
      -ErrorAction Stop

  }
  catch {

    throw "No fue posible reconstruir el inventario JSON. Error: $($_.Exception.Message)"
  }

  #==========================================================================
  # ASEGURAR QUE SEA ARRAY
  #==========================================================================

  if ($Aplicaciones -isnot [System.Array]) {

    $Aplicaciones = @($Aplicaciones)
  }

  Write-Output ""
  Write-Output "============================================================"
  Write-Output "PROCESAMIENTO REMOTO"
  Write-Output "Servidor : $env:COMPUTERNAME"
  Write-Output "============================================================"

  Write-Output ""
  Write-Output "Aplicaciones recibidas: $($Aplicaciones.Count)"

  #==========================================================================
  # BUSCAR WINRAR
  #==========================================================================

  function Find-WinRAR {

    $PosiblesRutas = @(
      "C:\Program Files\WinRAR\WinRAR.exe"
      "C:\Program Files (x86)\WinRAR\WinRAR.exe"
      "C:\WinRAR\WinRAR.exe"
      "C:\Program Files\WinRAR\Rar.exe"
      "C:\Program Files (x86)\WinRAR\Rar.exe"
    )

    foreach ($Ruta in $PosiblesRutas) {
      if (Test-Path -LiteralPath $Ruta) {
        return $Ruta
      }
    }

    try {
      $Command = Get-Command `
        WinRAR.exe `
        -ErrorAction SilentlyContinue

      if ($null -ne $Command) {
        return $Command.Source
      }
    }
    catch {
    }

    try {
      $Command = Get-Command `
        Rar.exe `
        -ErrorAction SilentlyContinue

      if ($null -ne $Command) {
        return $Command.Source
      }
    }
    catch {
    }

    return $null
  }

  #==========================================================================
  # LOCALIZAR WINRAR
  #==========================================================================

  $WinRAR = Find-WinRAR

  if ([string]::IsNullOrWhiteSpace($WinRAR)) {

    throw "No se encontro WinRAR.exe ni Rar.exe en $env:COMPUTERNAME."
  }

  Write-Output ""
  Write-Output "WinRAR encontrado:"
  Write-Output $WinRAR

  #==========================================================================
  # VALIDAR DESTINO
  #==========================================================================

  if (-not (Test-Path -LiteralPath $DestinoSite)) {

    New-Item `
      -ItemType Directory `
      -Path $DestinoSite `
      -Force |
    Out-Null
  }

  #==========================================================================
  # RESULTADOS
  #==========================================================================

  $Resultados = @()

  #==========================================================================
  # PROCESAR APLICACIONES
  #==========================================================================

  foreach ($App in $Aplicaciones) {

    $Nombre = [string]$App.Name

    $PhysicalPath = [string]$App.PhysicalPath

    $BackupFileName = [string]$App.BackupFileName

    Write-Output ""
    Write-Output "============================================================"
    Write-Output "APLICACION"
    Write-Output "============================================================"

    Write-Output "Name          : $Nombre"
    Write-Output "IISPath       : $($App.IISPath)"
    Write-Output "PhysicalPath  : $PhysicalPath"
    Write-Output "ApplicationPool: $($App.ApplicationPool)"
    Write-Output "RAR           : $BackupFileName"

    #----------------------------------------------------------------------
    # VALIDAR TYPE
    #----------------------------------------------------------------------

    if ([string]$App.Type -ne "APPLICATION") {

      Write-Output ""
      Write-Output "OMITIDA: No es APPLICATION."

      $Resultados += [pscustomobject]@{

        Name         = $Nombre

        PhysicalPath = $PhysicalPath

        RAR          = $BackupFileName

        Status       = "OMITTED"

        Message      = "El registro no es APPLICATION."

        ExitCode     = -10
      }

      continue
    }

    #----------------------------------------------------------------------
    # VALIDAR PHYSICAL PATH
    #----------------------------------------------------------------------

    if ([string]::IsNullOrWhiteSpace($PhysicalPath)) {

      Write-Output ""
      Write-Output "ERROR: PhysicalPath vacío."

      $Resultados += [pscustomobject]@{

        Name         = $Nombre

        PhysicalPath = $PhysicalPath

        RAR          = $BackupFileName

        Status       = "ERROR"

        Message      = "PhysicalPath vacío."

        ExitCode     = -1
      }

      continue
    }

    #----------------------------------------------------------------------
    # SOLO RUTAS LOCALES
    #----------------------------------------------------------------------

    if ($PhysicalPath -like "\\*") {

      Write-Output ""
      Write-Output "OMITIDA: PhysicalPath es UNC."

      $Resultados += [pscustomobject]@{

        Name         = $Nombre

        PhysicalPath = $PhysicalPath

        RAR          = $BackupFileName

        Status       = "OMITTED"

        Message      = "PhysicalPath UNC."

        ExitCode     = -2
      }

      continue
    }

    #----------------------------------------------------------------------
    # VALIDAR EXISTENCIA
    #----------------------------------------------------------------------

    if (-not (Test-Path -LiteralPath $PhysicalPath)) {

      Write-Output ""
      Write-Output "ERROR: La ruta no existe."

      $Resultados += [pscustomobject]@{

        Name         = $Nombre

        PhysicalPath = $PhysicalPath

        RAR          = $BackupFileName

        Status       = "ERROR"

        Message      = "La ruta no existe."

        ExitCode     = -3
      }

      continue
    }

    #----------------------------------------------------------------------
    # CONSTRUIR RAR
    #----------------------------------------------------------------------

    $ArchivoRAR = Join-Path `
      $DestinoSite `
      $BackupFileName

    Write-Output ""
    Write-Output "Destino RAR:"
    Write-Output $ArchivoRAR

    #----------------------------------------------------------------------
    # NO SOBRESCRIBIR
    #----------------------------------------------------------------------

    if (Test-Path -LiteralPath $ArchivoRAR) {

      Write-Output ""
      Write-Output "ADVERTENCIA: El RAR ya existe."

      $Resultados += [pscustomobject]@{

        Name         = $Nombre

        PhysicalPath = $PhysicalPath

        RAR          = $BackupFileName

        Status       = "EXISTS"

        Message      = "El RAR ya existe."

        ExitCode     = -4
      }

      continue
    }

    #----------------------------------------------------------------------
    # ARGUMENTOS WINRAR
    #
    # a       Agregar archivos
    # -r      Recursivo
    # -ep1    Excluir ruta padre
    #
    # EXCLUSIONES:
    #
    # *.rar
    # *.zip
    # temp
    # upload
    #
    #----------------------------------------------------------------------

    $Argumentos = @()

    $Argumentos += "a"

    $Argumentos += "-r"

    $Argumentos += "-ep1"

    $Argumentos += "-x*.rar"

    $Argumentos += "-x*.zip"

    $Argumentos += "-x*\temp\*"

    $Argumentos += "-x*\upload\*"

    # Archivo destino
    $Argumentos += "`"$ArchivoRAR`""

    # Directorio origen
    $Argumentos += "`"$PhysicalPath`""

    $ArgumentString = $Argumentos -join " "

    Write-Output ""
    Write-Output "Ejecutando:"
    Write-Output $WinRAR
    Write-Output $ArgumentString

    #----------------------------------------------------------------------
    # EJECUTAR WINRAR
    #----------------------------------------------------------------------

    try {

      $Process = Start-Process `
        -FilePath $WinRAR `
        -ArgumentList $ArgumentString `
        -Wait `
        -PassThru `
        -NoNewWindow

      $ExitCode = $Process.ExitCode

    }
    catch {

      Write-Output ""
      Write-Output "ERROR ejecutando WinRAR:"
      Write-Output $_.Exception.Message

      $Resultados += [pscustomobject]@{

        Name         = $Nombre

        PhysicalPath = $PhysicalPath

        RAR          = $BackupFileName

        Status       = "ERROR"

        Message      = $_.Exception.Message

        ExitCode     = -5
      }

      continue
    }

    #----------------------------------------------------------------------
    # VALIDAR RESULTADO
    #----------------------------------------------------------------------

    if ($ExitCode -eq 0) {

      if (Test-Path -LiteralPath $ArchivoRAR) {

        $FileInfo = Get-Item `
          -LiteralPath $ArchivoRAR

        Write-Output ""
        Write-Output "RAR generado correctamente."

        Write-Output (
          "Tamano: {0:N0} bytes" -f $FileInfo.Length
        )

        $Resultados += [pscustomobject]@{

          Name         = $Nombre

          PhysicalPath = $PhysicalPath

          RAR          = $BackupFileName

          Status       = "OK"

          Message      = "RAR generado correctamente."

          ExitCode     = $ExitCode

          SizeBytes    = $FileInfo.Length
        }

      }
      else {

        Write-Output ""
        Write-Output "ERROR: No se encontro el RAR."

        $Resultados += [pscustomobject]@{

          Name         = $Nombre

          PhysicalPath = $PhysicalPath

          RAR          = $BackupFileName

          Status       = "ERROR"

          Message      = "WinRAR termino pero no creo el archivo."

          ExitCode     = $ExitCode
        }
      }

    }
    else {

      Write-Output ""
      Write-Output "ERROR WinRAR. ExitCode=$ExitCode"

      $Resultados += [pscustomobject]@{

        Name         = $Nombre

        PhysicalPath = $PhysicalPath

        RAR          = $BackupFileName

        Status       = "ERROR"

        Message      = "WinRAR devolvio codigo $ExitCode."

        ExitCode     = $ExitCode
      }
    }
  }

  #==========================================================================
  # RETORNAR RESULTADOS
  #==========================================================================

  return $Resultados
}

#==============================================================================
# 19. EJECUTAR SCRIPT REMOTO
#==============================================================================

Write-Separator

Write-Host "Iniciando produccion de RAR..."

Write-Host ""
Write-Host "Servidor origen : $ServidorOrigen"
Write-Host "Site            : $NombreSite"
Write-Host "Destino         : $DestinoSite"

Write-Separator

try {

  #==========================================================================
  # IMPORTANTE:
  #
  # Se pasan SOLO TRES argumentos:
  #
  # 1. JSON completo
  # 2. Destino
  # 3. Fecha
  #
  # Esto evita que PowerShell descomponga el array de objetos.
  #==========================================================================

  $Resultados = Invoke-Command `
    -ComputerName $ServidorOrigen `
    -Credential $Credential `
    -ScriptBlock $ScriptRemoto `
    -ArgumentList @(
    $AplicacionesJson
    $DestinoSite
    $Fecha
  ) `
    -ErrorAction Stop

}
catch {

  Write-Host ""
  Write-Host "ERROR ejecutando la FASE 2 en el servidor origen." `
    -ForegroundColor Red

  Write-Host ""

  Write-Host $_.Exception.Message `
    -ForegroundColor Red

  Write-Log `
    "ERROR Invoke-Command: $($_.Exception.Message)"

  exit 1
}

#==============================================================================
# 20. RESUMEN
#==============================================================================

Write-Separator

Write-Host "RESUMEN FASE 2" `
  -ForegroundColor Cyan

Write-Separator

$Resultados = @(
  $Resultados |
  Where-Object {
    $_.Name
  }
)

$OK = @(
  $Resultados |
  Where-Object {
    $_.Status -eq "OK"
  }
)

$Errores = @(
  $Resultados |
  Where-Object {
    $_.Status -eq "ERROR"
  }
)

$Existentes = @(
  $Resultados |
  Where-Object {
    $_.Status -eq "EXISTS"
  }
)

$Omitidos = @(
  $Resultados |
  Where-Object {
    $_.Status -eq "OMITTED"
  }
)

Write-Host ""
Write-Host "Total aplicaciones : $($Resultados.Count)"
Write-Host "RAR generados      : $($OK.Count)"
Write-Host "Errores            : $($Errores.Count)"
Write-Host "Ya existentes      : $($Existentes.Count)"
Write-Host "Omitidos           : $($Omitidos.Count)"
Write-Host ""

#==============================================================================
# 21. DETALLE DE RESULTADOS
#==============================================================================

foreach ($Resultado in $Resultados) {

  switch ($Resultado.Status) {

    "OK" {

      Write-Host (
        "[OK]      {0} -> {1}" -f `
          $Resultado.Name,
        $Resultado.RAR
      ) -ForegroundColor Green

      Write-Log (
        "[OK] {0} -> {1} | Size={2}" -f `
          $Resultado.Name,
        $Resultado.RAR,
        $Resultado.SizeBytes
      )
    }

    "ERROR" {

      Write-Host (
        "[ERROR]   {0} -> {1}" -f `
          $Resultado.Name,
        $Resultado.Message
      ) -ForegroundColor Red

      Write-Log (
        "[ERROR] {0} -> {1}" -f `
          $Resultado.Name,
        $Resultado.Message
      )
    }

    "EXISTS" {

      Write-Host (
        "[EXISTE]  {0} -> {1}" -f `
          $Resultado.Name,
        $Resultado.RAR
      ) -ForegroundColor Yellow

      Write-Log (
        "[EXISTE] {0} -> {1}" -f `
          $Resultado.Name,
        $Resultado.RAR
      )
    }

    "OMITTED" {

      Write-Host (
        "[OMITIDO] {0} -> {1}" -f `
          $Resultado.Name,
        $Resultado.Message
      ) -ForegroundColor Yellow

      Write-Log (
        "[OMITIDO] {0} -> {1}" -f `
          $Resultado.Name,
        $Resultado.Message
      )
    }
  }
}

#==============================================================================
# 22. FIN
#==============================================================================

Write-Separator

Write-Host "FASE 2 FINALIZADA" `
  -ForegroundColor Green

Write-Separator

Write-Host ""
Write-Host "Repositorio de RAR:"
Write-Host $DestinoSite

Write-Host ""

Write-Host "Log:"
Write-Host $ArchivoLog

Write-Log "FIN FASE 2"

Write-Host ""