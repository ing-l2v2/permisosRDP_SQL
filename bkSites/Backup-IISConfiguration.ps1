<#
===============================================================================
 Backup-IISConfiguration.ps1

 Obtiene la configuración IIS utilizando únicamente APPCMD.EXE

 Compatible:
    Windows Server 2008 R2
    Windows Server 2012
    Windows Server 2016
    Windows Server 2019
    Windows Server 2022

===============================================================================
#>

#----------------------------------------------------------
# Exporta aplicaciones del Site
#----------------------------------------------------------
function Export-IISConfiguration {
  Write-Log "Exportando configuración IIS..."
  $AppCmd = Get-AppCmd
  if (!(Test-Path $AppCmd)) {
    throw "No existe appcmd.exe"
  }

  & $AppCmd list app /config /site.name:"$SiteName" > $ApplicationsFile

  if (!(Test-File $ApplicationsFile)) {
    throw "No fue posible generar $ApplicationsFile"
  }
  Write-Log "Archivo generado: $ApplicationsFile"
}

#----------------------------------------------------------
# Lee aplicaciones.txt y genera XML
#----------------------------------------------------------
function Load-IISConfiguration {
  Write-Log "Leyendo configuración IIS..."

  $contenido = Get-Content $ApplicationsFile

  if (!$contenido) {
    throw "El archivo aplicaciones.txt está vacío."
  }

  $xml = "<ROOT>`r`n"

  foreach ($linea in $contenido) {
    $xml += $linea + "`r`n"
  }

  $xml += "</ROOT>"

  $script:IISConfiguration = [xml]$xml

  Write-Log "Configuración cargada."
}

#----------------------------------------------------------
# Agrega una carpeta evitando duplicados
#----------------------------------------------------------
function Add-BackupFolder {
  param([string]$PhysicalPath)

  if ([string]::IsNullOrWhiteSpace($PhysicalPath)) {
    return
  }

  if (!(Test-Path $PhysicalPath)) {
    Write-Log "No existe: $PhysicalPath" "WARNING"
    return
  }

  Add-UniquePath $BackupFolders $PhysicalPath
}

#----------------------------------------------------------
# Obtiene todas las carpetas físicas
#----------------------------------------------------------
function Build-BackupFolderList {
  Write-Log "Construyendo inventario..."

  $BackupFolders.Clear()

  foreach ($Application in $script:IISConfiguration.ROOT.application) {
    foreach ($VirtualDirectory in $Application.virtualDirectory) {
      #
      # Si el usuario decidió excluir
      # Directorios Virtuales solamente
      # se respaldará el path "/"
      #

      if (!$IncludeVirtualDirectories) {
        if ($VirtualDirectory.path -ne "/") {
          continue
        }
      }

      $PhysicalPath = $VirtualDirectory.physicalPath

      Add-BackupFolder $PhysicalPath
    }
  }

  Write-Log ("Directorios únicos encontrados: " +
    $BackupFolders.Count)
}

#----------------------------------------------------------
# Guarda listado de carpetas
#----------------------------------------------------------
function Save-BackupFolderList {
  Write-Log "Generando lista para WinRAR..."

  if (Test-File $RARListFile) {
    Remove-Item $RARListFile -Force
  }

  foreach ($Folder in $BackupFolders) {
    Add-Content $RARListFile $Folder
  }

  Write-Log "Archivo generado: $RARListFile"
}

#----------------------------------------------------------
# Muestra resumen
#----------------------------------------------------------
function Show-IISInventory {
  Write-Log ""
  Write-Log "===== INVENTARIO IIS ====="

  foreach ($Folder in $BackupFolders) {
    Write-Log $Folder
  }

  Write-Log "=========================="
}

#----------------------------------------------------------
# Función principal
#----------------------------------------------------------
function Read-IISConfiguration {
  Export-IISConfiguration
  Load-IISConfiguration
  Build-BackupFolderList
  Save-BackupFolderList
  Show-IISInventory
}