# ================================================================
# INVENTARIO DE SITE IIS
# Obtiene desde un servidor remoto:
#   - Site IIS
#   - Physical Path
#   - Bindings
#   - Aplicaciones
#   - Virtual Directories
#   - Physical Paths
#   - Application Pools
#
# Ejecutar desde el equipo administrador
# ================================================================

# -------------------------------
# VARIABLES
# -------------------------------
$ServidorOrigen = "10.0.0.59"
$Usuario = "FIDENSLAT\leonel.villa"
$NombreSite = "DERCO_CORREDOR"
$FechaInventario = "11082026"

# Repositorio local del inventario
$Repositorio = "C:\Infraestructura\Site"

# Nombre automático del archivo
$NombreArchivo = "aplicaciones_{0}_{1}.txt" -f $NombreSite, $FechaInventario
$ArchivoSalida = Join-Path $Repositorio $NombreArchivo

# -------------------------------
# CREAR DIRECTORIO LOCAL
# -------------------------------
if (-not (Test-Path $Repositorio)) {
  New-Item `
    -Path $Repositorio `
    -ItemType Directory `
    -Force | Out-Null

  Write-Host "Directorio creado: $Repositorio" -ForegroundColor Green
}


# -------------------------------
# SOLICITAR PASSWORD
# -------------------------------
$Password = Read-Host `
  "Ingrese el password de $Usuario" `
  -AsSecureString

# -------------------------------
# CREAR CREDENTIAL
# -------------------------------
$Credential = New-Object `
  System.Management.Automation.PSCredential(
  $Usuario,
  $Password
)

# -------------------------------
# PROBAR CONECTIVIDAD WINRM
# -------------------------------
Write-Host ""
Write-Host "Probando conectividad con $ServidorOrigen..." `
  -ForegroundColor Cyan

try {
  Test-WSMan `
    -ComputerName $ServidorOrigen `
    -ErrorAction Stop | Out-Null

  Write-Host "WinRM disponible." -ForegroundColor Green
}
catch {
  Write-Host ""
  Write-Host "ERROR: No fue posible establecer comunicación WinRM con $ServidorOrigen , revisar la VPN" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  exit
}

# -------------------------------
# SCRIPT REMOTO
# -------------------------------
$ScriptRemoto = {
  param(
    [string]$NombreSite
  )
  # ------------------------------------------------------------
  # CARGAR IIS
  # ------------------------------------------------------------
  Import-Module WebAdministration

  function Get-ApplicationName {
    param(
      [string]$ApplicationPath
    )
    if ($ApplicationPath -eq "/") {
      return $NombreSite
    }
    $Nombre = $ApplicationPath.Trim("/")
    $Nombre = $Nombre.Replace("/", "_")
    return $Nombre
  }

  # ------------------------------------------------------------
  # VALIDAR SITE
  # ------------------------------------------------------------
  $Site = Get-Website `
    -Name $NombreSite `
    -ErrorAction SilentlyContinue

  if ($null -eq $Site) {
    throw "El Site IIS '$NombreSite' no existe en el servidor."
  }

  # ------------------------------------------------------------
  # RESULTADO PRINCIPAL
  # ------------------------------------------------------------
  $Resultado = [ordered]@{
    Name                          = $Pool.Name

    ManagedRuntimeVersion         = $Pool.managedRuntimeVersion

    ManagedPipelineMode           = $Pool.managedPipelineMode

    AutoStart                     = $Pool.autoStart

    Enable32BitAppOnWin64         = $Pool.enable32BitAppOnWin64

    IdentityType                  = $Pool.processModel.identityType

    UserName                      = $Pool.processModel.userName

    StartMode                     = $Pool.startMode

    IdleTimeout                   = $Pool.processModel.idleTimeout

    IdleTimeoutAction             = $Pool.processModel.idleTimeoutAction

    PingEnabled                   = $Pool.processModel.pingingEnabled

    PingInterval                  = $Pool.processModel.pingInterval

    PingResponseTime              = $Pool.processModel.pingResponseTime

    ShutdownTimeLimit             = $Pool.processModel.shutdownTimeLimit

    StartupTimeLimit              = $Pool.processModel.startupTimeLimit

    RapidFailProtection           = $Pool.failure.rapidFailProtection

    RapidFailProtectionInterval   = $Pool.failure.rapidFailProtectionInterval

    RapidFailProtectionMaxCrashes = $Pool.failure.rapidFailProtectionMaxCrashes
  }
  $Resultado["Servidor"] = $env:COMPUTERNAME
  $Resultado["Site"] = $Site.Name
  $Resultado["Estado"] = $Site.State
  $Resultado["PhysicalPath"] = $Site.PhysicalPath
  $Resultado["ApplicationPool"] = $Site.ApplicationPool


  # ------------------------------------------------------------
  # BINDINGS
  # ------------------------------------------------------------

  $Bindings = @()

  foreach ($Binding in $Site.Bindings.Collection) {
    $Bindings += [ordered]@{
      Protocol             = $Binding.Protocol
      BindingInformation   = $Binding.BindingInformation
      CertificateHash      = $Binding.CertificateHash
      CertificateStoreName = $Binding.CertificateStoreName
    }
  }

  $Resultado["Bindings"] = $Bindings

  # ------------------------------------------------------------
  # APPLICATION POOL DEL SITE
  # ------------------------------------------------------------
  $Pool = Get-Item `
    "IIS:\AppPools\$($Site.ApplicationPool)" `
    -ErrorAction SilentlyContinue

  if ($null -ne $Pool) {
    $Resultado["Pool"] = [ordered]@{
      Name                  = $Pool.Name

      ManagedRuntimeVersion =
      $Pool.managedRuntimeVersion

      ManagedPipelineMode   =
      $Pool.managedPipelineMode

      AutoStart             =
      $Pool.autoStart

      Enable32BitAppOnWin64 =
      $Pool.enable32BitAppOnWin64

      IdentityType          =
      $Pool.processModel.identityType
    }
  }


  # ------------------------------------------------------------
  # APLICACIONES IIS
  # ------------------------------------------------------------
  $Aplicaciones = @()

  $Apps = Get-WebApplication `
    -Site $NombreSite `
    -ErrorAction SilentlyContinue

  $IndiceAplicacion = 0

  foreach ($App in $Apps) {
    
    $IndiceAplicacion++

    $Aplicacion = [ordered]@{
      Id               = $IndiceAplicacion
      Name             = Split-Path $App.Path -Leaf
      Path             = $App.Path
      ApplicationPool  = $App.ApplicationPool
      PhysicalPath     = $App.PhysicalPath
      EnabledProtocols = $App.EnabledProtocols
    }

    # --------------------------------------------------------
    # APPLICATION POOL DE LA APLICACION
    # --------------------------------------------------------
    if ($App.ApplicationPool) {
      $AppPool = Get-Item `
        "IIS:\AppPools\$($App.ApplicationPool)" `
        -ErrorAction SilentlyContinue

      if ($null -ne $AppPool) {
        $Aplicacion["Pool"] = [ordered]@{
          Name                  = $AppPool.Name

          ManagedRuntimeVersion =
          $AppPool.managedRuntimeVersion

          ManagedPipelineMode   =
          $AppPool.managedPipelineMode

          AutoStart             =
          $AppPool.autoStart

          Enable32BitAppOnWin64 =
          $AppPool.enable32BitAppOnWin64

          IdentityType          =
          $AppPool.processModel.identityType
        }
      }
    }


    # --------------------------------------------------------
    # VIRTUAL DIRECTORIES DE LA APLICACION
    # --------------------------------------------------------
    $VirtualDirectories = @()

    $VDirs = Get-WebVirtualDirectory `
      -Site $NombreSite `
      -Application $App.Path `
      -ErrorAction SilentlyContinue

    foreach ($VD in $VDirs) {
      $VirtualDirectories += [ordered]@{
        Path         = $VD.Path

        PhysicalPath = $VD.PhysicalPath

        LogonMethod  = $VD.LogonMethod

        UserName     = $VD.UserName
      }
    }

    $Aplicacion["VirtualDirectories"] =
    $VirtualDirectories


    $Aplicaciones += $Aplicacion

  }

  $Resultado["Aplicaciones"] = $Aplicaciones

  # ------------------------------------------------------------
  # VIRTUAL DIRECTORIES DEL SITE RAIZ
  # ------------------------------------------------------------
  $VirtualDirectoriesSite = @()

  $VDirsSite = Get-WebVirtualDirectory `
    -Site $NombreSite `
    -Application "/" `
    -ErrorAction SilentlyContinue

  foreach ($VD in $VDirsSite) {
    $VirtualDirectoriesSite += [ordered]@{
      Path         = $VD.Path

      PhysicalPath = $VD.PhysicalPath

      LogonMethod  = $VD.LogonMethod

      UserName     = $VD.UserName
    }
  }

  $Resultado["VirtualDirectoriesSite"] = $VirtualDirectoriesSite

  # ------------------------------------------------------------
  # TODOS LOS APPLICATION POOLS DEL SERVIDOR
  # ------------------------------------------------------------
  $ApplicationPools = @()

  $Pools = Get-ChildItem IIS:\AppPools

  foreach ($Pool in $Pools) {

    $ApplicationPools += [ordered]@{
      Name                          = $Pool.Name

      ManagedRuntimeVersion         = $Pool.managedRuntimeVersion

      ManagedPipelineMode           = $Pool.managedPipelineMode

      AutoStart                     = $Pool.autoStart

      Enable32BitAppOnWin64         = $Pool.enable32BitAppOnWin64

      IdentityType                  = $Pool.processModel.identityType

      UserName                      = $Pool.processModel.userName

      StartMode                     = $Pool.startMode

      IdleTimeout                   = $Pool.processModel.idleTimeout

      PingEnabled                   = $Pool.processModel.pingingEnabled

      PingInterval                  = $Pool.processModel.pingInterval

      PingResponseTime              = $Pool.processModel.pingResponseTime

      RapidFailProtection           = $Pool.failure.rapidFailProtection

      RapidFailProtectionInterval   = $Pool.failure.rapidFailProtectionInterval

      RapidFailProtectionMaxCrashes = $Pool.failure.rapidFailProtectionMaxCrashes
    }
  }
  $Resultado["ApplicationPools"] = $ApplicationPools

  # ------------------------------------------------------------
  # DEVOLVER RESULTADO
  # ------------------------------------------------------------
  return $Resultado
}


# -------------------------------
# EJECUTAR EN SERVIDOR REMOTO
# -------------------------------
Write-Host ""
Write-Host "Obteniendo información IIS desde $ServidorOrigen..." `
  -ForegroundColor Cyan

try {
  $Inventario = Invoke-Command `
    -ComputerName $ServidorOrigen `
    -Credential $Credential `
    -ScriptBlock $ScriptRemoto `
    -ArgumentList $NombreSite `
    -ErrorAction Stop
}
catch {
  Write-Host ""
  Write-Host "ERROR ejecutando inventario remoto." `
    -ForegroundColor Red

  Write-Host $_.Exception.Message `
    -ForegroundColor Red
  exit
}


# -------------------------------
# GENERAR ARCHIVO TXT
# -------------------------------
$Salida = New-Object System.Collections.Generic.List[string]

$Salida.Add(
  "======================================================================"
)
$Salida.Add(
  "INVENTARIO IIS - ESTRUCTURA DEL SITE"
)
$Salida.Add(
  "======================================================================"
)
$Salida.Add(
  "Fecha inventario : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
)
$Salida.Add(
  "Servidor origen  : $ServidorOrigen"
)
$Salida.Add(
  "Site IIS         : $($Inventario.Site)"
)
$Salida.Add(
  "Estado           : $($Inventario.Estado)"
)
$Salida.Add(
  "Physical Path    : $($Inventario.PhysicalPath)"
)
$Salida.Add(
  "Application Pool : $($Inventario.ApplicationPool)"
)
$Salida.Add("")

# -------------------------------
# BINDINGS
# -------------------------------
$Salida.Add(
  "======================================================================"
)
$Salida.Add(
  "BINDINGS"
)
$Salida.Add(
  "======================================================================"
)

foreach ($Binding in $Inventario.Bindings) {
  $Salida.Add(
    "Protocol             : $($Binding.Protocol)"
  )
  $Salida.Add(
    "BindingInformation   : $($Binding.BindingInformation)"
  )
  $Salida.Add(
    "CertificateHash      : $($Binding.CertificateHash)"
  )
  $Salida.Add(
    "CertificateStoreName : $($Binding.CertificateStoreName)"
  )
  $Salida.Add("")
}


# -------------------------------
# APPLICATION POOL PRINCIPAL
# -------------------------------
if ($null -ne $Inventario.Pool) {
  $Salida.Add(
    "======================================================================"
  )
  $Salida.Add(
    "APPLICATION POOL PRINCIPAL"
  )
  $Salida.Add(
    "======================================================================"
  )
  $Salida.Add(
    "Nombre                 : $($Inventario.Pool.Name)"
  )
  $Salida.Add(
    "Managed Runtime        : $($Inventario.Pool.ManagedRuntimeVersion)"
  )
  $Salida.Add(
    "Pipeline               : $($Inventario.Pool.ManagedPipelineMode)"
  )
  $Salida.Add(
    "AutoStart              : $($Inventario.Pool.AutoStart)"
  )
  $Salida.Add(
    "Enable32BitAppOnWin64  : $($Inventario.Pool.Enable32BitAppOnWin64)"
  )
  $Salida.Add(
    "Identity Type          : $($Inventario.Pool.IdentityType)"
  )
  $Salida.Add("")
}


# -------------------------------
# APPLICATIONS
# -------------------------------
$Salida.Add(
  "======================================================================"
)
$Salida.Add(
  "APLICACIONES IIS"
)
$Salida.Add(
  "======================================================================"
)
foreach ($App in $Inventario.Aplicaciones) {
  $Salida.Add(
    "---------------------------------------------------------------------"
  )
  $Salida.Add(
    "Application Path       : $($App.Path)"
  )
  $Salida.Add(
    "Physical Path          : $($App.PhysicalPath)"
  )
  $Salida.Add(
    "Application Pool       : $($App.ApplicationPool)"
  )
  $Salida.Add(
    "Enabled Protocols      : $($App.EnabledProtocols)"
  )

  # ------------------------------------------------------------
  # POOL DE LA APLICACION
  # ------------------------------------------------------------
  if ($null -ne $App.Pool) {
    $Salida.Add("")
    $Salida.Add(
      "  APPLICATION POOL"
    )
    $Salida.Add(
      "  Nombre               : $($App.Pool.Name)"
    )
    $Salida.Add(
      "  Managed Runtime      : $($App.Pool.ManagedRuntimeVersion)"
    )
    $Salida.Add(
      "  Pipeline             : $($App.Pool.ManagedPipelineMode)"
    )
    $Salida.Add(
      "  AutoStart            : $($App.Pool.AutoStart)"
    )
    $Salida.Add(
      "  32 bits              : $($App.Pool.Enable32BitAppOnWin64)"
    )
    $Salida.Add(
      "  Identity             : $($App.Pool.IdentityType)"
    )
  }

  # ------------------------------------------------------------
  # VIRTUAL DIRECTORIES
  # ------------------------------------------------------------
  if ($App.VirtualDirectories.Count -gt 0) {
    $Salida.Add("")
    $Salida.Add(
      "  VIRTUAL DIRECTORIES"
    )

    foreach ($VD in $App.VirtualDirectories) {
      $Salida.Add(
        "  Path                 : $($VD.Path)"
      )
      $Salida.Add(
        "  Physical Path        : $($VD.PhysicalPath)"
      )
      $Salida.Add(
        "  Logon Method         : $($VD.LogonMethod)"
      )
      if ($VD.UserName) {
        $Salida.Add(
          "  User                 : $($VD.UserName)"
        )
      }
      $Salida.Add("")
    }
  }

  $Salida.Add("")
}


# -------------------------------
# VIRTUAL DIRECTORIES SITE ROOT
# -------------------------------
if ($Inventario.VirtualDirectoriesSite.Count -gt 0) {
  $Salida.Add(
    "======================================================================"
  )
  $Salida.Add(
    "VIRTUAL DIRECTORIES DEL SITE RAIZ"
  )
  $Salida.Add(
    "======================================================================"
  )

  foreach ($VD in $Inventario.VirtualDirectoriesSite) {
    $Salida.Add(
      "Path                 : $($VD.Path)"
    )
    $Salida.Add(
      "Physical Path        : $($VD.PhysicalPath)"
    )
    $Salida.Add(
      "Logon Method         : $($VD.LogonMethod)"
    )
    if ($VD.UserName) {
      $Salida.Add(
        "User                 : $($VD.UserName)"
      )
    }
    $Salida.Add("")
  }
}


# -------------------------------
# INFORMACION PARA IMPLEMENTACION
# -------------------------------
$Salida.Add(
  "======================================================================"
)
$Salida.Add(
  "DATOS NECESARIOS PARA REIMPLEMENTACION"
)
$Salida.Add(
  "======================================================================"
)
$Salida.Add(
  "1. Crear el Site IIS con el mismo nombre."
)
$Salida.Add(
  "2. Crear los Application Pools indicados."
)
$Salida.Add(
  "3. Configurar Managed Runtime y Pipeline Mode."
)
$Salida.Add(
  "4. Crear el Physical Path del Site."
)
$Salida.Add(
  "5. Crear las aplicaciones IIS con sus respectivos Paths."
)
$Salida.Add(
  "6. Crear los Virtual Directories."
)
$Salida.Add(
  "7. Configurar los Physical Paths."
)
$Salida.Add(
  "8. Configurar los Bindings."
)
$Salida.Add(
  "9. Verificar certificados SSL cuando existan."
)
$Salida.Add(
  "10. Copiar físicamente los directorios de las aplicaciones."
)
$Salida.Add("")
$Salida.Add(
  "======================================================================"
)
$Salida.Add(
  "FIN DEL INVENTARIO"
)
$Salida.Add(
  "======================================================================"
)

# -------------------------------
# GUARDAR TXT
# -------------------------------
$Salida |
Out-File `
  -FilePath $ArchivoSalida `
  -Encoding UTF8 `
  -Force

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Inventario generado correctamente." -ForegroundColor Green

Write-Host ""
Write-Host "Archivo:" -ForegroundColor Cyan

Write-Host $ArchivoSalida -ForegroundColor Yellow
Write-Host ""