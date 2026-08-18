$BdRepo49 = "master"
$UsrSql = "lvilla"
$Pass49 = "L2v2..20&25.#"
$serv49 = "10.0.0.49"
$BdRepo56 = "ProyFidens"
$serv56 = "10.0.0.56"
$Pass56 = "L2v2..20&25.#"
$Connect49 = "Server=$Serv49;Database=$BdRepo49;User ID=$UsrSql;Password=$Pass49;TrustServerCertificate=True";
$Connect56 = "Server=$serv56;Database=$BdRepo56;User ID=$UsrSql;Password=$Pass56;TrustServerCertificate=True";
$NumRegDup = 0

$inicioProc = Get-Date


$sql49 = @"
SELECT IdAzure, Servidor, Usuario, PermisoAsignado, BaseDatos, NumReg, CodUser, Ejecutar
FROM master.dbo.infraAccesosAzure
WHERE Estado = 'ASIGNADO'
AND Expira <= GETDATE()
ORDER BY IdAzure ASC
"@

# Write-Host $sql49
$expirados = Invoke-Sqlcmd -Query $sql49 -ConnectionString $Connect49


if (-not $expirados -or $expirados.Count -eq 0) {
  Write-Host "No existen accesos expirados para revocar en AZURE." -ForegroundColor Blue
  return
}
else {

  # ================================
  # PROGRESO + TIEMPO ESTIMADO
  # ================================
  $total = $expirados.count
  $startTime = Get-Date
  $index = 0

  foreach ($row in $expirados) {

    $index++
    $percent = [math]::Round(($index / $total) * 100, 2)
    # ===== Tiempo estimado =====
    $elapsed = (Get-Date) - $startTime
    if ($percent -gt 0) {
      $remaining = $elapsed.TotalSeconds * (100 - $percent) / $percent
      $eta = [TimeSpan]::FromSeconds($remaining)
      $etaText = "{0:hh\:mm\:ss}" -f $eta
    }
    else {
      $etaText = "Calculando..."
    }
    Write-Progress `
      -Activity "Revocatoria masiva Azure SQL-GINGER" `
      -Status "Progreso: $percent% | ETA: $etaText | Base: $db " `
      -PercentComplete $percent


    $IdAzure = [int]$row["IdAzure"]
    $ServAzure = $row["Servidor"]
    $Usuario = $row["Usuario"]
    $Permiso = $row["PermisoAsignado"]
    $BaseDatos = $row["BaseDatos"]
    $NumReg = [int]$row["NumReg"]
    $CodUser = $row["CodUser"]

    $sql56Fin = @"
UPDATE ProyFidens.dbo.ADM_ACTIVACION_CUENTA
SET ESTADO = 3
WHERE AAC_IDENAAC = $NumReg AND ESTADO IN (2,3);

SELECT * FROM ProyFidens.dbo.ADM_ACTIVACION_CUENTA WHERE AAC_IDENAAC = $NumReg;
"@  

    if ($NumReg -ne $NumRegDup) {
      $sqlCorreoSend = @"
EXEC [ProyFidens].[dbo].[SYS_ADM_EMAIL_SOLICITUD_ACCESO_PRODUCCION] '$CodUser', $NumReg;
"@
      Write-Host $sqlCorreoSend 
      Invoke-Sqlcmd -Query $sqlCorreoSend -ConnectionString $Connect56
      $NumRegDup = $NumReg
    }

    # Write-Host $sql56Fin 
    $finaliza56 = Invoke-Sqlcmd -Query $sql56Fin -ConnectionString $Connect56
    if (-not $finaliza56 -or $finaliza56.Count -eq 0) {
      Write-Host "No se pudo finalizar en Fidens para NumReg $NumReg"
    }
    else {
      $sql49Fin = @"
UPDATE dbo.infraAccesosAzure
SET Estado = 'REVOCADO',Revocado = GetDate()
WHERE IdAzure = $IdAzure;
SELECT * FROM dbo.infraAccesosAzure WHERE IdAzure = $IdAzure;
"@
      # Write-Host $sql49Fin
      $finaliza49 = Invoke-Sqlcmd -Query $sql49Fin -ConnectionString $Connect49
      if (-not $finaliza49 -or $finaliza49.Count -eq 0 -or $Permiso -eq "") {
        Write-Host "No se pudo finalizar en 49 para NumReg $NumReg"
      }
      else {
        # Revocar el permiso en Azure
        & "./sqlAzRemove" -Servidor $ServAzure -BaseDato $BaseDatos -Usr $Usuario -TipoAcceso $Permiso
      }
    }
  }

  # Cerrar barra de progreso
  Write-Progress -Activity "Revocatoria masiva Azure SQL-GINGER" -Completed -Status "Completado"
}
$finProc = Get-Date
$duracionProc = ($finProc - $inicioProc).ToString("hh\:mm\:ss")
Write-Host "Duracion del proceso $duracionProc" -ForegroundColor DarkYellow

<#
  Verificar si la tarea sigue corriendo
  Get-ScheduledTask -TaskName "Revocatoria Masiva de Permisos SQL Azure" | Get-ScheduledTaskInfo

  Buscar el proceso PS
  Get-Process powershell* | Select Id, StartTime

  Si coincide la hora matarlo
  Stop-Process -Id <ID> -Force
  
  Revisa duracion real del script
  (Get-Date) - (Get-ScheduledTaskInfo -TaskPath "\Infraestructura\" -TaskName "Revocatoria Masiva de Permisos SQL Azure").LastRunTime

  Obtener la configuracion de la tarea programada
  $task = Get-ScheduledTask -TaskPath "\Infraestructura\" -TaskName "Revocatoria Masiva de Permisos SQL Azure"
  Export-ScheduledTask -TaskPath "\Infraestructura\" -TaskName "Revocatoria Masiva de Permisos SQL Azure" | Out-File "C:\Temp\sqlAzureTareaRevocatoria.xml"

  Posiblemente sea necesario agregar al inicio del script lo siguiente
  $mutex = New-Object System.Threading.Mutex($false, "Revocatoria_Masiva_Permisos_SQL_Azure_Mutex", [ref]$created)
  if (-not $created) {
    Write-Output "Ya existe otra ejecución. Saliendo..."
    exit
  } 
#>