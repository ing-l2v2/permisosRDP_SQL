#Requires -Version 5.1

<#
===============================================================================
 FASE 1 v2 - INVENTARIO IIS PARA MIGRACION
===============================================================================

 OBJETIVO
 --------
 Obtener desde un equipo administrativo la informacion necesaria para
 reconstruir un Site IIS en otro servidor.

 SERVIDOR ORIGEN
 ---------------
 Parametrizado mediante:
    $ServidorOrigen
    $Usuario
    $NombreSite

 SALIDA
 ------
 C:\Infraestructura\Site\aplicaciones_<SITE>_<FECHA>.txt

 IMPORTANTE
 ----------
 Esta fase NO realiza backups.
 Esta fase NO ejecuta WinRAR.
 Esta fase NO modifica IIS.
 Esta fase solamente genera el inventario.

===============================================================================
#>

#Requires -Version 5.1

Clear-Host

#==============================================================================
# 1. VARIABLES PRINCIPALES
#==============================================================================

$ServidorOrigen = "10.0.0.59"

$Usuario = "FIDENSLAT\leonel.villa"

$NombreSite = "DERCO_CORREDOR"

# Repositorio local del inventario
$Repositorio = "C:\Infraestructura\Site"

# Fecha del inventario
$Fecha = Get-Date -Format "ddMMyyyy"

# Nombre del archivo de salida
$ArchivoSalida = Join-Path `
  $Repositorio `
  "aplicaciones_${NombreSite}_${Fecha}.txt"

#==============================================================================
# 2. CONFIGURACION
#==============================================================================

$ErrorActionPreference = "Stop"

# Crear repositorio si no existe
if (-not (Test-Path -LiteralPath $Repositorio)) {

  New-Item `
    -ItemType Directory `
    -Path $Repositorio `
    -Force |
  Out-Null
}

#==============================================================================
# 3. FUNCIONES LOCALES
#==============================================================================

function Add-Line {

  param(
    [string]$Text = ""
  )

  Add-Content `
    -LiteralPath $ArchivoSalida `
    -Value $Text `
    -Encoding UTF8
}

function Add-Section {

  param(
    [string]$Title
  )

  Add-Line ""
  Add-Line "======================================================================"
  Add-Line $Title
  Add-Line "======================================================================"
}

function Add-KeyValue {

  param(
    [string]$Key,
    [object]$Value
  )

  if ($null -eq $Value) {
    $Value = ""
  }

  Add-Line ("{0} = {1}" -f $Key, $Value)
}

function Normalize-IISPath {

  param(
    [string]$Path
  )

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return "/"
  }

  if ($Path -eq "/") {
    return "/"
  }

  return "/" + $Path.Trim("/")
}

function Get-SafeBackupName {

  param(
    [string]$Name,
    [string]$Type,
    [string]$Fecha
  )

  $SafeName = $Name

  # Eliminar caracteres no apropiados para nombre de archivo
  $SafeName = $SafeName -replace '[\\/:*?"<>|]', '_'

  $SafeName = $SafeName.Trim()

  if ([string]::IsNullOrWhiteSpace($SafeName)) {
    $SafeName = "SIN_NOMBRE"
  }

  if ($Type -eq "APPLICATION") {

    return "${SafeName}_${Fecha}.rar"
  }

  if ($Type -eq "VIRTUAL_DIRECTORY") {

    return "VDIR_${SafeName}_${Fecha}.rar"
  }

  return "${SafeName}_${Fecha}.rar"
}

#==============================================================================
# 4. INICIALIZAR ARCHIVO
#==============================================================================

if (Test-Path -LiteralPath $ArchivoSalida) {

  Remove-Item `
    -LiteralPath $ArchivoSalida `
    -Force
}

Add-Section "INVENTARIO IIS / MIGRACION"

Add-KeyValue "FechaInventario" (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Add-KeyValue "ServidorOrigenIP" $ServidorOrigen
Add-KeyValue "UsuarioInventario" $Usuario
Add-KeyValue "Site" $NombreSite
Add-KeyValue "ArchivoInventario" $ArchivoSalida

#==============================================================================
# 5. SOLICITAR CREDENCIALES
#==============================================================================

Write-Host ""
Write-Host "============================================================" `
  -ForegroundColor Cyan

Write-Host "INVENTARIO IIS - FASE 1 v2" `
  -ForegroundColor Cyan

Write-Host "============================================================" `
  -ForegroundColor Cyan

Write-Host ""

Write-Host "Servidor : $ServidorOrigen"
Write-Host "Usuario  : $Usuario"
Write-Host "Site     : $NombreSite"
Write-Host ""

$Credential = Get-Credential `
  -UserName $Usuario `
  -Message "Ingrese el password de $Usuario"

#==============================================================================
# 6. VALIDAR WINRM
#==============================================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "Validando conectividad WinRM..."
Write-Host "Servidor : $ServidorOrigen"
Write-Host "============================================================"

try {

  Test-WSMan `
    -ComputerName $ServidorOrigen `
    -ErrorAction Stop |
  Out-Null

  Write-Host ""
  Write-Host "WinRM disponible." `
    -ForegroundColor Green

  Add-KeyValue "WinRM" "OK"
}
catch {

  Write-Host ""
  Write-Host "ERROR: WinRM no disponible." `
    -ForegroundColor Red

  Add-KeyValue "WinRM" "ERROR"
  Add-KeyValue "WinRMError" $_.Exception.Message

  Write-Host $_.Exception.Message `
    -ForegroundColor Red

  exit 1
}

#==============================================================================
# 7. SCRIPT REMOTO
#==============================================================================

$ScriptRemoto = {

  param(
    [string]$SiteName
  )

  $ErrorActionPreference = "Stop"

  Import-Module WebAdministration

  #----------------------------------------------------------------------
  # ESTRUCTURA DE RESULTADO
  #----------------------------------------------------------------------

  $Resultado = [ordered]@{

    Server             = [ordered]@{}

    Site               = $null

    Bindings           = @()

    Applications       = @()

    VirtualDirectories = @()

    ApplicationPools   = @()

    Errors             = @()
  }

  #----------------------------------------------------------------------
  # INFORMACION DEL SERVIDOR
  #----------------------------------------------------------------------

  try {

    $ComputerSystem = Get-CimInstance `
      Win32_ComputerSystem

    $OperatingSystem = Get-CimInstance `
      Win32_OperatingSystem

    $Resultado.Server = [ordered]@{

      ComputerName      = $env:COMPUTERNAME

      Domain            = $ComputerSystem.Domain

      OS                = $OperatingSystem.Caption

      OSVersion         = $OperatingSystem.Version

      PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }

  }
  catch {

    $Resultado.Errors += [pscustomobject]@{

      Section = "SERVER"

      Message = $_.Exception.Message
    }
  }

  #----------------------------------------------------------------------
  # SITE
  #----------------------------------------------------------------------

  try {

    $Site = Get-Website `
      -Name $SiteName `
      -ErrorAction Stop

    $Resultado.Site = [ordered]@{

      Name             = $Site.Name

      ID               = $Site.ID

      State            = $Site.State

      ServerAutoStart  = $Site.ServerAutoStart

      PhysicalPath     = $Site.PhysicalPath

      ApplicationPool  = $Site.ApplicationPool

      EnabledProtocols = $Site.EnabledProtocols

      Bindings         = $Site.Bindings

    }

  }
  catch {

    $Resultado.Errors += [pscustomobject]@{

      Section = "SITE"

      Message = $_.Exception.Message
    }

    return $Resultado
  }

  #----------------------------------------------------------------------
  # BINDINGS
  #----------------------------------------------------------------------

  try {

    $Bindings = Get-WebBinding `
      -Name $SiteName `
      -ErrorAction Stop

    foreach ($Binding in $Bindings) {

      $Resultado.Bindings += [pscustomobject]@{

        Protocol             = $Binding.Protocol

        BindingInformation   = $Binding.BindingInformation

        HostHeader           = $Binding.HostHeader

        IPAddress            = $Binding.BindingInformation.Split(":")[0]

        Port                 = $Binding.BindingInformation.Split(":")[1]

        CertificateHash      = $Binding.CertificateHash

        CertificateStoreName = $Binding.CertificateStoreName
      }
    }

  }
  catch {

    $Resultado.Errors += [pscustomobject]@{

      Section = "BINDINGS"

      Message = $_.Exception.Message
    }
  }

  #----------------------------------------------------------------------
  # APLICACIONES IIS
  #----------------------------------------------------------------------

  try {

    $Applications = Get-WebApplication `
      -Site $SiteName `
      -ErrorAction Stop

    foreach ($Application in $Applications) {

      $PhysicalPath = $Application.PhysicalPath

      $PathExists = $false

      if (-not [string]::IsNullOrWhiteSpace($PhysicalPath)) {

        try {

          $PathExists = Test-Path `
            -LiteralPath $PhysicalPath `
            -ErrorAction SilentlyContinue

        }
        catch {

          $PathExists = $false
        }
      }

      $ApplicationName = $Application.Path.Trim("/")

      $Resultado.Applications += [pscustomobject]@{

        Name             = $ApplicationName

        IISPath          = $Application.Path

        PhysicalPath     = $PhysicalPath

        ApplicationPool  = $Application.ApplicationPool

        EnabledProtocols = $Application.EnabledProtocols

        PathExists       = $PathExists

        Type             = "APPLICATION"
      }
    }

  }
  catch {

    $Resultado.Errors += [pscustomobject]@{

      Section = "APPLICATIONS"

      Message = $_.Exception.Message
    }
  }

  #----------------------------------------------------------------------
  # VIRTUAL DIRECTORIES
  #----------------------------------------------------------------------

  try {

    $VirtualDirectories = Get-WebVirtualDirectory `
      -Site $SiteName `
      -ErrorAction Stop

    foreach ($VD in $VirtualDirectories) {

      $PhysicalPath = $VD.PhysicalPath

      $PathExists = $false

      if (-not [string]::IsNullOrWhiteSpace($PhysicalPath)) {

        try {

          if ($PhysicalPath -like "\\*") {

            $PathExists = Test-Path `
              -LiteralPath $PhysicalPath `
              -ErrorAction SilentlyContinue
          }
          else {

            $PathExists = Test-Path `
              -LiteralPath $PhysicalPath `
              -ErrorAction SilentlyContinue
          }

        }
        catch {

          $PathExists = $false
        }
      }

      $PathType = "LOCAL"

      if ($PhysicalPath -like "\\*") {

        $PathType = "UNC"
      }

      $Resultado.VirtualDirectories += [pscustomobject]@{

        Name         = $VD.Path.Trim("/")

        IISPath      = $VD.Path

        PhysicalPath = $PhysicalPath

        Application  = $VD.Application

        LogonMethod  = $VD.LogonMethod

        UserName     = $VD.UserName

        PathType     = $PathType

        PathExists   = $PathExists

        Type         = "VIRTUAL_DIRECTORY"
      }
    }

  }
  catch {

    $Resultado.Errors += [pscustomobject]@{

      Section = "VIRTUAL_DIRECTORIES"

      Message = $_.Exception.Message
    }
  }

  #----------------------------------------------------------------------
  # APPLICATION POOLS
  #----------------------------------------------------------------------

  try {

    $PoolNames = @()

    if ($Resultado.Site.ApplicationPool) {

      $PoolNames += $Resultado.Site.ApplicationPool
    }

    foreach ($Application in $Resultado.Applications) {

      if ($Application.ApplicationPool) {

        $PoolNames += $Application.ApplicationPool
      }
    }

    $PoolNames = $PoolNames |
    Sort-Object -Unique

    foreach ($PoolName in $PoolNames) {

      try {

        $Pool = Get-Item `
          "IIS:\AppPools\$PoolName" `
          -ErrorAction Stop

        $Resultado.ApplicationPools += [pscustomobject]@{

          Name                  = $Pool.Name

          ManagedRuntimeVersion = $Pool.managedRuntimeVersion

          ManagedPipelineMode   = $Pool.managedPipelineMode

          AutoStart             = $Pool.autoStart

          Enable32BitAppOnWin64 = $Pool.enable32BitAppOnWin64

          StartMode             = $Pool.startMode

          IdentityType          = $Pool.processModel.identityType

          UserName              = $Pool.processModel.userName

          LoadUserProfile       = $Pool.processModel.loadUserProfile

          IdleTimeout           = $Pool.processModel.idleTimeout

          PingEnabled           = $Pool.recycling.periodicRestart.pingEnabled

          State                 = (
            Get-WebAppPoolState `
              -Name $PoolName `
              -ErrorAction SilentlyContinue
          ).Value
        }

      }
      catch {

        $Resultado.Errors += [pscustomobject]@{

          Section = "APPLICATION_POOL"

          Message = "Pool [$PoolName]: $($_.Exception.Message)"
        }
      }
    }

  }
  catch {

    $Resultado.Errors += [pscustomobject]@{

      Section = "APPLICATION_POOLS"

      Message = $_.Exception.Message
    }
  }

  #----------------------------------------------------------------------
  # ACL NTFS
  #----------------------------------------------------------------------

  function Get-ACLInfo {

    param(
      [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
      return @()
    }

    try {

      if (-not (Test-Path -LiteralPath $Path)) {

        return @(
          [pscustomobject]@{
            Path              = $Path
            IdentityReference = ""
            FileSystemRights  = ""
            AccessControlType = ""
            IsInherited       = ""
            Error             = "PATH_NOT_FOUND"
          }
        )
      }

      $Acl = Get-Acl `
        -LiteralPath $Path `
        -ErrorAction Stop

      $List = @()

      foreach ($Access in $Acl.Access) {

        $List += [pscustomobject]@{

          Path              = $Path

          IdentityReference =
          $Access.IdentityReference.ToString()

          FileSystemRights  =
          $Access.FileSystemRights.ToString()

          AccessControlType =
          $Access.AccessControlType.ToString()

          IsInherited       =
          $Access.IsInherited
        }
      }

      return $List
    }
    catch {

      return @(
        [pscustomobject]@{
          Path              = $Path
          IdentityReference = ""
          FileSystemRights  = ""
          AccessControlType = ""
          IsInherited       = ""
          Error             = $_.Exception.Message
        }
      )
    }
  }

  #----------------------------------------------------------------------
  # ACL DE APLICACIONES
  #----------------------------------------------------------------------

  foreach ($Application in $Resultado.Applications) {

    $Application | Add-Member `
      -MemberType NoteProperty `
      -Name ACL `
      -Value (
      Get-ACLInfo `
        -Path $Application.PhysicalPath
    )
  }

  #----------------------------------------------------------------------
  # ACL DE VIRTUAL DIRECTORIES LOCALES
  #----------------------------------------------------------------------

  foreach ($VD in $Resultado.VirtualDirectories) {

    if ($VD.PathType -eq "LOCAL") {

      $VD | Add-Member `
        -MemberType NoteProperty `
        -Name ACL `
        -Value (
        Get-ACLInfo `
          -Path $VD.PhysicalPath
      )
    }
    else {

      $VD | Add-Member `
        -MemberType NoteProperty `
        -Name ACL `
        -Value @()
    }
  }

  #----------------------------------------------------------------------
  # RESULTADO
  #----------------------------------------------------------------------

  return $Resultado
}

#==============================================================================
# 8. EJECUTAR INVENTARIO REMOTO
#==============================================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "Obteniendo informacion IIS..."
Write-Host "Servidor : $ServidorOrigen"
Write-Host "Site     : $NombreSite"
Write-Host "============================================================"

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
  Write-Host "ERROR ejecutando el inventario remoto." `
    -ForegroundColor Red

  Write-Host ""

  Write-Host "Mensaje:" `
    -ForegroundColor Yellow

  Write-Host $_.Exception.Message `
    -ForegroundColor Red

  Add-KeyValue "InventarioRemoto" "ERROR"
  Add-KeyValue "InventarioRemotoError" $_.Exception.Message

  exit 1
}

#==============================================================================
# 9. VALIDAR RESULTADO DEL SITE
#==============================================================================

if ($null -eq $Inventario.Site) {

  Write-Host ""
  Write-Host "ERROR: No fue posible obtener el Site." `
    -ForegroundColor Red

  Add-KeyValue "SiteStatus" "ERROR"

  foreach ($ErrorItem in $Inventario.Errors) {

    Add-KeyValue `
      "Error_$($ErrorItem.Section)" `
      $ErrorItem.Message
  }

  exit 1
}

#==============================================================================
# 10. INFORMACION DEL SERVIDOR
#==============================================================================

Add-Section "SERVIDOR ORIGEN"

Add-KeyValue "ComputerName" `
  $Inventario.Server.ComputerName

Add-KeyValue "Domain" `
  $Inventario.Server.Domain

Add-KeyValue "OperatingSystem" `
  $Inventario.Server.OS

Add-KeyValue "OSVersion" `
  $Inventario.Server.OSVersion

Add-KeyValue "PowerShellVersion" `
  $Inventario.Server.PowerShellVersion

#==============================================================================
# 11. INFORMACION DEL SITE
#==============================================================================

Add-Section "SITE IIS"

Add-KeyValue "Name" `
  $Inventario.Site.Name

Add-KeyValue "ID" `
  $Inventario.Site.ID

Add-KeyValue "State" `
  $Inventario.Site.State

Add-KeyValue "ServerAutoStart" `
  $Inventario.Site.ServerAutoStart

Add-KeyValue "PhysicalPath" `
  $Inventario.Site.PhysicalPath

Add-KeyValue "ApplicationPool" `
  $Inventario.Site.ApplicationPool

Add-KeyValue "EnabledProtocols" `
  $Inventario.Site.EnabledProtocols

#==============================================================================
# 12. BINDINGS
#==============================================================================

Add-Section "BINDINGS"

$BindingIndex = 0

foreach ($Binding in $Inventario.Bindings) {

  $BindingIndex++

  Add-Line ""
  Add-Line "[BINDING_$("{0:D3}" -f $BindingIndex)]"

  Add-KeyValue "Protocol" `
    $Binding.Protocol

  Add-KeyValue "BindingInformation" `
    $Binding.BindingInformation

  Add-KeyValue "HostHeader" `
    $Binding.HostHeader

  Add-KeyValue "IPAddress" `
    $Binding.IPAddress

  Add-KeyValue "Port" `
    $Binding.Port

  Add-KeyValue "CertificateHash" `
    $Binding.CertificateHash

  Add-KeyValue "CertificateStoreName" `
    $Binding.CertificateStoreName
}

#==============================================================================
# 13. APPLICATION POOLS
#==============================================================================

Add-Section "APPLICATION POOLS"

$PoolIndex = 0

foreach ($Pool in $Inventario.ApplicationPools) {

  $PoolIndex++

  Add-Line ""
  Add-Line "[APPLICATION_POOL_$("{0:D3}" -f $PoolIndex)]"

  Add-KeyValue "Name" `
    $Pool.Name

  Add-KeyValue "State" `
    $Pool.State

  Add-KeyValue "ManagedRuntimeVersion" `
    $Pool.ManagedRuntimeVersion

  Add-KeyValue "ManagedPipelineMode" `
    $Pool.ManagedPipelineMode

  Add-KeyValue "AutoStart" `
    $Pool.AutoStart

  Add-KeyValue "Enable32BitAppOnWin64" `
    $Pool.Enable32BitAppOnWin64

  Add-KeyValue "StartMode" `
    $Pool.StartMode

  Add-KeyValue "IdentityType" `
    $Pool.IdentityType

  Add-KeyValue "UserName" `
    $Pool.UserName

  Add-KeyValue "LoadUserProfile" `
    $Pool.LoadUserProfile

  Add-KeyValue "IdleTimeout" `
    $Pool.IdleTimeout

  Add-KeyValue "PingEnabled" `
    $Pool.PingEnabled
}

#==============================================================================
# 14. APLICACIONES IIS
#==============================================================================

Add-Section "APLICACIONES IIS"

$ApplicationIndex = 0

foreach ($Application in $Inventario.Applications) {

  $ApplicationIndex++

  Add-Line ""
  Add-Line "[APPLICATION_$("{0:D3}" -f $ApplicationIndex)]"

  Add-KeyValue "Type" `
    "APPLICATION"

  Add-KeyValue "Name" `
    $Application.Name

  Add-KeyValue "IISPath" `
    $Application.IISPath

  Add-KeyValue "PhysicalPath" `
    $Application.PhysicalPath

  Add-KeyValue "ApplicationPool" `
    $Application.ApplicationPool

  Add-KeyValue "EnabledProtocols" `
    $Application.EnabledProtocols

  Add-KeyValue "PathExists" `
    $Application.PathExists

  # ACL
  if ($Application.ACL) {

    Add-Line "ACLCount = $($Application.ACL.Count)"

    foreach ($ACL in $Application.ACL) {

      Add-Line (
        "ACL = {0} | Rights={1} | Type={2} | Inherited={3}" -f `
          $ACL.IdentityReference,
        $ACL.FileSystemRights,
        $ACL.AccessControlType,
        $ACL.IsInherited
      )
    }
  }
}

#==============================================================================
# 15. VIRTUAL DIRECTORIES
#==============================================================================

Add-Section "VIRTUAL DIRECTORIES"

$VDIndex = 0

foreach ($VD in $Inventario.VirtualDirectories) {

  $VDIndex++

  Add-Line ""
  Add-Line "[VIRTUAL_DIRECTORY_$("{0:D3}" -f $VDIndex)]"

  Add-KeyValue "Type" `
    "VIRTUAL_DIRECTORY"

  Add-KeyValue "Name" `
    $VD.Name

  Add-KeyValue "IISPath" `
    $VD.IISPath

  Add-KeyValue "PhysicalPath" `
    $VD.PhysicalPath

  Add-KeyValue "PathType" `
    $VD.PathType

  Add-KeyValue "Application" `
    $VD.Application

  Add-KeyValue "LogonMethod" `
    $VD.LogonMethod

  Add-KeyValue "UserName" `
    $VD.UserName

  Add-KeyValue "PathExists" `
    $VD.PathExists

  if ($VD.ACL) {

    Add-Line "ACLCount = $($VD.ACL.Count)"

    foreach ($ACL in $VD.ACL) {

      Add-Line (
        "ACL = {0} | Rights={1} | Type={2} | Inherited={3}" -f `
          $ACL.IdentityReference,
        $ACL.FileSystemRights,
        $ACL.AccessControlType,
        $ACL.IsInherited
      )
    }
  }
}

#==============================================================================
# 16. RUTAS PARA BACKUP
#==============================================================================

Add-Section "RUTAS PARA BACKUP"

$BackupIndex = 0

$BackupPaths = @()

#------------------------------------------------------------------------------
# APLICACIONES
#------------------------------------------------------------------------------

foreach ($Application in $Inventario.Applications) {

  $BackupIndex++

  $BackupFileName = Get-SafeBackupName `
    -Name $Application.Name `
    -Type "APPLICATION" `
    -Fecha $Fecha

  $BackupPaths += [pscustomobject]@{

    ID              = $BackupIndex

    Type            = "APPLICATION"

    Name            = $Application.Name

    IISPath         = $Application.IISPath

    PhysicalPath    = $Application.PhysicalPath

    PathType        = "LOCAL"

    ApplicationPool = $Application.ApplicationPool

    PathExists      = $Application.PathExists

    BackupRequired  = $true

    BackupFileName  = $BackupFileName
  }
}

#------------------------------------------------------------------------------
# VIRTUAL DIRECTORIES
#------------------------------------------------------------------------------

foreach ($VD in $Inventario.VirtualDirectories) {

  $BackupIndex++

  $BackupFileName = Get-SafeBackupName `
    -Name $VD.Name `
    -Type "VIRTUAL_DIRECTORY" `
    -Fecha $Fecha

  $BackupPaths += [pscustomobject]@{

    ID              = $BackupIndex

    Type            = "VIRTUAL_DIRECTORY"

    Name            = $VD.Name

    IISPath         = $VD.IISPath

    PhysicalPath    = $VD.PhysicalPath

    PathType        = $VD.PathType

    ApplicationPool = ""

    PathExists      = $VD.PathExists

    BackupRequired  = $true

    BackupFileName  = $BackupFileName
  }
}

#==============================================================================
# 17. DETECTAR RUTAS DUPLICADAS
#==============================================================================

Add-Section "ANALISIS DE RUTAS"

$NormalizedPaths = @()

foreach ($Item in $BackupPaths) {

  if ([string]::IsNullOrWhiteSpace($Item.PhysicalPath)) {
    continue
  }

  $NormalizedPath = $Item.PhysicalPath.TrimEnd("\").ToLower()

  $NormalizedPaths += [pscustomobject]@{

    ID             = $Item.ID

    Type           = $Item.Type

    Name           = $Item.Name

    PhysicalPath   = $Item.PhysicalPath

    NormalizedPath = $NormalizedPath
  }
}

$DuplicateGroups = $NormalizedPaths |
Group-Object NormalizedPath |
Where-Object { $_.Count -gt 1 }

if ($DuplicateGroups.Count -eq 0) {

  Add-KeyValue "DuplicatePaths" "NONE"
}
else {

  Add-KeyValue `
    "DuplicatePathGroups" `
    $DuplicateGroups.Count

  foreach ($Group in $DuplicateGroups) {

    Add-Line ""
    Add-Line "[DUPLICATE_PATH]"

    Add-KeyValue "PhysicalPath" `
      $Group.Name

    foreach ($Item in $Group.Group) {

      Add-Line (
        "Item = ID:{0} | Type:{1} | Name:{2}" -f `
          $Item.ID,
        $Item.Type,
        $Item.Name
      )
    }
  }
}

#==============================================================================
# 18. DETECTAR RUTAS CONTENIDAS
#==============================================================================

Add-Line ""
Add-Line "[CONTAINED_PATH_ANALYSIS]"

$ContainedCount = 0

for ($i = 0; $i -lt $NormalizedPaths.Count; $i++) {

  for ($j = 0; $j -lt $NormalizedPaths.Count; $j++) {

    if ($i -eq $j) {
      continue
    }

    $Parent = $NormalizedPaths[$i]
    $Child = $NormalizedPaths[$j]

    if (
      $Child.NormalizedPath.StartsWith(
        $Parent.NormalizedPath + "\"
      )
    ) {

      $ContainedCount++

      Add-Line (
        "Parent = ID:{0} | {1}" -f `
          $Parent.ID,
        $Parent.PhysicalPath
      )

      Add-Line (
        "Child  = ID:{0} | {1}" -f `
          $Child.ID,
        $Child.PhysicalPath
      )

      Add-Line ""
    }
  }
}

if ($ContainedCount -eq 0) {

  Add-KeyValue "ContainedPaths" "NONE"
}
else {

  Add-KeyValue `
    "ContainedRelationships" `
    $ContainedCount
}

#==============================================================================
# 19. GENERAR SECCION FINAL DE BACKUPS
#==============================================================================

Add-Section "DETALLE DE RUTAS PARA BACKUP"

foreach ($Item in $BackupPaths) {

  Add-Line ""
  Add-Line "[BACKUP_$("{0:D3}" -f $Item.ID)]"

  Add-KeyValue "Type" `
    $Item.Type

  Add-KeyValue "Name" `
    $Item.Name

  Add-KeyValue "IISPath" `
    $Item.IISPath

  Add-KeyValue "PhysicalPath" `
    $Item.PhysicalPath

  Add-KeyValue "PathType" `
    $Item.PathType

  Add-KeyValue "ApplicationPool" `
    $Item.ApplicationPool

  Add-KeyValue "PathExists" `
    $Item.PathExists

  Add-KeyValue "BackupRequired" `
    $Item.BackupRequired

  Add-KeyValue "BackupFileName" `
    $Item.BackupFileName
}

#==============================================================================
# 20. ERRORES ENCONTRADOS
#==============================================================================

Add-Section "ERRORES / ADVERTENCIAS"

if ($Inventario.Errors.Count -eq 0) {

  Add-KeyValue "Errors" "NONE"
}
else {

  Add-KeyValue `
    "ErrorCount" `
    $Inventario.Errors.Count

  $ErrorIndex = 0

  foreach ($ErrorItem in $Inventario.Errors) {

    $ErrorIndex++

    Add-Line ""
    Add-Line "[ERROR_$("{0:D3}" -f $ErrorIndex)]"

    Add-KeyValue "Section" `
      $ErrorItem.Section

    Add-KeyValue "Message" `
      $ErrorItem.Message
  }
}

#==============================================================================
# 21. RESUMEN
#==============================================================================

Add-Section "RESUMEN"

$TotalApplications =
$Inventario.Applications.Count

$TotalVirtualDirectories =
$Inventario.VirtualDirectories.Count

$TotalApplicationPools =
$Inventario.ApplicationPools.Count

$TotalBindings =
$Inventario.Bindings.Count

$TotalBackupPaths =
$BackupPaths.Count

$TotalLocalPaths =
@(
  $BackupPaths |
  Where-Object {
    $_.PathType -eq "LOCAL"
  }
).Count

$TotalUNCPaths =
@(
  $BackupPaths |
  Where-Object {
    $_.PathType -eq "UNC"
  }
).Count

$TotalExistingPaths =
@(
  $BackupPaths |
  Where-Object {
    $_.PathExists -eq $true
  }
).Count

$TotalMissingPaths =
@(
  $BackupPaths |
  Where-Object {
    $_.PathExists -ne $true
  }
).Count

Add-KeyValue "TotalApplications" `
  $TotalApplications

Add-KeyValue "TotalVirtualDirectories" `
  $TotalVirtualDirectories

Add-KeyValue "TotalApplicationPools" `
  $TotalApplicationPools

Add-KeyValue "TotalBindings" `
  $TotalBindings

Add-KeyValue "TotalBackupPaths" `
  $TotalBackupPaths

Add-KeyValue "TotalLocalPaths" `
  $TotalLocalPaths

Add-KeyValue "TotalUNCPaths" `
  $TotalUNCPaths

Add-KeyValue "TotalExistingPaths" `
  $TotalExistingPaths

Add-KeyValue "TotalMissingPaths" `
  $TotalMissingPaths

Add-KeyValue "TotalErrors" `
  $Inventario.Errors.Count

#==============================================================================
# 22. FIN
#==============================================================================

Add-Section "FIN DEL INVENTARIO"

Add-KeyValue "FechaFin" `
(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Add-KeyValue "ArchivoGenerado" `
  $ArchivoSalida

Write-Host ""
Write-Host "============================================================" `
  -ForegroundColor Green

Write-Host "INVENTARIO COMPLETADO" `
  -ForegroundColor Green

Write-Host "============================================================" `
  -ForegroundColor Green

Write-Host ""

Write-Host "Servidor : $ServidorOrigen"
Write-Host "Site     : $NombreSite"
Write-Host ""

Write-Host "Aplicaciones IIS       : $TotalApplications"
Write-Host "Virtual Directories    : $TotalVirtualDirectories"
Write-Host "Application Pools      : $TotalApplicationPools"
Write-Host "Bindings               : $TotalBindings"
Write-Host "Rutas para backup      : $TotalBackupPaths"
Write-Host "Rutas locales          : $TotalLocalPaths"
Write-Host "Rutas UNC              : $TotalUNCPaths"
Write-Host "Rutas existentes       : $TotalExistingPaths"
Write-Host "Rutas no encontradas   : $TotalMissingPaths"
Write-Host "Errores                : $($Inventario.Errors.Count)"
Write-Host ""

Write-Host "Repositorio : $Repositorio"
Write-Host "Archivo     : $ArchivoSalida"

Write-Host ""

if ($TotalMissingPaths -gt 0) {

  Write-Host "ADVERTENCIA: existen rutas que no fueron encontradas." `
    -ForegroundColor Yellow
}

if ($Inventario.Errors.Count -gt 0) {

  Write-Host "ADVERTENCIA: existen errores registrados en el inventario." `
    -ForegroundColor Yellow
}
else {

  Write-Host "Inventario sin errores." `
    -ForegroundColor Green
}

Write-Host ""