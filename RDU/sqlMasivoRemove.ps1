. "$PSScriptRoot\SyncCreds.ps1"
if (-not (Test-Connection -ComputerName 10.0.0.49 -Count 1 -Quiet)) {
    Write-Output "VPN no activa. Saliendo..."
    exit
}

$BdRepo = "master"
$UsrSql = "lvilla"
$PassFidens = "lv..2021"
$servSqlFidens = "10.0.0.102"
$Serv = "10.0.0."
$Origenes = @(
    [pscustomobject]@{ Servidor = 49; Pass = "L2v2..20&25.#" },
    [pscustomobject]@{ Servidor = 56; Pass = "L2v2..20&25.#" },
    [pscustomobject]@{ Servidor = 61; Pass = "lv..2021" },
    [pscustomobject]@{ Servidor = 80; Pass = "lv..2021" },
    [pscustomobject]@{ Servidor = 86; Pass = "lv..2021" },
    [pscustomobject]@{ Servidor = 102; Pass = "lv..2021" }
)

$ServidoresLista = $Origenes | ForEach-Object { "10.0.0.$($_.Servidor)" }
. "$PSScriptRoot\ServidoresCredenciales.ps1"
foreach ($cmdServ in $servidoresLista) {    
    $accCreds = $Global:ServidoresCredenciales[$cmdServ]
    $accUsr = $accCreds.User
    $accPass = $accCreds.Password
    Write-Host "Validando $cmdServ..."
    Start-Process cmdkey -ArgumentList "/add:$cmdServ", "/user:$accUsr", "/pass:$accPass" -NoNewWindow -Wait
}

#Sync-RemoteCredencialGrupo -Servidores $ServidoresLista

# ==================================================================
# LOGGING
# ==================================================================
$LogDir = ".\logs"
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
function Write-ServerLog {
    param(
        [string]$Server,
        [string]$Message
    )
    $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $line = "$timestamp | $Message"
    $path = "$LogDir\$Server.log"
    $maxRetry = 5
    $delay = 300  # ms
    for ($i = 1; $i -le $maxRetry; $i++) {
        try {
            Add-Content -Path $path -Value $line -ErrorAction Stop
            return
        }
        catch {
            if ($i -eq $maxRetry) {
                Write-Host "[$Server] ERROR: No se pudo escribir en el log después de $maxRetry intentos" -ForegroundColor Red
                return
            }
            Start-Sleep -Milliseconds $delay
        }
    }
}

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
    $linea = "$timestamp sqlMasivoRemove $Mensaje"
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
$ConnProyFidens = "Server=$servSqlFidens; Database=$BdRepo; User ID=$UsrSql; Password=$PassFidens; TrustServerCertificate=True;"

# ================================
# PROGRESO + TIEMPO ESTIMADO
# ================================
$total = $Origenes.count
$startTime = Get-Date
$index = 0
foreach ($r in $Origenes) {

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
        -Activity "Revocatoria masiva SQL Local" `
        -Status "Progreso: $percent% | ETA: $etaText | Base: $db " `
        -PercentComplete $percent


    $accesoSql = "$Serv$($r.Servidor)"    
    Write-Host "Servidor: $accesoSql"
    $ConnAcceso = "Server=$accesoSql; Database=$BdRepo; User ID=$UsrSql; Password=$($r.Pass); TrustServerCertificate=True;"
    # Write-Host "[$servSqlFidens sqlMasivoRemove] QUERY SQL EJECUTADO rdu_infraProyectoFidensRegistrarEstado" -Foreground Yellow
    #Write-Host "[$ConnAcceso] EXEC sp_infra_list_revocados_sql"
    
    $revocados = Invoke-Sqlcmd -Query "EXEC sp_infra_list_revocados_sql" -ConnectionString $ConnAcceso

    if (-not $revocados) {
        Write-Host "`nNo existen accesos expirados para revocar.`n" -ForegroundColor Cyan
        continue
    }
    else {
        foreach ($fila in $revocados) {
            $IdPermiso = [int]$fila["IdPermiso"]
            $PermisoAsignado = $fila["PermisoAsignado"]
            $NumReg = ConvertirToValorSql($fila["NumReg"])
            $Estado = ConvertirToValorSql($fila["Estado"])
            $Usuario = ConvertirToValorSql($fila["Usuario"])
            $CodUser = ConvertirToValorSql($fila["CodUser"])
            $BD = ConvertirToValorSql($fila["BaseDatos"])
            # ==================================================================
            # INFO
            # ==================================================================
            Write-Host "Usuario a gestionar: $Usuario    Servidor: $accesoSql    Base: $BD    NumReg: $NumReg    CodUser: $CodUser" -ForegroundColor Cyan
            Write-Host "Accion: REMOVE SQL" -ForegroundColor Cyan
            Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan

            # Write-Host "DEBUG Valor real CodUser: $($fila["CodUser"]) Tipo: $($fila["CodUser"].GetType().FullName)"

            try {
                # Write-Host "[$accesoSql] Revocando $Usuario en grupo SQL"
                #if ($NumReg -eq $null -or $NumReg -eq "" -or $NumReg -eq "NULL" -or $NumReg -is [System.DBNull] -or  $CodUser -eq $null -or $CodUser -eq "" -or $CodUser -eq "NULL" -or $CodUser -is [System.DBNull] ) {
                if ($NumReg -is [System.DBNull] -or $null -eq $NumReg -or $NumReg -eq "" -or $NumReg -eq "NULL") {
                    Write-Host "[$servSqlFidens sqlMasivoRemove] No se Asigno estado EJECUTADO por NumReg $NumReg.GetType().name " -ForegroundColor Red
                }
                else {
                    # Write-Host "[$servSqlFidens sqlMasivoRemove] Asignando estado EJECUTADO en NumReg $NumReg " -ForegroundColor Green
	    
                    $SqlFidens = @"
EXEC dbo.rdu_infraProyectoFidensRegistrarEstado
     @NumReg = $NumReg,
     @Estado = $Estado,
     @CodUser = $CodUser,
     @FechaFin = NULL;
"@	    
                    # Write-Host "[$servSqlFidens sqlMasivoRemove] QUERY SQL EJECUTADO rdu_infraProyectoFidensRegistrarEstado" -Foreground Yellow
                    Write-Host $SqlFidens

                    try {
                        $proyFidens = Invoke-Sqlcmd -ConnectionString $ConnProyFidens -Query $SqlFidens
                        # Write-Host "[$servSqlFidens sql-remove-proy-fidens] SP ejecutado" -ForegroundColor Cyan
                        # Write-ServerLog -Server $servSqlFidens -Message "[$servSqlFidens sql-remove-proy-fidens] SP ejecutado"
                        if (-not $proyFidens) {
                            Write-Host "No hay referencias para actualizar ESTADO $Estado en ProyFidens 102." -ForegroundColor Yellow
                        }
                        else {
                            $NumRegPry = ConvertirToValorSql($proyFidens["NumReg"])
                            $EstadoPry = ConvertirToValorSql($proyFidens["Estado"])
                            $FFIN = ConvertirToValorSql($proyFidens["FFIN"])
                            $HFIN = ConvertirToValorSql($proyFidens["HFIN"])
                            Write-Host "`n---------------------------------------------------------------------------------" -ForegroundColor Yellow
                            Write-Host "Registro ProyFidens:: Usuario: $Usuario    Servidor: $accesoSql    Base: $BD    NumReg: $NumRegPry    CodUser: $CodUser    Estado: $EstadoPry    FechaFin: $FFIN    HFIN: $HFIN" -ForegroundColor Yellow
                            Write-Host "---------------------------------------------------------------------------------`n" -ForegroundColor Yellow
                            Write-AzureLog "[$IdPermiso] .\sqlRemove -Serv `"$accesoSql`" -Usr `"$Usuario`" -TipoAcceso `"$PermisoAsignado`" -BaseDato `"$BD`" "
                        }
                    }
                    catch {
                        $sqlError = $_.Exception.Message
                        Write-Host "[$servSqlFidens sql-remove-proy-fidens] ERROR ejecutando SP rdu_infraProyectoFidensRegistrarEstado: $sqlError" -ForegroundColor Magenta
                        Write-ServerLog -Server $servSqlFidens -Message "[$servSqlFidens] sql-remove-proy-fidens] ERROR ejecutando SP rdu_infraProyectoFidensRegistrarEstado: $sqlError"
                    }
                }
            }
            catch {
                $err = $_.Exception.Message
                Write-Host "[$servSqlFidens] ERROR: $err" -ForegroundColor Red
                Write-ServerLog -Server $servSqlFidens -Message "[$servSqlFidens sql-remove-proy-fidens] ERROR: $err"
            }
        }
    }
}

# Cerrar barra de progreso
Write-Progress -Activity "Revocatoria masiva SQL Local" -Completed -Status "Completado"
<#
  Verificar si la tarea sigue corriendo
  Get-ScheduledTask -TaskName "SQL-Revocacion-ProyFidens" | Get-ScheduledTaskInfo

  Buscar el proceso PS
  Get-Process powershell* | Select Id, StartTime

  Si coincide la hora matarlo
  Stop-Process -Id <ID> -Force
  
  Revisa duracion real del script
  (Get-Date) - (Get-ScheduledTaskInfo -TaskPath "\Infraestructura\" -TaskName "SQL-Revocacion-ProyFidens").LastRunTime

  Obtener la configuracion de la tarea programada
  $task = Get-ScheduledTask -TaskPath "\Infraestructura\" -TaskName "SQL-Revocacion-ProyFidens"
  Export-ScheduledTask -TaskPath "\Infraestructura\" -TaskName "SQL-Revocacion-ProyFidens" | Out-File "C:\Temp\sqlTareaRevocatoria.xml"

  Posiblemente sea necesario agregar al inicio del script lo siguiente
  $mutex = New-Object System.Threading.Mutex($false, "SQL_Revocacion_ProyFidens_Mutex", [ref]$created)
  if (-not $created) {
    Write-Output "Ya existe otra ejecución. Saliendo..."
    exit
  }
#>