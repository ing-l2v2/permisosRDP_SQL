#Requires -Version 5.1
<#
=======================================================================
 INVENTARIO IIS - FASE 1
=======================================================================
 OBJETIVO
 --------
 Obtener desde un servidor IIS remoto toda la informacion necesaria
 para documentar y posteriormente migrar un Site IIS.

 ORIGEN
 -------
 Equipo desde el cual se ejecuta este script.

 SERVIDOR IIS
 ------------
 Variable: $ServidorOrigen

 INFORMACION OBTENIDA
 --------------------
 - Site IIS
 - Estado
 - Physical Path
 - Bindings
 - Application Pools
 - Configuracion de Application Pools
 - Aplicaciones IIS
 - Virtual Directories
 - Authentication
 - Default Documents
 - MIME Types
 - Request Filtering
 - URL Rewrite
 - Existencia de Physical Paths
 - ACL NTFS de aplicaciones y Virtual Directories
 - Informacion necesaria para reconstruccion posterior

 SALIDA
 ------
 C:\Infraestructura\Site\aplicaciones_<site>_<fecha>.txt

 IMPORTANTE
 ----------
 Este script NO realiza backup ni compresion.
 La compresion con WinRAR se realizará posteriormente mediante
 un segundo script que leerá el archivo generado.

 NO SE ALMACENAN PASSWORDS.
=======================================================================
#>


# =====================================================================
# 1. VARIABLES
# =====================================================================
$ServidorOrigen = "10.0.0.59"
$Usuario = "FIDENSLAT\leonel.villa"
$NombreSite = "DERCO_CORREDOR"
$FechaInventario = "11082026"

# ---------------------------------------------------------------------
# Repositorio local donde se almacenará el inventario
# ---------------------------------------------------------------------
$Repositorio = "C:\Infraestructura\Site"

# ---------------------------------------------------------------------
# Nombre automático del archivo
# ---------------------------------------------------------------------
$NombreArchivo = "aplicaciones_{0}_{1}.txt" -f `
  $NombreSite, `
  $FechaInventario

$ArchivoSalida = Join-Path `
  $Repositorio `
  $NombreArchivo

# =====================================================================
# 2. FUNCIONES LOCALES
# =====================================================================
function Add-OutputLine {
  param(
    [System.Collections.Generic.List[string]]$Lista,
    [string]$Texto = ""
  )
  $Lista.Add($Texto)
}

function Add-Section {
  param(
    [System.Collections.Generic.List[string]]$Lista,

    [string]$Nombre
  )
  $Lista.Add("")
  $Lista.Add("======================================================================")
  $Lista.Add($Nombre)
  $Lista.Add("======================================================================")
  $Lista.Add("")
}

# =====================================================================
# 3. CREAR REPOSITORIO LOCAL
# =====================================================================
if (-not (Test-Path -LiteralPath $Repositorio)) {
  Write-Host ""
  Write-Host "Creando repositorio local..." -ForegroundColor Cyan
  New-Item `
    -Path $Repositorio `
    -ItemType Directory `
    -Force | Out-Null
}
Write-Host ""
Write-Host "Repositorio : $Repositorio" -ForegroundColor Green
Write-Host "Archivo     : $ArchivoSalida" -ForegroundColor Green

# =====================================================================
# 4. SOLICITAR PASSWORD
# =====================================================================
Write-Host ""
$Password = Read-Host `
  "Ingrese el password de $Usuario" `
  -AsSecureString

# =====================================================================
# 5. CREAR CREDENTIAL
# =====================================================================
$Credential = New-Object `
  System.Management.Automation.PSCredential(
  $Usuario,
  $Password
)

# =====================================================================
# 6. VALIDAR WINRM
# =====================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Validando conectividad WinRM..." -ForegroundColor Cyan
Write-Host "Servidor : $ServidorOrigen" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

try {
  Test-WSMan `
    -ComputerName $ServidorOrigen `
    -ErrorAction Stop | Out-Null

  Write-Host ""
  Write-Host "WinRM disponible." -ForegroundColor Green
}
catch {
  Write-Host ""
  Write-Host "ERROR: No fue posible conectarse mediante WinRM." -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  exit 1
}

# =====================================================================
# 7. SCRIPT QUE SE EJECUTARÁ EN EL SERVIDOR IIS
# =====================================================================
$ScriptRemoto = {
  param(
    [string]$NombreSite
  )

  # ================================================================
  # CARGAR MODULO IIS
  # ================================================================
  Import-Module WebAdministration -ErrorAction Stop

  # ================================================================
  # FUNCION PARA OBTENER NOMBRE DE APLICACION
  # ================================================================
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

  # ================================================================
  # VALIDAR SITE
  # ================================================================
  $Site = Get-Website `
    -Name $NombreSite `
    -ErrorAction SilentlyContinue

  if ($null -eq $Site) {
    throw "El Site IIS '$NombreSite' no existe en el servidor $env:COMPUTERNAME."
  }

  # ================================================================
  # RESULTADO PRINCIPAL
  # ================================================================
  $Resultado = [ordered]@{}

  $Resultado["Servidor"] = $env:COMPUTERNAME

  $Resultado["Site"] = $Site.Name

  $Resultado["Estado"] = $Site.State

  $Resultado["PhysicalPath"] = $Site.PhysicalPath

  $Resultado["ApplicationPool"] = $Site.ApplicationPool

  $Resultado["ServerComment"] = $Site.ServerAutoStart
  

  # ================================================================
  # INFORMACION DEL PHYSICAL PATH DEL SITE
  # ================================================================
  $SitePathExists = $false
  $SitePathIsDirectory = $false

  if ($Site.PhysicalPath) {
    $SitePathExists = Test-Path `
      -LiteralPath $Site.PhysicalPath `
      -PathType Container

    if ($SitePathExists) {
      $SitePathIsDirectory = $true
    }
  }


  $Resultado["SitePathExists"] = $SitePathExists

  $Resultado["SitePathIsDirectory"] = $SitePathIsDirectory

  # ================================================================
  # BINDINGS
  # ================================================================
  $Bindings = @()

  foreach ($Binding in $Site.Bindings.Collection) {
    $BindingInformation = $Binding.BindingInformation

    $BindingParts = $BindingInformation.Split(":")

    $IPAddress = ""

    $Port = ""

    $HostName = ""

    if ($BindingParts.Count -ge 1) {
      $IPAddress = $BindingParts[0]
    }

    if ($BindingParts.Count -ge 2) {
      $Port = $BindingParts[1]
    }

    if ($BindingParts.Count -ge 3) {
      $HostName = $BindingParts[2]
    }

    $Bindings += [ordered]@{
      Protocol             = $Binding.Protocol

      BindingInformation   = $BindingInformation

      IPAddress            = $IPAddress

      Port                 = $Port

      HostName             = $HostName

      CertificateHash      = $Binding.CertificateHash

      CertificateStoreName = $Binding.CertificateStoreName

      SslFlags             = $Binding.sslFlags
    }
  }

  $Resultado["Bindings"] = $Bindings

  # ================================================================
  # APPLICATION POOL PRINCIPAL
  # ================================================================
  $Pool = Get-Item "IIS:\AppPools\$($Site.ApplicationPool)" -ErrorAction SilentlyContinue

  if ($null -ne $Pool) {
    $Resultado["Pool"] = [ordered]@{
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
  }
  else {
    $Resultado["Pool"] = $null
  }

  # ================================================================
  # TODOS LOS APPLICATION POOLS
  # ================================================================
  $ApplicationPools = @()

  $Pools = Get-ChildItem  IIS:\AppPools -ErrorAction SilentlyContinue

  foreach ($PoolItem in $Pools) {
    $ApplicationPools += [ordered]@{
      Name                          = $PoolItem.Name

      ManagedRuntimeVersion         = $PoolItem.managedRuntimeVersion

      ManagedPipelineMode           = $PoolItem.managedPipelineMode

      AutoStart                     = $PoolItem.autoStart

      Enable32BitAppOnWin64         = $PoolItem.enable32BitAppOnWin64

      IdentityType                  = $PoolItem.processModel.identityType

      UserName                      = $PoolItem.processModel.userName

      StartMode                     = $PoolItem.startMode

      IdleTimeout                   = $PoolItem.processModel.idleTimeout

      IdleTimeoutAction             = $PoolItem.processModel.idleTimeoutAction

      PingEnabled                   = $PoolItem.processModel.pingingEnabled

      PingInterval                  = $PoolItem.processModel.pingInterval

      PingResponseTime              = $PoolItem.processModel.pingResponseTime

      ShutdownTimeLimit             = $PoolItem.processModel.shutdownTimeLimit

      StartupTimeLimit              = $PoolItem.processModel.startupTimeLimit

      RapidFailProtection           = $PoolItem.failure.rapidFailProtection

      RapidFailProtectionInterval   = $PoolItem.failure.rapidFailProtectionInterval

      RapidFailProtectionMaxCrashes = $PoolItem.failure.rapidFailProtectionMaxCrashes
    }
  }

  $Resultado["ApplicationPools"] = $ApplicationPools

  # ================================================================
  # APLICACIONES IIS
  # ================================================================
  $Aplicaciones = @()

  $Apps = Get-WebApplication `
    -Site $NombreSite `
    -ErrorAction SilentlyContinue

  $IndiceAplicacion = 0

  foreach ($App in $Apps) {
    $IndiceAplicacion++

    $NombreAplicacion = Get-ApplicationName -ApplicationPath $App.Path

    $PathExists = $false

    if ($App.PhysicalPath) {
      $PathExists =
      Test-Path `
        -LiteralPath $App.PhysicalPath `
        -PathType Container
    }

    # ------------------------------------------------------------
    # ACL DE LA APLICACION
    # ------------------------------------------------------------
    $ACLs = @()

    if ($PathExists) {
      try {
        $Acl = Get-Acl `
          -LiteralPath $App.PhysicalPath `
          -ErrorAction Stop

        foreach ($Access in $Acl.Access) {
          $ACLs += [ordered]@{
            IdentityReference = $Access.IdentityReference.ToString()

            FileSystemRights  = $Access.FileSystemRights.ToString()

            AccessControlType = $Access.AccessControlType.ToString()

            IsInherited       = $Access.IsInherited

            InheritanceFlags  = $Access.InheritanceFlags.ToString()

            PropagationFlags  = $Access.PropagationFlags.ToString()
          }
        }
      }
      catch {
        $ACLs = @()
      }
    }

    # ------------------------------------------------------------
    # APLICACION
    # ------------------------------------------------------------
    $Aplicacion = [ordered]@{
      Id               = $IndiceAplicacion

      Name             = $NombreAplicacion

      Path             = $App.Path

      PhysicalPath     = $App.PhysicalPath

      PathType         = "Application"

      PathExists       = $PathExists

      ApplicationPool  = $App.ApplicationPool

      EnabledProtocols = $App.EnabledProtocols

      ACLs             = $ACLs
    }

    # ------------------------------------------------------------
    # APPLICATION POOL DE LA APLICACION
    # ------------------------------------------------------------
    if ($App.ApplicationPool) {
      $AppPool = Get-Item `
        "IIS:\AppPools\$($App.ApplicationPool)" `
        -ErrorAction SilentlyContinue

      if ($null -ne $AppPool) {
        $Aplicacion["Pool"] = [ordered]@{
          Name                  = $AppPool.Name

          ManagedRuntimeVersion = $AppPool.managedRuntimeVersion

          ManagedPipelineMode   = $AppPool.managedPipelineMode

          AutoStart             = $AppPool.autoStart

          Enable32BitAppOnWin64 = $AppPool.enable32BitAppOnWin64

          IdentityType          = $AppPool.processModel.identityType

          UserName              = $AppPool.processModel.userName

          StartMode             = $AppPool.startMode

          IdleTimeout           = $AppPool.processModel.idleTimeout

          PingEnabled           = $AppPool.processModel.pingingEnabled

          PingInterval          = $AppPool.processModel.pingInterval

          PingResponseTime      = $AppPool.processModel.pingResponseTime

          RapidFailProtection   = $AppPool.failure.rapidFailProtection
        }
      }
    }

    # ============================================================
    # VIRTUAL DIRECTORIES
    # ============================================================
    $VirtualDirectories = @()

    $VDirs = Get-WebVirtualDirectory `
      -Site $NombreSite `
      -Application $App.Path `
      -ErrorAction SilentlyContinue

    $IndiceVD = 0

    foreach ($VD in $VDirs) {
      $IndiceVD++

      $VDPathExists = $false

      if ($VD.PhysicalPath) {
        $VDPathExists =
        Test-Path `
          -LiteralPath $VD.PhysicalPath `
          -PathType Container
      }

      # --------------------------------------------------------
      # ACL DEL VIRTUAL DIRECTORY
      # --------------------------------------------------------
      $VDACLs = @()

      if ($VDPathExists) {
        try {
          $VDAcl = Get-Acl `
            -LiteralPath $VD.PhysicalPath `
            -ErrorAction Stop

          foreach ($Access in $VDAcl.Access) {
            $VDACLs += [ordered]@{
              IdentityReference = $Access.IdentityReference.ToString()

              FileSystemRights  = $Access.FileSystemRights.ToString()

              AccessControlType = $Access.AccessControlType.ToString()

              IsInherited       = $Access.IsInherited

              InheritanceFlags  = $Access.InheritanceFlags.ToString()

              PropagationFlags  = $Access.PropagationFlags.ToString()
            }
          }
        }
        catch {
          $VDACLs = @()
        }
      }

      $VirtualDirectories += [ordered]@{
        Id           = $IndiceVD

        Path         = $VD.Path

        PhysicalPath = $VD.PhysicalPath

        PathType     = "VirtualDirectory"

        PathExists   = $VDPathExists

        Site         = $NombreSite

        Application  = $App.Path

        LogonMethod  = $VD.LogonMethod

        UserName     = $VD.UserName

        ACLs         = $VDACLs
      }
    }

    $Aplicacion["VirtualDirectories"] = $VirtualDirectories

    $Aplicaciones += $Aplicacion
  }

  $Resultado["Aplicaciones"] = $Aplicaciones

  # ================================================================
  # VIRTUAL DIRECTORIES DEL SITE RAIZ
  # ================================================================
  $VirtualDirectoriesSite = @()

  $VDirsSite = Get-WebVirtualDirectory `
    -Site $NombreSite `
    -Application "/" `
    -ErrorAction SilentlyContinue

  $IndiceRootVD = 0

  foreach ($VD in $VDirsSite) {
    $IndiceRootVD++

    $VDPathExists = $false

    if ($VD.PhysicalPath) {
      $VDPathExists =
      Test-Path `
        -LiteralPath $VD.PhysicalPath `
        -PathType Container
    }

    $VirtualDirectoriesSite += [ordered]@{

      Id           = $IndiceRootVD

      Path         = $VD.Path

      PhysicalPath = $VD.PhysicalPath

      PathType     = "VirtualDirectory"

      PathExists   = $VDPathExists

      Site         = $NombreSite

      Application  = "/"

      LogonMethod  = $VD.LogonMethod

      UserName     = $VD.UserName
    }
  }

  $Resultado["VirtualDirectoriesSite"] = $VirtualDirectoriesSite

  # ================================================================
  # AUTENTICACION
  # ================================================================
  $Autenticacion = [ordered]@{
    Anonymous = $false

    Windows   = $false

    Basic     = $false

    Digest    = $false
  }

  try {
    $Autenticacion.Anonymous =
    (Get-WebConfigurationProperty `
      -Filter "/system.webServer/security/authentication/anonymousAuthentication" `
      -Name enabled `
      -PSPath "IIS:\Sites\$NombreSite" `
      -ErrorAction Stop).Value
  }
  catch {}

  try {
    $Autenticacion.Windows =
    (Get-WebConfigurationProperty `
      -Filter "/system.webServer/security/authentication/windowsAuthentication" `
      -Name enabled `
      -PSPath "IIS:\Sites\$NombreSite" `
      -ErrorAction Stop).Value
  }
  catch {}

  try {
    $Autenticacion.Basic =
    (Get-WebConfigurationProperty `
      -Filter "/system.webServer/security/authentication/basicAuthentication" `
      -Name enabled `
      -PSPath "IIS:\Sites\$NombreSite" `
      -ErrorAction Stop).Value
  }
  catch {}


  try {
    $Autenticacion.Digest =
    (Get-WebConfigurationProperty `
      -Filter "/system.webServer/security/authentication/digestAuthentication" `
      -Name enabled `
      -PSPath "IIS:\Sites\$NombreSite" `
      -ErrorAction Stop).Value

  }
  catch {}

  $Resultado["Autenticacion"] = $Autenticacion

  # ================================================================
  # DEFAULT DOCUMENTS
  # ================================================================
  $DefaultDocuments = @()

  try {
    $Documents = Get-WebConfiguration `
      -Filter "/system.webServer/defaultDocument/files/add" `
      -PSPath "IIS:\Sites\$NombreSite" `
      -ErrorAction Stop

    foreach ($Document in $Documents) {
      if ($Document.value) {
        $DefaultDocuments += $Document.value
      }
    }
  }
  catch {}


  $Resultado["DefaultDocuments"] = $DefaultDocuments

  # ================================================================
  # MIME TYPES
  # ================================================================
  $MimeTypes = @()

  try {
    $Mime = Get-WebConfiguration `
      -Filter "/system.webServer/staticContent/mimeMap" `
      -PSPath "IIS:\Sites\$NombreSite" `
      -ErrorAction Stop

    foreach ($M in $Mime) {
      $MimeTypes += [ordered]@{
        FileExtension = $M.fileExtension

        MimeType      = $M.mimeType
      }
    }
  }
  catch {}

  $Resultado["MimeTypes"] = $MimeTypes

  # ================================================================
  # REQUEST FILTERING
  # ================================================================
  $RequestFiltering = $null

  try {
    $RequestFiltering =
    Get-WebConfiguration `
      -Filter "/system.webServer/security/requestFiltering" `
      -PSPath "IIS:\Sites\$NombreSite" `
      -ErrorAction Stop
  }
  catch {}

  $Resultado["RequestFiltering"] = $RequestFiltering

  # ================================================================
  # URL REWRITE
  # ================================================================
  $Rewrite = $null

  try {
    $Rewrite =
    Get-WebConfiguration `
      -Filter "/system.webServer/rewrite/rules/rule" `
      -PSPath "IIS:\Sites\$NombreSite" `
      -ErrorAction Stop
  }
  catch {}

  $Resultado["URLRewrite"] = $Rewrite

  # ================================================================
  # CONFIGURACION GENERAL DEL SITE
  # ================================================================
  $Resultado["Configuration"] = $null

  try {
    $Resultado["Configuration"] =
    Get-WebConfiguration `
      -Filter "/system.webServer" `
      -PSPath "IIS:\Sites\$NombreSite" `
      -ErrorAction SilentlyContinue
  }
  catch {}

  # ================================================================
  # DEVOLVER INFORMACION
  # ================================================================
  return $Resultado
}



# =====================================================================
# 8. EJECUTAR INVENTARIO REMOTO
# =====================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Obteniendo informacion IIS..." -ForegroundColor Cyan
Write-Host "Servidor : $ServidorOrigen" -ForegroundColor Cyan
Write-Host "Site     : $NombreSite" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

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
  Write-Host "ERROR ejecutando el inventario remoto." -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  exit 1
}

# =====================================================================
# 9. CREAR CONTENIDO DEL TXT
# =====================================================================
$Salida = New-Object System.Collections.Generic.List[string]

# =====================================================================
# CABECERA
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "INVENTARIO IIS / MIGRACION"


$Salida.Add(
  "FechaInventario = $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
)

$Salida.Add(
  "ServidorOrigen = $ServidorOrigen"
)

$Salida.Add(
  "ServidorNombre = $($Inventario.Servidor)"
)

$Salida.Add(
  "Site = $($Inventario.Site)"
)

$Salida.Add(
  "Estado = $($Inventario.Estado)"
)

$Salida.Add(
  "PhysicalPath = $($Inventario.PhysicalPath)"
)

$Salida.Add(
  "PathType = Site"
)

$Salida.Add(
  "PathExists = $($Inventario.SitePathExists)"
)

$Salida.Add(
  "ApplicationPool = $($Inventario.ApplicationPool)"
)

$Salida.Add("")


# =====================================================================
# BINDINGS
# =====================================================================

Add-Section `
  -Lista $Salida `
  -Nombre "BINDINGS"

$IndiceBinding = 0

foreach ($Binding in $Inventario.Bindings) {
  $IndiceBinding++

  $Salida.Add(
    "[BINDING_{0:D3}]" -f $IndiceBinding
  )

  $Salida.Add(
    "Protocol = $($Binding.Protocol)"
  )

  $Salida.Add(
    "BindingInformation = $($Binding.BindingInformation)"
  )

  $Salida.Add(
    "IPAddress = $($Binding.IPAddress)"
  )

  $Salida.Add(
    "Port = $($Binding.Port)"
  )

  $Salida.Add(
    "HostName = $($Binding.HostName)"
  )

  $Salida.Add(
    "CertificateHash = $($Binding.CertificateHash)"
  )

  $Salida.Add(
    "CertificateStoreName = $($Binding.CertificateStoreName)"
  )

  $Salida.Add(
    "SslFlags = $($Binding.SslFlags)"
  )

  $Salida.Add("")
}

# =====================================================================
# APPLICATION POOL PRINCIPAL
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "APPLICATION POOL PRINCIPAL"

if ($null -ne $Inventario.Pool) {
  $Pool = $Inventario.Pool

  $Salida.Add(
    "Name = $($Pool.Name)"
  )

  $Salida.Add(
    "ManagedRuntimeVersion = $($Pool.ManagedRuntimeVersion)"
  )

  $Salida.Add(
    "ManagedPipelineMode = $($Pool.ManagedPipelineMode)"
  )

  $Salida.Add(
    "AutoStart = $($Pool.AutoStart)"
  )

  $Salida.Add(
    "Enable32BitAppOnWin64 = $($Pool.Enable32BitAppOnWin64)"
  )

  $Salida.Add(
    "IdentityType = $($Pool.IdentityType)"
  )

  $Salida.Add(
    "UserName = $($Pool.UserName)"
  )

  $Salida.Add(
    "StartMode = $($Pool.StartMode)"
  )

  $Salida.Add(
    "IdleTimeout = $($Pool.IdleTimeout)"
  )

  $Salida.Add(
    "IdleTimeoutAction = $($Pool.IdleTimeoutAction)"
  )

  $Salida.Add(
    "PingEnabled = $($Pool.PingEnabled)"
  )

  $Salida.Add(
    "PingInterval = $($Pool.PingInterval)"
  )

  $Salida.Add(
    "PingResponseTime = $($Pool.PingResponseTime)"
  )

  $Salida.Add(
    "ShutdownTimeLimit = $($Pool.ShutdownTimeLimit)"
  )

  $Salida.Add(
    "StartupTimeLimit = $($Pool.StartupTimeLimit)"
  )

  $Salida.Add(
    "RapidFailProtection = $($Pool.RapidFailProtection)"
  )

  $Salida.Add(
    "RapidFailProtectionInterval = $($Pool.RapidFailProtectionInterval)"
  )

  $Salida.Add(
    "RapidFailProtectionMaxCrashes = $($Pool.RapidFailProtectionMaxCrashes)
"
  )
}
else {
  $Salida.Add(
    "ApplicationPoolNotFound = True"
  )
}

# =====================================================================
# TODOS LOS APPLICATION POOLS
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "APPLICATION POOLS"

$IndicePool = 0

foreach ($Pool in $Inventario.ApplicationPools) {
  $IndicePool++

  $Salida.Add(
    "[APPPOOL_{0:D3}]" -f $IndicePool
  )

  $Salida.Add(
    "Name = $($Pool.Name)"
  )

  $Salida.Add(
    "ManagedRuntimeVersion = $($Pool.ManagedRuntimeVersion)"
  )

  $Salida.Add(
    "ManagedPipelineMode = $($Pool.ManagedPipelineMode)"
  )

  $Salida.Add(
    "AutoStart = $($Pool.AutoStart)"
  )

  $Salida.Add(
    "Enable32BitAppOnWin64 = $($Pool.Enable32BitAppOnWin64)"
  )

  $Salida.Add(
    "IdentityType = $($Pool.IdentityType)"
  )

  $Salida.Add(
    "UserName = $($Pool.UserName)"
  )

  $Salida.Add(
    "StartMode = $($Pool.StartMode)"
  )

  $Salida.Add(
    "IdleTimeout = $($Pool.IdleTimeout)"
  )

  $Salida.Add(
    "IdleTimeoutAction = $($Pool.IdleTimeoutAction)"
  )

  $Salida.Add(
    "PingEnabled = $($Pool.PingEnabled)"
  )

  $Salida.Add(
    "PingInterval = $($Pool.PingInterval)"
  )

  $Salida.Add(
    "PingResponseTime = $($Pool.PingResponseTime)"
  )

  $Salida.Add(
    "ShutdownTimeLimit = $($Pool.ShutdownTimeLimit)"
  )

  $Salida.Add(
    "StartupTimeLimit = $($Pool.StartupTimeLimit)"
  )

  $Salida.Add(
    "RapidFailProtection = $($Pool.RapidFailProtection)"
  )

  $Salida.Add(
    "RapidFailProtectionInterval = $($Pool.RapidFailProtectionInterval)"
  )

  $Salida.Add(
    "RapidFailProtectionMaxCrashes = $($Pool.RapidFailProtectionMaxCrashes)"
  )

  $Salida.Add("")
}

# =====================================================================
# APLICACIONES IIS
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "APLICACIONES IIS"

foreach ($App in $Inventario.Aplicaciones) {
  $IdApp =
  "{0:D3}" -f $App.Id

  $Salida.Add(
    "[APPLICATION_$IdApp]"
  )

  $Salida.Add(
    "Name = $($App.Name)"
  )

  $Salida.Add(
    "Path = $($App.Path)"
  )

  $Salida.Add(
    "PhysicalPath = $($App.PhysicalPath)"
  )

  $Salida.Add(
    "PathType = $($App.PathType)"
  )

  $Salida.Add(
    "PathExists = $($App.PathExists)"
  )

  $Salida.Add(
    "ApplicationPool = $($App.ApplicationPool)"
  )

  $Salida.Add(
    "EnabledProtocols = $($App.EnabledProtocols)"
  )

  $Salida.Add("")

  # ================================================================
  # POOL DE LA APLICACION
  # ================================================================
  if ($null -ne $App.Pool) {
    $Salida.Add(
      "[APPLICATION_${IdApp}_POOL]"
    )

    $Salida.Add(
      "Name = $($App.Pool.Name)"
    )

    $Salida.Add(
      "ManagedRuntimeVersion = $($App.Pool.ManagedRuntimeVersion)"
    )

    $Salida.Add(
      "ManagedPipelineMode = $($App.Pool.ManagedPipelineMode)"
    )

    $Salida.Add(
      "AutoStart = $($App.Pool.AutoStart)"
    )

    $Salida.Add(
      "Enable32BitAppOnWin64 = $($App.Pool.Enable32BitAppOnWin64)"
    )

    $Salida.Add(
      "IdentityType = $($App.Pool.IdentityType)"
    )

    $Salida.Add(
      "UserName = $($App.Pool.UserName)"
    )

    $Salida.Add(
      "StartMode = $($App.Pool.StartMode)"
    )

    $Salida.Add(
      "IdleTimeout = $($App.Pool.IdleTimeout)"
    )

    $Salida.Add(
      "PingEnabled = $($App.Pool.PingEnabled)"
    )

    $Salida.Add(
      "PingInterval = $($App.Pool.PingInterval)"
    )

    $Salida.Add(
      "PingResponseTime = $($App.Pool.PingResponseTime)"
    )

    $Salida.Add(
      "RapidFailProtection = $($App.Pool.RapidFailProtection)"
    )

    $Salida.Add("")
  }

  # ================================================================
  # VIRTUAL DIRECTORIES
  # ================================================================
  foreach ($VD in $App.VirtualDirectories) {
    $IdVD =
    "{0:D3}" -f $VD.Id

    $Salida.Add(
      "[APPLICATION_${IdApp}_VDIR_$IdVD]"
    )

    $Salida.Add(
      "Path = $($VD.Path)"
    )

    $Salida.Add(
      "PhysicalPath = $($VD.PhysicalPath)"
    )

    $Salida.Add(
      "PathType = $($VD.PathType)"
    )

    $Salida.Add(
      "PathExists = $($VD.PathExists)"
    )

    $Salida.Add(
      "Site = $($VD.Site)"
    )

    $Salida.Add(
      "Application = $($VD.Application)"
    )

    $Salida.Add(
      "LogonMethod = $($VD.LogonMethod)"
    )

    $Salida.Add(
      "UserName = $($VD.UserName)"
    )

    $Salida.Add("")

    # ------------------------------------------------------------
    # ACL DEL VIRTUAL DIRECTORY
    # ------------------------------------------------------------
    $IndiceACL = 0

    foreach ($ACL in $VD.ACLs) {
      $IndiceACL++

      $Salida.Add(
        "[APPLICATION_${IdApp}_VDIR_${IdVD}_ACL_{0:D3}]" -f $IndiceACL
      )

      $Salida.Add(
        "IdentityReference = $($ACL.IdentityReference)"
      )

      $Salida.Add(
        "FileSystemRights = $($ACL.FileSystemRights)"
      )

      $Salida.Add(
        "AccessControlType = $($ACL.AccessControlType)"
      )

      $Salida.Add(
        "IsInherited = $($ACL.IsInherited)"
      )

      $Salida.Add(
        "InheritanceFlags = $($ACL.InheritanceFlags)"
      )

      $Salida.Add(
        "PropagationFlags = $($ACL.PropagationFlags)"
      )

      $Salida.Add("")
    }
  }



  # ================================================================
  # ACL DE LA APLICACION
  # ================================================================
  $IndiceACLApp = 0

  foreach ($ACL in $App.ACLs) {
    $IndiceACLApp++

    $Salida.Add(
      "[APPLICATION_${IdApp}_ACL_{0:D3}]" -f $IndiceACLApp
    )

    $Salida.Add(
      "IdentityReference = $($ACL.IdentityReference)"
    )

    $Salida.Add(
      "FileSystemRights = $($ACL.FileSystemRights)"
    )

    $Salida.Add(
      "AccessControlType = $($ACL.AccessControlType)"
    )

    $Salida.Add(
      "IsInherited = $($ACL.IsInherited)"
    )

    $Salida.Add(
      "InheritanceFlags = $($ACL.InheritanceFlags)"
    )

    $Salida.Add(
      "PropagationFlags = $($ACL.PropagationFlags)"
    )

    $Salida.Add("")
  }
}


# =====================================================================
# VIRTUAL DIRECTORIES DEL SITE ROOT
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "VIRTUAL DIRECTORIES DEL SITE ROOT"

foreach ($VD in $Inventario.VirtualDirectoriesSite) {
  $IdVD = "{0:D3}" -f $VD.Id

  $Salida.Add(
    "[SITE_ROOT_VDIR_$IdVD]"
  )

  $Salida.Add(
    "Path = $($VD.Path)"
  )

  $Salida.Add(
    "PhysicalPath = $($VD.PhysicalPath)"
  )

  $Salida.Add(
    "PathType = $($VD.PathType)"
  )

  $Salida.Add(
    "PathExists = $($VD.PathExists)"
  )

  $Salida.Add(
    "Site = $($VD.Site)"
  )

  $Salida.Add(
    "Application = $($VD.Application)"
  )

  $Salida.Add(
    "LogonMethod = $($VD.LogonMethod)"
  )

  $Salida.Add(
    "UserName = $($VD.UserName)"
  )

  $Salida.Add("")

}

# =====================================================================
# AUTENTICACION
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "AUTENTICACION IIS"

$Salida.Add(
  "Anonymous = $($Inventario.Autenticacion.Anonymous)"
)

$Salida.Add(
  "Windows = $($Inventario.Autenticacion.Windows)"
)

$Salida.Add(
  "Basic = $($Inventario.Autenticacion.Basic)"
)

$Salida.Add(
  "Digest = $($Inventario.Autenticacion.Digest)"
)

$Salida.Add("")

# =====================================================================
# DEFAULT DOCUMENTS
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "DEFAULT DOCUMENTS"

$IndiceDocument = 0

foreach ($Document in $Inventario.DefaultDocuments) {
  $IndiceDocument++

  $Salida.Add(
    "[DEFAULT_DOCUMENT_{0:D3}]" -f $IndiceDocument
  )

  $Salida.Add(
    "Name = $Document"
  )

  $Salida.Add("")
}

# =====================================================================
# MIME TYPES
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "MIME TYPES"

$IndiceMime = 0

foreach ($Mime in $Inventario.MimeTypes) {
  $IndiceMime++

  $Salida.Add(
    "[MIME_{0:D3}]" -f $IndiceMime
  )

  $Salida.Add(
    "FileExtension = $($Mime.FileExtension)"
  )

  $Salida.Add(
    "MimeType = $($Mime.MimeType)"
  )

  $Salida.Add("")
}

# =====================================================================
# URL REWRITE
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "URL REWRITE"

if ($null -ne $Inventario.URLRewrite) {
  $IndiceRewrite = 0

  foreach ($Rule in $Inventario.URLRewrite) {
    $IndiceRewrite++

    $Salida.Add(
      "[REWRITE_RULE_{0:D3}]" -f $IndiceRewrite
    )

    foreach ($Property in $Rule.PSObject.Properties) {
      $Valor = $Property.Value

      if ($null -ne $Valor) {
        $Salida.Add(
          "{0} = {1}" -f `
            $Property.Name, `
            $Valor
        )
      }
    }

    $Salida.Add("")
  }
}
else {
  $Salida.Add(
    "URLRewriteInstalled = False"
  )
  $Salida.Add("")
}

# =====================================================================
# REQUEST FILTERING
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "REQUEST FILTERING"

if ($null -ne $Inventario.RequestFiltering) {
  foreach ($Property in $Inventario.RequestFiltering.PSObject.Properties) {
    $Valor = $Property.Value

    if ($null -ne $Valor) {
      $Salida.Add(
        "{0} = {1}" -f $Property.Name, $Valor
      )
    }
  }
}
else {
  $Salida.Add(
    "RequestFilteringAvailable = False"
  )
}
$Salida.Add("")

# =====================================================================
# RESUMEN DE RUTAS PARA BACKUP
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "RUTAS PARA BACKUP"

$IndiceBackup = 0

foreach ($App in $Inventario.Aplicaciones) {
  $IndiceBackup++

  $IdApp = "{0:D3}" -f $App.Id

  $Salida.Add(
    "[BACKUP_APPLICATION_$IdApp]"
  )
  $Salida.Add(
    "ApplicationName = $($App.Name)"
  )
  $Salida.Add(
    "ApplicationPath = $($App.Path)"
  )
  $Salida.Add(
    "PhysicalPath = $($App.PhysicalPath)"
  )
  $Salida.Add(
    "PathExists = $($App.PathExists)"
  )
  $Salida.Add(
    "BackupRequired = True"
  )
  $Salida.Add(
    "PathType = Application"
  )
  $Salida.Add("")
}

# =====================================================================
# RESUMEN DE VIRTUAL DIRECTORIES
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "RUTAS EXTERNAS / VIRTUAL DIRECTORIES"

foreach ($App in $Inventario.Aplicaciones) {
  $IdApp = "{0:D3}" -f $App.Id

  foreach ($VD in $App.VirtualDirectories) {
    $IdVD = "{0:D3}" -f $VD.Id

    $Salida.Add(
      "[EXTERNAL_PATH_${IdApp}_$IdVD]"
    )
    $Salida.Add(
      "ApplicationName = $($App.Name)"
    )
    $Salida.Add(
      "VirtualDirectory = $($VD.Path)"
    )
    $Salida.Add(
      "PhysicalPath = $($VD.PhysicalPath)"
    )
    $Salida.Add(
      "PathExists = $($VD.PathExists)"
    )
    $Salida.Add(
      "PathType = VirtualDirectory"
    )
    $Salida.Add(
      "BackupRequired = True"
    )
    $Salida.Add("")
  }
}

# =====================================================================
# RESUMEN FINAL
# =====================================================================
Add-Section `
  -Lista $Salida `
  -Nombre "INFORMACION PARA MIGRACION"

$Salida.Add(
  "ServidorOrigen = $ServidorOrigen"
)
$Salida.Add(
  "Site = $NombreSite"
)
$Salida.Add(
  "FechaInventario = $FechaInventario"
)
$Salida.Add(
  "RepositorioBackupEsperado = \\10.0.0.179\Backup_BD_APP\$ServidorOrigen\$NombreSite\"
)
$Salida.Add("")
$Salida.Add(
  "IMPORTANTE:"
)
$Salida.Add(
  "Este archivo es un inventario de configuracion y rutas."
)
$Salida.Add(
  "No contiene passwords."
)
$Salida.Add(
  "La compresion de las aplicaciones será realizada por un"
)
$Salida.Add(
  "script independiente de backup."
)
$Salida.Add("")

# =====================================================================
# 10. GUARDAR TXT
# =====================================================================
$Salida |
Out-File `
  -LiteralPath $ArchivoSalida `
  -Encoding UTF8 `
  -Force

# =====================================================================
# 11. RESULTADO
# =====================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "INVENTARIO IIS GENERADO CORRECTAMENTE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Servidor origen :" -ForegroundColor Cyan
Write-Host $ServidorOrigen -ForegroundColor Yellow
Write-Host ""
Write-Host "Site            :" -ForegroundColor Cyan
Write-Host $NombreSite -ForegroundColor Yellow
Write-Host ""
Write-Host "Archivo generado:" -ForegroundColor Cyan
Write-Host $ArchivoSalida -ForegroundColor Yellow
Write-Host ""
Write-Host "Aplicaciones encontradas:" -ForegroundColor Cyan
Write-Host $Inventario.Aplicaciones.Count -ForegroundColor Yellow
Write-Host ""
Write-Host "Application Pools encontrados:" -ForegroundColor Cyan
Write-Host $Inventario.ApplicationPools.Count -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green

<#
  Prueba de conectividad en powershell
    $cred = Get-Credential "FIDENSLAT\leonel.villa"
    Invoke-Command `
    -ComputerName 10.0.0.59 `
    -Credential $cred `
    -ScriptBlock {
        whoami
        hostname
    }

  Prueba de conectividad en powershell con credenciales de dominio para obtener informacion de IIS
    1. Abrir powershell en el equipo local
    2. Ejecutar el siguiente comando:

    $cred = Get-Credential "FIDENSLAT\leonel.villa"
    Invoke-Command `
    -ComputerName 10.0.0.59 `
    -Credential $cred `
    -ScriptBlock {
        Import-Module WebAdministration
        Get-Website
    }
#>