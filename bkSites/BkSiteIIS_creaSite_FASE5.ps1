#requires -version 3.0

<#
===========================================================================
 FASE 5 - RECONSTRUCCION DEL SITIO IIS
===========================================================================

 OBJETIVO
 --------
 Reconstruir en el servidor destino la estructura IIS definida en el
 archivo aplicaciones.txt generado durante la FASE 1.

 Se reconstruye:
   - SITE
   - APPLICATION POOLS
   - APPLICATIONS
   - VIRTUAL DIRECTORIES
   - BINDINGS

 Adicionalmente:
   - Busca archivos web.config dentro de las aplicaciones.
   - Identifica web.config que aparentemente contienen configuraciones
     de conexión a bases de datos.
   - Genera webconfigs.txt en el servidor destino.
   - Copia webconfigs.txt al equipo desde donde se ejecuta este script.

===========================================================================
 IMPORTANTE - ANTES DE EJECUTAR
===========================================================================
 1. FASE 2 debe haber generado los RAR.
 2. FASE 3 debe haber descomprimido las aplicaciones en el servidor
    destino.
 3. FASE 4 debe haber creado los directorios físicos correspondientes
    a los VIRTUAL_DIRECTORY.
 4. El archivo aplicaciones.txt debe corresponder exactamente al
    respaldo que se está restaurando.
 5. Este script NO modifica archivos web.config.
 6. Este script NO modifica cadenas de conexión.
 7. Las cadenas de conexión deberán ser modificadas posteriormente
    MANUALMENTE.
 8. Este script NO elimina Sites existentes.
 9. Este script NO elimina Applications existentes.
10. Este script NO elimina Application Pools existentes.
11. Si un elemento ya existe, intenta reutilizarlo.
12. Los Virtual Directory que apunten a:
       \\10.0.0.92\
       \\10.0.0.179\
    NO serán creados/modificados.
13. Las contraseñas de los connection strings NO se escriben en
    webconfigs.txt.
===========================================================================
#>


Clear-Host

# =========================================================================
# VARIABLES
# =========================================================================

$ServidorDestino = "10.0.0.201"
$Usuario = "FIDENSLAT\leonel.villa"
$NombreSite = "DERCO_CORREDOR"
#$FechaBackup = Get-Date -Format "ddMMyyyy"
$FechaBackup = "12082026"

$ArchivoInventario = "C:\Infraestructura\Site\aplicaciones_$NombreSite_$FechaBackup.txt"

$RutaRepositorioDestino = "C:\Infraestructura\Site\$NombreSite_$FechaBackup"

$ArchivoWebConfigsRemoto = Join-Path `
  $RutaRepositorioDestino `
  "webconfigs.txt"

$ArchivoWebConfigsLocal = `
  "C:\Infraestructura\Site\$NombreSite_$FechaBackup\webconfigs.txt"


# =========================================================================
# FUNCIONES
# =========================================================================

function Mostrar-Titulo {
  param(
    [string]$Texto
  )
  Write-Host ""
  Write-Host ("=" * 75)
  Write-Host $Texto
  Write-Host ("=" * 75)
  Write-Host ""
}


function Obtener-Valor {
  param(
    [string[]]$Bloque,
    [string]$Nombre
  )

  foreach ($Linea in $Bloque) {
    if ($Linea -match "^\s*$([regex]::Escape($Nombre))\s*=\s*(.*)$") {
      return $Matches[1].Trim()
    }
  }

  return $null
}


function Obtener-ListaACL {
  param(
    [string[]]$Bloque
  )
  $Resultado = @()

  foreach ($Linea in $Bloque) {
    if ($Linea -match "^ACL\s*=\s*(.*)$") {
      $Resultado += $Matches[1].Trim()
    }
  }

  return $Resultado
}


# =========================================================================
# INICIO
# =========================================================================
Mostrar-Titulo "FASE 5 - RECONSTRUCCION IIS"
Write-Host "Servidor destino : $ServidorDestino"
Write-Host "Usuario          : $Usuario"
Write-Host "Site             : $NombreSite"
Write-Host "Inventario       : $ArchivoInventario"


# =========================================================================
# VALIDAR INVENTARIO
# =========================================================================
Mostrar-Titulo "VALIDANDO ARCHIVO DE INVENTARIO"
if (-not (Test-Path -LiteralPath $ArchivoInventario)) {
  Write-Host "[ERROR] No existe el archivo:" -ForegroundColor Red
  Write-Host $ArchivoInventario
  Read-Host "Presione ENTER para finalizar"
  exit 1
}

Write-Host "[OK] Archivo encontrado."

# =========================================================================
# LEER INVENTARIO
# =========================================================================
Mostrar-Titulo "LEYENDO INVENTARIO IIS"
try {
  $Lineas = Get-Content `
    -LiteralPath $ArchivoInventario `
    -ErrorAction Stop
}
catch {
  Write-Host "[ERROR] No fue posible leer el inventario." -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  Read-Host "Presione ENTER para finalizar"
  exit 1
}

# =========================================================================
# ESTRUCTURAS
# =========================================================================
$SiteData = @{}
$Applications = @()
$VirtualDirectories = @()
$ApplicationPools = @()
$Bindings = @()

# =========================================================================
# DETECTAR SECCIONES
# =========================================================================
$SeccionActual = ""
$BloqueActual = @()

function Procesar-Bloque {
  param(
    [string]$Seccion,
    [string[]]$Bloque
  )
  if ($Bloque.Count -eq 0) {
    return
  }

  # =====================================================================
  # SITE
  # =====================================================================
  if ($Seccion -eq "SITE") {
    $script:SiteData = @{
      Name             = Obtener-Valor $Bloque "Name"
      PhysicalPath     = Obtener-Valor $Bloque "PhysicalPath"
      ApplicationPool  = Obtener-Valor $Bloque "ApplicationPool"
      ServerAutoStart  = Obtener-Valor $Bloque "ServerAutoStart"
      EnabledProtocols = Obtener-Valor $Bloque "EnabledProtocols"
    }
    return
  }

  # =====================================================================
  # APPLICATION
  # =====================================================================
  if ($Seccion -eq "APPLICATIONS") {
    $Name = Obtener-Valor $Bloque "Name"
    $IISPath = Obtener-Valor $Bloque "IISPath"
    $PhysicalPath = Obtener-Valor $Bloque "PhysicalPath"
    $ApplicationPool = Obtener-Valor $Bloque "ApplicationPool"
    $EnabledProtocols = Obtener-Valor $Bloque "EnabledProtocols"

    if ($Name -and $IISPath -and $PhysicalPath) {
      $script:Applications += [PSCustomObject]@{
        Name             = $Name
        IISPath          = $IISPath
        PhysicalPath     = $PhysicalPath
        ApplicationPool  = $ApplicationPool
        EnabledProtocols = $EnabledProtocols
      }
    }

    return
  }

  # =====================================================================
  # VIRTUAL DIRECTORY
  # =====================================================================
  if ($Seccion -eq "VIRTUAL_DIRECTORIES") {
    $Path = Obtener-Valor $Bloque "Path"
    $PhysicalPath = Obtener-Valor $Bloque "physicalPath"
    $Application = Obtener-Valor $Bloque "Application"

    if ($Path -and $PhysicalPath) {
      $script:VirtualDirectories += [PSCustomObject]@{
        Path         = $Path
        PhysicalPath = $PhysicalPath
        Application  = $Application
      }
    }

    return
  }


  # =====================================================================
  # APPLICATION POOL
  # =====================================================================
  if ($Seccion -eq "APPLICATION_POOLS") {
    $Name = Obtener-Valor $Bloque "name"
    $Runtime = Obtener-Valor $Bloque "managedRuntimeVersion"
    $Pipeline = Obtener-Valor $Bloque "managedPipelineMode"

    if ($Name) {
      $script:ApplicationPools += [PSCustomObject]@{
        Name     = $Name
        Runtime  = $Runtime
        Pipeline = $Pipeline
      }
    }

    return
  }

  # =====================================================================
  # BINDING
  # =====================================================================
  if ($Seccion -eq "BINDINGS") {
    $Protocol = Obtener-Valor $Bloque "Protocol"
    $BindingInformation = Obtener-Valor $Bloque "BindingInformation"
    $HostHeader = Obtener-Valor $Bloque "HostHeader"
    $IPAddress = Obtener-Valor $Bloque "IPAddress"
    $Port = Obtener-Valor $Bloque "Port"
    $CertificateHash = Obtener-Valor $Bloque "CertificateHash"
    $CertificateStoreName = Obtener-Valor $Bloque "CertificateStoreName"

    if ($Protocol -and $BindingInformation) {
      $script:Bindings += [PSCustomObject]@{
        Protocol             = $Protocol
        BindingInformation   = $BindingInformation
        HostHeader           = $HostHeader
        IPAddress            = $IPAddress
        Port                 = $Port
        CertificateHash      = $CertificateHash
        CertificateStoreName = $CertificateStoreName
      }
    }

    return
  }
}

foreach ($Linea in $Lineas) {
  $Texto = $Linea.Trim()

  # ---------------------------------------------------------------------
  # Detectar secciones
  # ---------------------------------------------------------------------
  if ($Texto -eq "SITE") {
    if ($BloqueActual.Count -gt 0) {
      Procesar-Bloque `
        -Seccion $SeccionActual `
        -Bloque $BloqueActual
    }

    $SeccionActual = "SITE"
    $BloqueActual = @()

    continue
  }

  if ($Texto -eq "APLICACIONES IIS") {
    if ($BloqueActual.Count -gt 0) {
      Procesar-Bloque `
        -Seccion $SeccionActual `
        -Bloque $BloqueActual
    }

    $SeccionActual = "APPLICATIONS"
    $BloqueActual = @()

    continue
  }

  if ($Texto -eq "VIRTUAL DIRECTORIES") {
    if ($BloqueActual.Count -gt 0) {
      Procesar-Bloque `
        -Seccion $SeccionActual `
        -Bloque $BloqueActual
    }

    $SeccionActual = "VIRTUAL_DIRECTORIES"
    $BloqueActual = @()

    continue
  }

  if ($Texto -eq "APPLICATION POOLS") {
    if ($BloqueActual.Count -gt 0) {
      Procesar-Bloque `
        -Seccion $SeccionActual `
        -Bloque $BloqueActual
    }

    $SeccionActual = "APPLICATION_POOLS"
    $BloqueActual = @()

    continue
  }

  if ($Texto -eq "BINDINGS") {
    if ($BloqueActual.Count -gt 0) {
      Procesar-Bloque `
        -Seccion $SeccionActual `
        -Bloque $BloqueActual
    }

    $SeccionActual = "BINDINGS"
    $BloqueActual = @()

    continue
  }

  # ---------------------------------------------------------------------
  # Nuevo bloque
  # ---------------------------------------------------------------------
  if ($Texto -match "^\[.*\]$") {
    if ($BloqueActual.Count -gt 0) {
      Procesar-Bloque `
        -Seccion $SeccionActual `
        -Bloque $BloqueActual
    }

    $BloqueActual = @($Texto)

    continue
  }

  # ---------------------------------------------------------------------
  # Acumular linea
  # ---------------------------------------------------------------------
  if ($SeccionActual) {
    $BloqueActual += $Linea
  }
}

# =========================================================================
# PROCESAR ULTIMO BLOQUE
# =========================================================================
if ($BloqueActual.Count -gt 0) {
  Procesar-Bloque `
    -Seccion $SeccionActual `
    -Bloque $BloqueActual
}

# =========================================================================
# MOSTRAR INVENTARIO
# =========================================================================
Mostrar-Titulo "RESUMEN DEL INVENTARIO"
Write-Host "Site                 : $($SiteData.Name)"
Write-Host "PhysicalPath         : $($SiteData.PhysicalPath)"
Write-Host "ApplicationPool      : $($SiteData.ApplicationPool)"
Write-Host ""
Write-Host "Applications         : $($Applications.Count)"
Write-Host "Virtual Directories  : $($VirtualDirectories.Count)"
Write-Host "Application Pools    : $($ApplicationPools.Count)"
Write-Host "Bindings             : $($Bindings.Count)"

# =========================================================================
# CREDENCIALES
# =========================================================================
Mostrar-Titulo "CREDENCIALES"

$Password = Read-Host `
  "Ingrese el password de $Usuario" `
  -AsSecureString

$Credencial = New-Object `
  System.Management.Automation.PSCredential(
  $Usuario,
  $Password
)

# =========================================================================
# WINRM
# =========================================================================
Mostrar-Titulo "VALIDANDO WINRM"
try {
  Test-WSMan `
    -ComputerName $ServidorDestino `
    -ErrorAction Stop | Out-Null

  Write-Host "[OK] WinRM disponible."
}
catch {
  Write-Host "[ERROR] WinRM no disponible." -ForegroundColor Red
  Write-Host $_.Exception.Message
  Read-Host "Presione ENTER para finalizar"
  exit 1
}

# =========================================================================
# SESION REMOTA
# =========================================================================
Mostrar-Titulo "ESTABLECIENDO SESION REMOTA"
try {
  $Sesion = New-PSSession `
    -ComputerName $ServidorDestino `
    -Credential $Credencial `
    -ErrorAction Stop

  Write-Host "[OK] Sesion establecida."
}
catch {
  Write-Host "[ERROR] No fue posible establecer la sesion." -ForegroundColor Red
  Write-Host $_.Exception.Message
  Read-Host "Presione ENTER para finalizar"
  exit 1
}

# =========================================================================
# VALIDAR IIS
# =========================================================================
Mostrar-Titulo "VALIDANDO IIS EN SERVIDOR DESTINO"
try {
  $IISOK = Invoke-Command `
    -Session $Sesion `
    -ScriptBlock {
    Import-Module WebAdministration `
      -ErrorAction Stop

    return $true
  } `
    -ErrorAction Stop
  Write-Host "[OK] IIS / WebAdministration disponible."
}
catch {
  Write-Host "[ERROR] IIS/WebAdministration no disponible." -ForegroundColor Red
  Write-Host $_.Exception.Message
  Remove-PSSession $Sesion
  Read-Host "Presione ENTER para finalizar"
  exit 1
}

# =========================================================================
# CREAR REPOSITORIO
# =========================================================================
Mostrar-Titulo "VALIDANDO REPOSITORIO DESTINO"
try {
  Invoke-Command `
    -Session $Sesion `
    -ScriptBlock {
    param(
      $Ruta
    )
    if (-not (Test-Path -LiteralPath $Ruta)) {
      New-Item `
        -ItemType Directory `
        -Path $Ruta `
        -Force | Out-Null

      return "CREADO"
    }

    return "EXISTENTE"

  } `
    -ArgumentList $RutaRepositorioDestino `
    -ErrorAction Stop |
  ForEach-Object {
    Write-Host "Repositorio : $RutaRepositorioDestino"
    Write-Host "Estado      : $_"
  }
}
catch {
  Write-Host "[ERROR] No fue posible crear el repositorio." -ForegroundColor Red
  Write-Host $_.Exception.Message
}

# =========================================================================
# APPLICATION POOLS
# =========================================================================
Mostrar-Titulo "CREANDO / VALIDANDO APPLICATION POOLS"
foreach ($Pool in $ApplicationPools) {
  Write-Host ""
  Write-Host "Application Pool : $($Pool.Name)"
  Write-Host "Runtime          : $($Pool.Runtime)"
  Write-Host "Pipeline         : $($Pool.Pipeline)"
  try {
    $ResultadoPool = Invoke-Command -Session $Sesion -ScriptBlock {
      param(
        $Nombre,
        $Runtime,
        $Pipeline
      )

      Import-Module WebAdministration

      $RutaPool = "IIS:\AppPools\$Nombre"

      if (-not (Test-Path -LiteralPath $RutaPool)) {
        New-WebAppPool `
          -Name $Nombre `
          -ErrorAction Stop | Out-Null

        $Estado = "CREADO"
      }
      else {
        $Estado = "EXISTENTE"
      }

      # ---------------------------------------------------------
      # Runtime
      # ---------------------------------------------------------
      if ($Runtime -ne $null -and
        $Runtime -ne "") {
        Set-ItemProperty `
          -Path $RutaPool `
          -Name managedRuntimeVersion `
          -Value $Runtime `
          -ErrorAction Stop
      }

      # ---------------------------------------------------------
      # Pipeline
      # ---------------------------------------------------------
      if ($Pipeline -eq "Integrated" -or $Pipeline -eq "Classic") {
        Set-ItemProperty `
          -Path $RutaPool `
          -Name managedPipelineMode `
          -Value $Pipeline `
          -ErrorAction Stop
      }

      return $Estado
    } `
      -ArgumentList `
      $Pool.Name,
    $Pool.Runtime,
    $Pool.Pipeline `
      -ErrorAction Stop


    Write-Host "[OK] $ResultadoPool"
  }
  catch {
    Write-Host "[ERROR] Application Pool $($Pool.Name)" -ForegroundColor Red
    Write-Host $_.Exception.Message
  }
}

# =========================================================================
# CREAR SITE
# =========================================================================
Mostrar-Titulo "CREANDO / VALIDANDO SITE"
$SitePhysicalPath = $SiteData.PhysicalPath
if ([string]::IsNullOrWhiteSpace($SitePhysicalPath)) {
  Write-Host "[ERROR] El Site no tiene PhysicalPath." -ForegroundColor Red
  Remove-PSSession $Sesion
  exit 1
}

try {
  $ResultadoSite = Invoke-Command `
    -Session $Sesion `
    -ScriptBlock {

    param(
      $NombreSite,
      $PhysicalPath,
      $ApplicationPool
    )

    Import-Module WebAdministration

    # -------------------------------------------------------------
    # Directorio fisico
    # -------------------------------------------------------------
    if (-not (Test-Path -LiteralPath $PhysicalPath)) {
      New-Item `
        -ItemType Directory `
        -Path $PhysicalPath `
        -Force | Out-Null
    }

    # -------------------------------------------------------------
    # Site
    # -------------------------------------------------------------
    $Site = Get-Website `
      -Name $NombreSite `
      -ErrorAction SilentlyContinue

    if ($null -eq $Site) {
      # Crear Site sin binding inicial especifico.
      #
      # El binding se configurara posteriormente.
      New-Website `
        -Name $NombreSite `
        -PhysicalPath $PhysicalPath `
        -Port 80 `
        -ErrorAction Stop | Out-Null

      $Estado = "CREADO"
    }
    else {
      $Estado = "EXISTENTE"
      Set-ItemProperty `
        "IIS:\Sites\$NombreSite" `
        -Name physicalPath `
        -Value $PhysicalPath `
        -ErrorAction Stop
    }

    # -------------------------------------------------------------
    # Application Pool del Site
    # -------------------------------------------------------------
    if ($ApplicationPool) {
      Set-ItemProperty `
        "IIS:\Sites\$NombreSite" `
        -Name applicationPool `
        -Value $ApplicationPool `
        -ErrorAction SilentlyContinue
    }

    return $Estado
  } `
    -ArgumentList `
    $NombreSite,
  $SitePhysicalPath,
  $SiteData.ApplicationPool `
    -ErrorAction Stop

  Write-Host "[OK] Site $ResultadoSite"
  Write-Host "PhysicalPath : $SitePhysicalPath"
}
catch {
  Write-Host "[ERROR] No fue posible crear/configurar el Site." -ForegroundColor Red
  Write-Host $_.Exception.Message
  Remove-PSSession $Sesion
  exit 1
}

# =========================================================================
# BINDINGS
# =========================================================================
Mostrar-Titulo "CONFIGURANDO BINDINGS"
foreach ($Binding in $Bindings) {
  Write-Host ""
  Write-Host "Protocol          : $($Binding.Protocol)"
  Write-Host "BindingInformation: $($Binding.BindingInformation)"
  Write-Host "HostHeader        : $($Binding.HostHeader)"
  Write-Host "Port              : $($Binding.Port)"
  try {
    $ResultadoBinding = Invoke-Command `
      -Session $Sesion `
      -ScriptBlock {
      param(
        $NombreSite,
        $Protocol,
        $BindingInformation,
        $HostHeader,
        $CertificateHash,
        $CertificateStoreName
      )

      Import-Module WebAdministration

      $BindingExistente = Get-WebBinding `
        -Name $NombreSite `
        -Protocol $Protocol `
        -ErrorAction SilentlyContinue |
      Where-Object {
        $_.bindingInformation -eq $BindingInformation
      }

      if ($BindingExistente) {
        return "EXISTENTE"
      }

      # ---------------------------------------------------------
      # HTTPS
      # ---------------------------------------------------------
      if ($Protocol -eq "https") {
        try {
          New-WebBinding `
            -Name $NombreSite `
            -Protocol "https" `
            -BindingInformation $BindingInformation `
            -ErrorAction Stop | Out-Null

          # -------------------------------------------------
          # Certificado
          # -------------------------------------------------
          if ($CertificateHash) {
            $CertStore = "Cert:\LocalMachine\$CertificateStoreName"

            $Cert = Get-ChildItem `
              -Path $CertStore `
              -ErrorAction SilentlyContinue |
            Where-Object {
              $_.Thumbprint -eq
              ($CertificateHash -replace "\s", "")
            }

            if ($Cert) {
              try {
                $BindingObj = Get-WebBinding `
                  -Name $NombreSite `
                  -Protocol "https" |
                Where-Object {

                  $_.bindingInformation -eq
                  $BindingInformation
                }

                $BindingObj.AddSslCertificate(
                  $Cert.Thumbprint,
                  $CertificateStoreName
                )
                return "CREADO_CERTIFICADO"
              }
              catch {
                return "CREADO_SIN_CERTIFICADO"
              }
            }
            else {
              return "CREADO_SIN_CERTIFICADO"
            }
          }
          return "CREADO"
        }
        catch {
          return "ERROR_HTTPS: $($_.Exception.Message)"
        }
      }

      # ---------------------------------------------------------
      # HTTP
      # ---------------------------------------------------------
      New-WebBinding `
        -Name $NombreSite `
        -Protocol $Protocol `
        -BindingInformation $BindingInformation `
        -ErrorAction Stop | Out-Null

      return "CREADO"
    } `
      -ArgumentList `
      $NombreSite,
    $Binding.Protocol,
    $Binding.BindingInformation,
    $Binding.HostHeader,
    $Binding.CertificateHash,
    $Binding.CertificateStoreName `
      -ErrorAction Stop

    if ($ResultadoBinding -eq "CREADO_SIN_CERTIFICADO") {
      Write-Host "[AVISO] Binding HTTPS creado pero SIN certificado." -ForegroundColor Yellow
    }
    elseif ($ResultadoBinding -like "ERROR*") {
      Write-Host "[ERROR] $ResultadoBinding" -ForegroundColor Red
    }
    else {
      Write-Host "[OK] $ResultadoBinding"
    }
  }
  catch {
    Write-Host "[ERROR] Binding." -ForegroundColor Red
    Write-Host $_.Exception.Message
  }
}

# =========================================================================
# APPLICATIONS IIS
# =========================================================================
Mostrar-Titulo "CREANDO APPLICATIONS IIS"
$Contador = 0
foreach ($App in $Applications) {
  $Contador++
  Write-Host ""
  Write-Host ("APPLICATION {0} DE {1}" -f $Contador, $Applications.Count)
  Write-Host "Nombre          : $($App.Name)"
  Write-Host "IISPath         : $($App.IISPath)"
  Write-Host "PhysicalPath    : $($App.PhysicalPath)"
  Write-Host "ApplicationPool : $($App.ApplicationPool)"

  try {
    $ResultadoApp = Invoke-Command `
      -Session $Sesion `
      -ScriptBlock {

      param(
        $NombreSite,
        $NombreApp,
        $IISPath,
        $PhysicalPath,
        $ApplicationPool
      )

      Import-Module WebAdministration

      # ---------------------------------------------------------
      # Directorio fisico
      # ---------------------------------------------------------
      if (-not (Test-Path -LiteralPath $PhysicalPath)) {
        New-Item `
          -ItemType Directory `
          -Path $PhysicalPath `
          -Force | Out-Null
      }

      # ---------------------------------------------------------
      # Normalizar IISPath
      # ---------------------------------------------------------
      $RutaIIS = $IISPath.Trim("/")

      # ---------------------------------------------------------
      # Buscar Application
      # ---------------------------------------------------------
      $Application = Get-WebApplication `
        -Site $NombreSite `
        -Name $RutaIIS `
        -ErrorAction SilentlyContinue

      if ($Application) {
        # -----------------------------------------------------
        # Actualizar configuracion existente
        # -----------------------------------------------------
        Set-ItemProperty `
          "IIS:\Sites\$NombreSite\$RutaIIS" `
          -Name physicalPath `
          -Value $PhysicalPath `
          -ErrorAction Stop

        if ($ApplicationPool) {
          Set-ItemProperty `
            "IIS:\Sites\$NombreSite\$RutaIIS" `
            -Name applicationPool `
            -Value $ApplicationPool `
            -ErrorAction Stop
        }

        return "EXISTENTE_ACTUALIZADA"
      }

      # ---------------------------------------------------------
      # Crear Application
      # ---------------------------------------------------------
      New-WebApplication `
        -Site $NombreSite `
        -Name $RutaIIS `
        -PhysicalPath $PhysicalPath `
        -ApplicationPool $ApplicationPool `
        -ErrorAction Stop | Out-Null

      return "CREADA"
    } `
      -ArgumentList `
      $NombreSite,
    $App.Name,
    $App.IISPath,
    $App.PhysicalPath,
    $App.ApplicationPool `
      -ErrorAction Stop

    Write-Host "[OK] $ResultadoApp" -ForegroundColor Green
  }
  catch {
    Write-Host "[ERROR] Application $($App.Name)" -ForegroundColor Red
    Write-Host $_.Exception.Message
  }
}

# =========================================================================
# VIRTUAL DIRECTORIES
# =========================================================================
Mostrar-Titulo "CREANDO VIRTUAL DIRECTORIES"
$ContadorVD = 0
foreach ($VD in $VirtualDirectories) {
  $ContadorVD++
  Write-Host ""
  Write-Host ("VIRTUAL DIRECTORY {0} DE {1}" -f $ContadorVD, $VirtualDirectories.Count)
  Write-Host "Path          : $($VD.Path)"
  Write-Host "PhysicalPath  : $($VD.PhysicalPath)"

  # =====================================================================
  # EXCLUSION UNC
  # =====================================================================
  if ($VD.PhysicalPath -match '^\\\\10\.0\.0\.92\\') {
    Write-Host "[EXCLUIDO] \\10.0.0.92" -ForegroundColor Yellow
    continue
  }

  if ($VD.PhysicalPath -match '^\\\\10\.0\.0\.179\\') {
    Write-Host "[EXCLUIDO] \\10.0.0.179" -ForegroundColor Yellow
    continue
  }

  # =====================================================================
  # DETERMINAR PADRE
  # =====================================================================
  $ParentApplication = $VD.Application

  try {
    $ResultadoVD = Invoke-Command `
      -Session $Sesion `
      -ScriptBlock {

      param(
        $NombreSite,
        $Path,
        $PhysicalPath,
        $ParentApplication
      )

      Import-Module WebAdministration

      # ---------------------------------------------------------
      # Limpiar path
      # ---------------------------------------------------------
      $NombreVD = $Path.Trim("/")

      # ---------------------------------------------------------
      # Directorio fisico
      # ---------------------------------------------------------
      if (-not (Test-Path -LiteralPath $PhysicalPath)) {
        New-Item `
          -ItemType Directory `
          -Path $PhysicalPath `
          -Force | Out-Null
      }

      # ---------------------------------------------------------
      # Si tiene Application padre
      # ---------------------------------------------------------
      if ($ParentApplication) {
        $ApplicationPath = $ParentApplication.Trim("/")

        $RutaVD = "IIS:\Sites\$NombreSite\$ApplicationPath\$NombreVD"

        if (Test-Path -LiteralPath $RutaVD) {
          Set-ItemProperty `
            -Path $RutaVD `
            -Name physicalPath `
            -Value $PhysicalPath `
            -ErrorAction Stop

          return "EXISTENTE_ACTUALIZADO"
        }

        New-WebVirtualDirectory `
          -Site $NombreSite `
          -Application $ApplicationPath `
          -Name $NombreVD `
          -PhysicalPath $PhysicalPath `
          -ErrorAction Stop | Out-Null
        return "CREADO"
      }

      # ---------------------------------------------------------
      # Virtual Directory a nivel Site
      # ---------------------------------------------------------
      $RutaVD = "IIS:\Sites\$NombreSite\$NombreVD"

      if (Test-Path -LiteralPath $RutaVD) {
        Set-ItemProperty `
          -Path $RutaVD `
          -Name physicalPath `
          -Value $PhysicalPath `
          -ErrorAction Stop

        return "EXISTENTE_ACTUALIZADO"
      }

      New-WebVirtualDirectory `
        -Site $NombreSite `
        -Name $NombreVD `
        -PhysicalPath $PhysicalPath `
        -ErrorAction Stop | Out-Null

      return "CREADO"
    } `
      -ArgumentList `
      $NombreSite,
    $VD.Path,
    $VD.PhysicalPath,
    $ParentApplication `
      -ErrorAction Stop

    Write-Host "[OK] $ResultadoVD" -ForegroundColor Green
  }
  catch {
    Write-Host "[ERROR] Virtual Directory" -ForegroundColor Red
    Write-Host $_.Exception.Message
  }
}

# =========================================================================
# GENERAR WEBCONFIGS.TXT
# =========================================================================
Mostrar-Titulo "BUSCANDO WEBCONFIG CON CONNECTION STRING"
Write-Host "Esta etapa NO modifica los web.config."
Write-Host ""
Write-Host "Se buscaran archivos web.config dentro de las aplicaciones."
Write-Host "Solo se registraran aquellos que contengan indicios de conexion"
Write-Host "a bases de datos."
Write-Host ""

try {
  $ResultadoBusqueda = Invoke-Command `
    -Session $Sesion `
    -ScriptBlock {

    param(
      $Applications,
      $ArchivoSalida
    )

    $Resultados = @()

    # -------------------------------------------------------------
    # Crear directorio de salida
    # -------------------------------------------------------------
    $DirectorioSalida = Split-Path `
      -Path $ArchivoSalida `
      -Parent

    if (-not (Test-Path -LiteralPath $DirectorioSalida)) {
      New-Item `
        -ItemType Directory `
        -Path $DirectorioSalida `
        -Force | Out-Null
    }

    # -------------------------------------------------------------
    # Encabezado
    # -------------------------------------------------------------
    $Resultados += ""
    $Resultados += "======================================================================"
    $Resultados += "WEBCONFIG CON POSIBLES CONNECTION STRINGS"
    $Resultados += "======================================================================"
    $Resultados += ""
    $Resultados += "Servidor : $env:COMPUTERNAME"
    $Resultados += "Fecha    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $Resultados += ""
    $Resultados += "IMPORTANTE:"
    $Resultados += "Este archivo solamente identifica los web.config."
    $Resultados += "NO contiene cadenas de conexion."
    $Resultados += "Las cadenas de conexion deben modificarse manualmente."
    $Resultados += ""

    # -------------------------------------------------------------
    # Patrones de deteccion
    # -------------------------------------------------------------
    $Patrones = @(
      'connectionStrings',
      'connectionString\s*=',
      'connectionString\s*:',
      'Data Source\s*=',
      'DataSource\s*=',
      'Initial Catalog\s*=',
      'InitialCatalog\s*=',
      'Integrated Security\s*=',
      'Trusted_Connection\s*=',
      'Server\s*=\s*[^<\r\n;]+',
      'Database\s*=\s*[^<\r\n;]+',
      'User ID\s*=',
      'UserID\s*=',
      'Persist Security Info\s*='
    )

    $NumeroAplicacion = 0

    foreach ($App in $Applications) {
      $NumeroAplicacion++

      $Nombre = $App.Name
      $IISPath = $App.IISPath
      $PhysicalPath = $App.PhysicalPath

      Write-Output "Analizando application $NumeroAplicacion : $Nombre"

      if (-not (Test-Path -LiteralPath $PhysicalPath)) {
        $Resultados += ""
        $Resultados += "[APPLICATION]"
        $Resultados += "Name = $Nombre"
        $Resultados += "IISPath = $IISPath"
        $Resultados += "PhysicalPath = $PhysicalPath"
        $Resultados += "Estado = PHYSICALPATH_NO_EXISTE"

        continue
      }

      try {
        $WebConfigs = Get-ChildItem `
          -LiteralPath $PhysicalPath `
          -Filter "web.config" `
          -File `
          -Recurse `
          -Force `
          -ErrorAction SilentlyContinue
      }
      catch {
        $Resultados += ""
        $Resultados += "[APPLICATION]"
        $Resultados += "Name = $Nombre"
        $Resultados += "IISPath = $IISPath"
        $Resultados += "PhysicalPath = $PhysicalPath"
        $Resultados += "Estado = ERROR_LISTANDO"

        continue
      }

      foreach ($WebConfig in $WebConfigs) {
        $Contenido = $null

        try {
          $Contenido = Get-Content `
            -LiteralPath $WebConfig.FullName `
            -Raw `
            -ErrorAction Stop
        }
        catch {
          continue
        }

        $Encontrado = $false

        $PatronEncontrado = @()

        foreach ($Patron in $Patrones) {
          if ($Contenido -match $Patron) {
            $Encontrado = $true

            $PatronEncontrado += $Patron
          }
        }

        if ($Encontrado) {
          $RutaRelativa = $WebConfig.FullName

          if ($WebConfig.FullName.StartsWith(
              $PhysicalPath,
              [System.StringComparison]::OrdinalIgnoreCase
            )) {
            $RutaRelativa =
            $WebConfig.FullName.Substring(
              $PhysicalPath.Length
            ).TrimStart("\")
          }

          $Resultados += ""
          $Resultados += "======================================================================"
          $Resultados += "WEB.CONFIG ENCONTRADO"
          $Resultados += "======================================================================"
          $Resultados += "Application       = $Nombre"
          $Resultados += "IISPath            = $IISPath"
          $Resultados += "PhysicalPath       = $PhysicalPath"
          $Resultados += "WebConfig          = $($WebConfig.FullName)"
          $Resultados += "RutaRelativa       = $RutaRelativa"
          $Resultados += "PatronesDetectados = $($PatronEncontrado -join ', ')"
          $Resultados += ""
        }
      }
    }

    if ($Resultados.Count -eq 0) {
      $Resultados += ""
      $Resultados += "No se encontraron web.config con patrones de"
      $Resultados += "connection string."
    }

    # -------------------------------------------------------------
    # Guardar
    # -------------------------------------------------------------
    $Resultados |
    Out-File `
      -FilePath $ArchivoSalida `
      -Encoding UTF8 `
      -Force

    return $ArchivoSalida
  } `
    -ArgumentList `
    $Applications,
  $ArchivoWebConfigsRemoto `
    -ErrorAction Stop

  Write-Host ""
  Write-Host "[OK] Archivo generado en servidor destino:"
  Write-Host $ArchivoWebConfigsRemoto
}
catch {
  Write-Host ""
  Write-Host "[ERROR] No fue posible generar webconfigs.txt." -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
}

# =========================================================================
# COPIAR WEBCONFIGS.TXT AL EQUIPO LOCAL
# =========================================================================
Mostrar-Titulo "COPIANDO WEBCONFIGS.TXT AL EQUIPO LOCAL"
Write-Host "Origen remoto:"
Write-Host "$ServidorDestino : $ArchivoWebConfigsRemoto"
Write-Host ""
Write-Host "Destino local:"
Write-Host $ArchivoWebConfigsLocal
Write-Host ""

try {
  # ---------------------------------------------------------------------
  # Crear directorio local
  # ---------------------------------------------------------------------
  $DirectorioLocal = Split-Path `
    -Path $ArchivoWebConfigsLocal `
    -Parent

  if (-not (Test-Path -LiteralPath $DirectorioLocal)) {
    New-Item `
      -ItemType Directory `
      -Path $DirectorioLocal `
      -Force | Out-Null
  }

  # ---------------------------------------------------------------------
  # Copiar archivo desde sesion remota
  # ---------------------------------------------------------------------
  Copy-Item `
    -FromSession $Sesion `
    -Path $ArchivoWebConfigsRemoto `
    -Destination $ArchivoWebConfigsLocal `
    -Force `
    -ErrorAction Stop

  Write-Host "[OK] webconfigs.txt copiado correctamente." -ForegroundColor Green
  Write-Host ""
  Write-Host "Archivo local:"
  Write-Host $ArchivoWebConfigsLocal
}
catch {
  Write-Host ""
  Write-Host "[ERROR] No fue posible copiar webconfigs.txt." -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
}

# =========================================================================
# VALIDAR ARCHIVO LOCAL
# =========================================================================
Mostrar-Titulo "VALIDACION FINAL"

if (Test-Path -LiteralPath $ArchivoWebConfigsLocal) {
  $InfoArchivo = Get-Item -LiteralPath $ArchivoWebConfigsLocal

  Write-Host "[OK] Archivo disponible localmente."
  Write-Host ""
  Write-Host "Archivo : $($InfoArchivo.FullName)"
  Write-Host "Tamano  : $([math]::Round($InfoArchivo.Length / 1KB,2)) KB"
}
else {
  Write-Host "[ERROR] El archivo local no fue encontrado." -ForegroundColor Red
}

# =========================================================================
# CERRAR SESION
# =========================================================================
Mostrar-Titulo "CERRANDO SESION"
try {
  Remove-PSSession `
    -Session $Sesion `
    -ErrorAction SilentlyContinue
  Write-Host "[OK] Sesion remota cerrada."
}
catch {
  Write-Host "[AVISO] No fue posible cerrar la sesion."
}

# =========================================================================
# FIN
# =========================================================================
Mostrar-Titulo "FASE 5 FINALIZADA"

Write-Host "Servidor destino : $ServidorDestino"
Write-Host "Site             : $NombreSite"
Write-Host ""
Write-Host "Archivo remoto:"
Write-Host $ArchivoWebConfigsRemoto
Write-Host ""
Write-Host "Archivo local:"
Write-Host $ArchivoWebConfigsLocal
Write-Host ""
Write-Host "IMPORTANTE:"
Write-Host "Los web.config NO fueron modificados."
Write-Host "Las cadenas de conexion deben ser revisadas/modificadas"
Write-Host "manualmente antes de poner el sitio en produccion."
Write-Host ""

Read-Host "Presione ENTER para finalizar"