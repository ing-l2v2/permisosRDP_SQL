<#
===============================================================================
 Common.ps1
 Librería común para Backup-IIS.ps1 y Restore-IIS.ps1

 Autor  : Leonel Villa / ChatGPT
 Versión: 1.0
===============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# VARIABLES GLOBALES
#----------------------------------------------------------

$script:LogFile = $null

#----------------------------------------------------------
# INICIALIZA EL LOG
#----------------------------------------------------------

function Initialize-Log {
  param(
    [Parameter(Mandatory = $true)]
    [string]$File
  )

  $script:LogFile = $File

  $folder = Split-Path $File

  if (!(Test-Path $folder)) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
  }

  "" | Out-File $script:LogFile -Encoding UTF8
}

#----------------------------------------------------------
# ESCRIBE EN PANTALLA Y LOG
#----------------------------------------------------------

function Write-Log {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [ValidateSet("INFO", "WARNING", "ERROR")]
    [string]$Level = "INFO"
  )

  $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message

  Write-Host $line

  if ($script:LogFile) {
    Add-Content -Path $script:LogFile -Value $line
  }
}

#----------------------------------------------------------
# CREA DIRECTORIO SI NO EXISTE
#----------------------------------------------------------

function New-Folder {
  param([string]$Path)

  if (!(Test-Path $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    Write-Log "Directorio creado: $Path"
  }
}

#----------------------------------------------------------
# VALIDA DIRECTORIO
#----------------------------------------------------------

function Test-Folder {
  param([string]$Path)

  return (Test-Path $Path -PathType Container)
}

#----------------------------------------------------------
# VALIDA ARCHIVO
#----------------------------------------------------------

function Test-File {
  param([string]$Path)

  return (Test-Path $Path -PathType Leaf)
}

#----------------------------------------------------------
# OBTIENE FECHA YYYYMMDD_HHMMSS
#----------------------------------------------------------

function Get-TimeStamp {
  return (Get-Date -Format "yyyyMMdd_HHmmss")
}

#----------------------------------------------------------
# OBTIENE RUTA DE APPCMD
#----------------------------------------------------------

function Get-AppCmd {
  return Join-Path $env:windir "System32\inetsrv\appcmd.exe"
}

#----------------------------------------------------------
# VALIDA IIS
#----------------------------------------------------------

function Test-IISInstalled {
  $appcmd = Get-AppCmd

  if (!(Test-Path $appcmd)) {
    throw "No se encontró appcmd.exe. IIS no está instalado."
  }

  Write-Log "IIS detectado."
}

#----------------------------------------------------------
# VALIDA WINRAR
#----------------------------------------------------------

function Test-WinRAR {
  param([string]$WinRAR)

  if (!(Test-Path $WinRAR)) {
    throw "No existe WinRAR: $WinRAR"
  }

  Write-Log "WinRAR detectado."
}

#----------------------------------------------------------
# EJECUTA WINRAR
#----------------------------------------------------------

function Invoke-WinRAR {
  param(
    [string]$WinRAR,

    [string]$Arguments
  )

  Write-Log "Ejecutando WinRAR..."

  $process = Start-Process `
    -FilePath $WinRAR `
    -ArgumentList $Arguments `
    -Wait `
    -PassThru `
    -NoNewWindow

  if ($process.ExitCode -ne 0) {
    throw "WinRAR retornó código $($process.ExitCode)"
  }

  Write-Log "WinRAR finalizó correctamente."
}

#----------------------------------------------------------
# AGREGA RUTA SIN DUPLICADOS
#----------------------------------------------------------

function Add-UniquePath {
  param(
    [System.Collections.Generic.HashSet[string]]$Collection,
    [string]$Path
  )

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return
  }

  $Path = $Path.Trim()

  if (Test-Path $Path) {
    $Collection.Add($Path) | Out-Null
  }
}

#----------------------------------------------------------
# NORMALIZA RUTA
#----------------------------------------------------------

function Normalize-Path {
  param([string]$Path)

  return ([System.IO.Path]::GetFullPath($Path))
}

#----------------------------------------------------------
# OBTIENE TAMAÑO DIRECTORIO
#----------------------------------------------------------

function Get-FolderSize {
  param([string]$Path)

  if (!(Test-Path $Path)) {
    return 0
  }

  return (Get-ChildItem $Path -Recurse -Force |
    Measure-Object Length -Sum).Sum
}

#----------------------------------------------------------
# ESPACIO LIBRE EN GB
#----------------------------------------------------------

function Test-FreeDiskSpace {
  param(
    [string]$Drive,

    [int]$MinimumGB = 5
  )

  $disk = Get-WmiObject Win32_LogicalDisk |
  Where-Object { $_.DeviceID -eq $Drive }

  if (!$disk) {
    throw "Unidad no encontrada: $Drive"
  }

  $free = [math]::Round($disk.FreeSpace / 1GB, 2)

  Write-Log "Espacio libre en $Drive : $free GB"

  if ($free -lt $MinimumGB) {
    throw "Espacio insuficiente."
  }
}

#----------------------------------------------------------
# VALIDA ADMINISTRADOR
#----------------------------------------------------------

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

  $principal = New-Object Security.Principal.WindowsPrincipal($identity)

  if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Debe ejecutar PowerShell como Administrador."
  }

  Write-Log "Permisos de Administrador OK."
}

Write-Host ""
Write-Host "==============================================="
Write-Host " Common.ps1 cargado correctamente"
Write-Host "==============================================="
Write-Host ""