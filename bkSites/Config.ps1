<#
===============================================================================
 Config.ps1
 Configuración general del proyecto IIS Migration Toolkit

 Todas las variables modificables se encuentran en este archivo.

 Autor : Leonel Villa / ChatGPT
 Versión : 1.0
===============================================================================
#>

#==============================================================================
# INFORMACIÓN DEL SITIO
#==============================================================================

# Nombre del Site IIS a respaldar
$SiteName = "zenitdesa"

# Nombre que tendrá el Site al restaurar.
# Si está vacío se utilizará el mismo nombre del origen.
$DestinationSiteName = ""

#==============================================================================
# DIRECTORIOS
#==============================================================================

# Carpeta donde se generará el respaldo
$BackupRoot = "C:\Infraestructura"

# Carpeta temporal de trabajo
$TempFolder = Join-Path $BackupRoot "Temp"

# Carpeta donde se almacenarán los metadatos
$MetadataFolder = Join-Path $TempFolder "IIS_METADATA"

#==============================================================================
# WINRAR
#==============================================================================

$WinRAR = "C:\Program Files\WinRAR\WinRAR.exe"

#==============================================================================
# ARCHIVOS GENERADOS
#==============================================================================

$TimeStamp = Get-TimeStamp

$ServerName = $env:COMPUTERNAME

$BackupName = "$SiteName`_$ServerName`_$TimeStamp"

$RARFile = Join-Path $BackupRoot "$BackupName.rar"

$ManifestFile = Join-Path $MetadataFolder "manifest.json"

$ApplicationsFile = Join-Path $MetadataFolder "aplicaciones.txt"

$SiteConfigFile = Join-Path $MetadataFolder "site.xml"

$AppPoolConfigFile = Join-Path $MetadataFolder "apppools.xml"

$VirtualDirectoryFile = Join-Path $MetadataFolder "virtualdirectories.xml"

$StatisticsFile = Join-Path $MetadataFolder "statistics.txt"

$BackupLog = Join-Path $MetadataFolder "Backup.log"

$RARListFile = Join-Path $MetadataFolder "rarfiles.lst"

#==============================================================================
# OPCIONES DEL BACKUP
#==============================================================================

# Incluir directorios virtuales
$IncludeVirtualDirectories = $true

# Sobrescribir el RAR si ya existe
$OverwriteRAR = $true

# Incluir Application Pools
$IncludeApplicationPools = $true

# Incluir configuración del Site
$IncludeSiteConfiguration = $true

# Generar Manifest
$GenerateManifest = $true

#==============================================================================
# EXCLUSIONES
#==============================================================================

# Directorios excluidos
$ExcludedFolders = @(
  "temp",
  "upload"
)

# Extensiones excluidas
$ExcludedExtensions = @(
  "*.rar",
  "*.zip"
)

#==============================================================================
# CONFIGURACIÓN DEL LOG
#==============================================================================

$LogDateFormat = "yyyy-MM-dd HH:mm:ss"

$LogLevel = "INFO"

#==============================================================================
# VALIDACIONES
#==============================================================================

# Espacio libre mínimo requerido (GB)
$MinimumFreeSpaceGB = 5

#==============================================================================
# INFORMACIÓN DEL PROYECTO
#==============================================================================

$ProjectName = "IIS Migration Toolkit"

$ProjectVersion = "1.0"

$Author = "Leonel Villa"

#==============================================================================
# VARIABLES GLOBALES DE TRABAJO
#==============================================================================

# Lista de carpetas únicas que serán respaldadas
$BackupFolders = New-Object System.Collections.Generic.HashSet[string]

# Lista de Application Pools
$ApplicationPools = @()

# Lista de Aplicaciones
$Applications = @()

# Lista de Directorios Virtuales
$VirtualDirectories = @()

# Lista de Sitios
$Sites = @()

#==============================================================================
# FIN DEL ARCHIVO
#==============================================================================

Write-Host ""
Write-Host "==========================================="
Write-Host " Config.ps1 cargado correctamente"
Write-Host "==========================================="
Write-Host ""