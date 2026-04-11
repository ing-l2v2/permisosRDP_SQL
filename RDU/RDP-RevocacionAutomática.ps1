# Task en el grupo Infraestructura con el nombre RDP-RevocacionAutomática
$TaskName = "RDU-RevocacionAutomatica"
$FolderName = "\Infraestructura"
$ScriptPath = "C:\Users\lvill\Dropbox\AtencionFidens\ScriptSQL\permisos\RDU\rdpMasivoRemove.ps1"

# Crear el folder si no existe
$service = New-Object -ComObject "Schedule.Service"
$service.Connect()
try {
  $root = $service.GetFolder("\")
  $root.GetFolder($FolderName) | Out-Null
}
catch {
  $root.CreateFolder($FolderName) | Out-Null
}

# === XML DEL TRIGGER DIARIO CON REPETICIÓN ===
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

# Crear archivo XML temporal
$xmlPath = "$env:TEMP\rdp_revocacion_task.xml"
$xml | Out-File -Encoding UTF8 $xmlPath

# Registrar la tarea desde XML
Register-ScheduledTask `
  -TaskName $TaskName `
  -TaskPath $FolderName"\" `
  -Xml (Get-Content $xmlPath | Out-String) `
  -Force

Remove-Item $xmlPath -Force