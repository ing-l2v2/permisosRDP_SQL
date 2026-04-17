if (-not (Test-Connection -ComputerName 10.0.0.49 -Count 1 -Quiet)) {
	Write-Output "VPN no activa. Saliendo..."
	exit
}

$ServidorSql = "10.0.0.49"
$Db = "master"
$UsrDb = "lvilla"
$Pass = "L2v2..20&25.#"
$ConCentral = "Server=$ServidorSql;Database=$Db;User ID=$UsrDb;Password=$Pass;TrustServerCertificate=True";

$inicioProc = Get-Date

# ==========================================================
# CONFIGURACION LOG
# ==========================================================
$LogDirSqlAdd = ".\reportes\accesosGestionados"
$LogFileSqlAdd = "$LogDirSqlAdd\accesosREVOCADOS.txt"
if (!(Test-Path $LogDirSqlAdd)) {
	New-Item -ItemType Directory -Path $LogDirSqlAdd -Force | Out-Null
}
function Write-AzureLog {
	param(
		[string]$Mensaje
	)
	$timestamp = (Get-Date -Format "yyyyMMdd HH:mm:ss")
	$linea = "$timestamp $Mensaje"
	$maxRetry = 6
	$delay = 250
	for ($i = 1; $i -le $maxRetry; $i++) {
		try {
			if (!(Test-Path $LogFileSqlAdd)) {
				Set-Content -Path $LogFileSqlAdd -Value $linea
				return
			}
			# leer contenido actual
			$contenido = Get-Content $LogFileSqlAdd -ErrorAction Stop
			# insertar arriba
			$nuevo = @($linea) + $contenido
			# escribir nuevamente
			Set-Content -Path $LogFileSqlAdd -Value $nuevo -ErrorAction Stop
			return
		}
		catch {
			if ($i -eq $maxRetry) {
				Write-Host "ERROR: No se pudo escribir en el log después de $maxRetry intentos." -ForegroundColor Red
				return
			}
			Start-Sleep -Milliseconds $delay
		}
	}
}


$servidoresVerificados = ( @() + $servidorSql) | Sort-Object -Unique
. "$PSScriptRoot\ServidoresCredenciales.ps1"
foreach ($cmdServ in $servidoresVerificados) {    
	$accCreds = $Global:ServidoresCredenciales[$cmdServ]
	$accUsr = $accCreds.User
	$accPass = $accCreds.Password
	Write-Host "Validando $cmdServ..."
	# Start-Process cmdkey -ArgumentList "/add:$cmdServ", "/user:$accUsr", "/pass:$accPass" -NoNewWindow -Wait
	Start-Process cmdkey -ArgumentList "/add:$cmdServ", "/user:$accUsr", "/pass:$accPass" -NoNewWindow -Wait -RedirectStandardOutput "NUL"
}


# ==================================================================
# 		CONVERSION A VALOR SQL
# ==================================================================
function ConvertirToValorSql {
	param(
		[Parameter(Mandatory = $false)]
		$Value
	)
	# 		    NULL o vacío
	# ------------------------------------------
	if ($Value -is [System.DBNull] -or $null -eq $Value -or $Value -eq "") { return "NULL" }    
	#   BOOL / BIT;    # true → 1    # false → 0
	# ------------------------------------------
	if ($Value -is [bool]) { return ($(if ($Value) { 1 }else { 0 })) }
	# 			INT
	# ------------------------------------------
	if ($Value -is [int] -or $Value -is [long]) { return $Value }
	# 		DECIMAL / FLOAT / NUMÉRICOS
	# ------------------------------------------
	if ($Value -is [double] -or $Value -is [float] -or $Value -is [decimal]) {
		return $Value.ToString().Replace(",", ".")  # SQL exige punto
	}
	# 			DATETIME
	# ------------------------------------------    
	if ($Value -is [datetime]) {
		return "'" + $Value.ToString("yyyy-MM-dd HH:mm") + "'"
	}
	# 	STRING — verificar si representa fecha
	#   STRINGS (incluye PSObject → str real)
	# ------------------------------------------
	if ($Value -is [string] -or $Value -is [System.Management.Automation.PSObject]) {
		$str = [string]$Value.trim()        
		# si la cadena está vacía → no es fecha
		if ([string]::IsNullOrWhiteSpace($str)) {
			return "NULL"
		}
		# Write-Host "DEBUG VALUE TYPE = $($str.GetType().FullName)"
		# Write-Host "DEBUG VALUE RAW  = '$str'"
		try {
			<#
            if ([datetime]::TryParse($str, [ref]$parsedDate)) {
                return "'" + $parsedDate.ToString("yyyy-MM-dd HH:mm") + "'"
            }
            #>
			$parsed = [datetime]::Parse($str)
			return "'" + $parsed.ToString("yyyy-MM-dd HH:mm") + "'"
		}
		catch {
			# no es fecha → tratar como texto
			return "'" + $str.Replace("'", "''") + "'"        
		}
		# No es fecha → tratar como texto
		return "'" + $Value.ToString.Replace("'", "''") + "'"
	}
	# Último recurso (otros tipos)
	# ------------------------------------------
	return "'" + $Value.ToString().Replace("'", "''") + "'"
	#return $Value.ToString()
}

Import-Module SqlServer

# 1. Obtener accesos expirados desde 10.0.0.49
$expirados = Invoke-Sqlcmd -Query "EXEC rdu_infraObtenerAccesosExpiradosRDU" -ConnectionString $ConCentral

if (-not $expirados) {
	Write-Host "No existen accesos expirados para revocar." -ForegroundColor Blue
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
			-Activity "Revocando masivamente accesos RDP" `
			-Status "Progreso: $percent% | ETA: $etaText | Base: $row " `
			-PercentComplete $percent


		$id = ConvertirToValorSql($row["id"])
		$usr = ConvertirToValorSql($row["Usuario"])
		$srv = ConvertirToValorSql($row["Servidor"])
		$grp = ConvertirToValorSql($row["Grupo"])
		
		try {
			# ==================================================================
			# INFO
			# ==================================================================
			Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
			Write-Host "Revocado masivo RDP  [$id]   Servidor: $srv    Usuario: $usr    Grupo: $grp" -ForegroundColor Cyan
			Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
			$usrClean = $usr.Trim().Trim("'").ToUpper()
			$srvClean = $srv.Trim().Trim("'").ToUpper()
			$grpClean = $grp.Trim().Trim("'").ToUpper()
			switch ($grpClean) {
				"ADMINISTRATORS" { $Grupo = "ADM" }
				"REMOTE DESKTOP USERS" { $Grupo = "RDU" }
				Default {
					throw "Grupo desconocido: $grp - $Grupo"
				}
			}
	
			& "./rdpRemove" -Servidores $srvClean -Usuario $usrClean -GrupoIn $Grupo
			#Write-AzureLog "./rdpRemove -Servidores $srvClean -Usuario $usrClean -GrupoIn $Grupo"
			
			# Log-SqlRevocacion -Id $id -Mensaje $null
			# Write-Host "Revocado OK" -ForegroundColor Green
		}
		catch {
			$msg = $_.Exception.Message.Replace("'", "")
			# Log-SqlRevocacion -Id $id -Mensaje $msg
			Write-Host "ERROR: $msg" -ForegroundColor Red
		}
	}

	# Cerrar barra de progreso
	Write-Progress -Activity "Revocando masivamente accesos RDP" -Completed -Status "Completado"
}

$finProc = Get-Date
$duracionProc = ($finProc - $inicioProc).ToString("hh\:mm\:ss")

Write-Host("Duración Proceso $duracionProc")

<#
	Verificar si la tarea sigue corriendo
  Get-ScheduledTask -TaskName "RDU-RevocacionAutomatica" | Get-ScheduledTaskInfo

	Buscar el proceso PS
  Get-Process powershell* | Select Id, StartTime

  Si coincide la hora matarlo
  Stop-Process -Id <ID> -Force
  
  Revisa duracion real del script  
	(Get-Date) - (Get-ScheduledTaskInfo -TaskPath "\Infraestructura\" -TaskName "RDU-RevocacionAutomatica").LastRunTime

	Obtener la configuracion de la tarea programada
  $task = Get-ScheduledTask -TaskPath "\Infraestructura\" -TaskName "RDU-RevocacionAutomatica"
  Export-ScheduledTask -TaskPath "\Infraestructura\" -TaskName "RDU-RevocacionAutomatica" | Out-File "C:\Temp\rdpTareaRevocatoria.xml"

	Posiblemente sea necesario agregar al inicio del script lo siguiente
	$mutex = New-Object System.Threading.Mutex($false, "RDU_Revocacion_Mutex", [ref]$created)
	if (-not $created) {
		Write-Output "Ya existe otra ejecución. Saliendo..."
		exit
	}
#>
