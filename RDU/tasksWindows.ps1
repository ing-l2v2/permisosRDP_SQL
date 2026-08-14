# ============================================================
# INVENTARIO COMPLETO DE TAREAS PROGRAMADAS
# Windows Server 2019
# ============================================================

$Fecha = Get-Date -Format "yyyyMMdd_HHmmss"

$DirectorioSalida = "C:\Infraestructura\InventarioTareas"
$TaskPath = "\FIDENS\*"     # Tareas dentro de la carpeta FIDENS o * para todas las tareas

if (-not (Test-Path $DirectorioSalida)) {
  New-Item -Path $DirectorioSalida -ItemType Directory | Out-Null
}

$ArchivoCSV = Join-Path $DirectorioSalida "Inventario_Tareas_$Fecha.csv"

Write-Host "Obteniendo tareas programadas..." -ForegroundColor Cyan

$Resultado = @()

$Tareas = Get-ScheduledTask -TaskPath $TaskPath

foreach ($Task in $Tareas) {

  try {

    $Info = Get-ScheduledTaskInfo `
      -TaskName $Task.TaskName `
      -TaskPath $Task.TaskPath `
      -ErrorAction SilentlyContinue

    # ----------------------------------------------------
    # Acciones de la tarea
    # ----------------------------------------------------

    $Acciones = @()

    foreach ($Action in $Task.Actions) {

      $Acciones += (
        "Ejecutable: " + $Action.Execute +
        " | Argumentos: " + $Action.Arguments +
        " | Directorio: " + $Action.WorkingDirectory
      )
    }

    $AccionesTexto = $Acciones -join " || "

    # ----------------------------------------------------
    # Triggers
    # ----------------------------------------------------

    $Triggers = @()

    foreach ($Trigger in $Task.Triggers) {

      $TriggerInfo = $Trigger.TriggerType

      if ($Trigger.StartBoundary) {
        $TriggerInfo += " | Inicio: " + $Trigger.StartBoundary
      }

      if ($Trigger.EndBoundary) {
        $TriggerInfo += " | Fin: " + $Trigger.EndBoundary
      }

      if ($null -ne $Trigger.Enabled) {
        $TriggerInfo += " | Habilitado: " + $Trigger.Enabled
      }

      $Triggers += $TriggerInfo
    }

    $TriggersTexto = $Triggers -join " || "

    # ----------------------------------------------------
    # Registrar información
    # ----------------------------------------------------

    $Resultado += [PSCustomObject]@{

      NombreTarea                  = $Task.TaskName
      RutaTarea                    = $Task.TaskPath

      Estado                       = $Task.State
      Oculta                       = $Task.Settings.Hidden

      Usuario                      = $Task.Principal.UserId
      TipoLogon                    = $Task.Principal.LogonType
      NivelPrivilegio              = $Task.Principal.RunLevel

      Autor                        = $Task.RegistrationInfo.Author
      Descripcion                  = $Task.Description
      FechaRegistro                = $Task.RegistrationInfo.Date

      EjecutarComo                 = $Task.Principal.UserId

      Acciones                     = $AccionesTexto
      Triggers                     = $TriggersTexto

      UltimaEjecucion              = $Info.LastRunTime
      ProximaEjecucion             = $Info.NextRunTime
      ResultadoUltimaEjecucion     = $Info.LastTaskResult

      Habilitada                   = $Task.Settings.Enabled
      PermitirInicioBateria        = $Task.Settings.AllowStartIfOnBatteries
      DetenerBateria               = $Task.Settings.StopIfGoingOnBatteries

      EjecutarSoloUsuarioConectado = $Task.Principal.UserId

      RutaXML                      = $Task.TaskPath + $Task.TaskName
    }

  }
  catch {

    Write-Warning "No se pudo obtener información de: $($Task.TaskPath)$($Task.TaskName)"
  }
}

# ------------------------------------------------------------
# Exportar CSV
# ------------------------------------------------------------

$Resultado |
Sort-Object RutaTarea, NombreTarea |
Export-Csv `
  -Path $ArchivoCSV `
  -NoTypeInformation `
  -Encoding UTF8

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "Inventario terminado" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Total de tareas: $($Resultado.Count)"
Write-Host "Archivo generado:"
Write-Host $ArchivoCSV -ForegroundColor Yellow