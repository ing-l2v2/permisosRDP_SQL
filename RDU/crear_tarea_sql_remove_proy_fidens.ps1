$TaskName   = "SQL-Revocacion-ProyFidens"
$FolderName = "\Infraestructura"
$ScriptPath = "C:\Users\lvill\Dropbox\AtencionFidens\ScriptSQL\permisos\RDU\sqlMasivoRemove.ps1"

# Crear el folder si no existe
$service = New-Object -ComObject "Schedule.Service"
$service.Connect()
try {
    $root = $service.GetFolder("\")
    $root.GetFolder($FolderName) | Out-Null
} catch {
    $root.CreateFolder($FolderName) | Out-Null
}

# === XML DEL TRIGGER ===
# Diario a las 08:00 + repetici�n cada hora (PT1H) durante 1 d�a (P1D)
# + Trigger al iniciar el equipo

$xml = @"
<Task xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task" version="1.4">
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$(Get-Date -Format "yyyy-MM-ddT08:00:00")</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
      <Repetition>
        <Interval>PT1H</Interval>
        <Duration>P1D</Duration>
      </Repetition>
    </CalendarTrigger>
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$ScriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# Guardar XML temporal
$xmlPath = "$env:TEMP\task_sql_remove_proyfidens.xml"
$xml | Out-File -Encoding UTF8 $xmlPath

# Registrar la tarea desde el XML
Register-ScheduledTask `
   -TaskName $TaskName `
   -TaskPath $FolderName"\" `
   -Xml (Get-Content $xmlPath | Out-String) `
   -Force

Remove-Item $xmlPath -Force

Write-Host "Tarea programada creada exitosamente en $FolderName con nombre $TaskName"