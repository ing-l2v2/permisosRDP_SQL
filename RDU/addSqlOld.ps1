param(
    [string]$Serv,
    [string]$Usr,
    [ValidateSet("R","W","RW","SP","SM","RWSP","RWSM","JOB","SYS","PRF")]
    [string]$TipoAcceso,
    [string]$BaseDato,
    [string]$DuracionHoras,
    [string]$Expira
)

$TipoAcceso = $TipoAcceso.ToUpper()
$servSql = "10.0.0.49"
$servSqlFidens = "10.0.0.102"
$accesoSql = "10.0.0.$Serv"
$BdRepo = "master"
$UsrSql = "lvilla"
$Pass49 = "L2v2..20&25.#"
$PassFidens = "lv..2021"
switch ($Serv) {
	{$_ -in "49","56"} { $Pass = "L2v2..20&25.#" }
	{$_ -in "61","77","80","86","102"} { $Pass = "lv..2021" }
	{$_ -in "15","36","40","48","54","60","84","87","101","186","198","203"} { $Pass = "lv..2021" }
}

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

# ==================================================================
# INFO
# ==================================================================
Write-Host "----------------------------------------------------------------"
Write-Host "Usuario a gestionar: $Usr	                     Servidor: $Serv" -ForegroundColor Cyan
Write-Host "Tipo de acceso: $TipoAcceso                      BaseDato: $BaseDato" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------"

Import-Module SqlServer



#$ConnMain = "Server=$servSql; Database=$BdRepo; User ID=$UsrSql; Password=$Pass49; TrustServerCertificate=True;"
$ConnAcceso = "Server=$accesoSql; Database=$BdRepo; User ID=$UsrSql; Password=$Pass; TrustServerCertificate=True;"
$ConnProyFidens = "Server=$servSqlFidens; Database=$BdRepo; User ID=$UsrSql; Password=$PassFidens; TrustServerCertificate=True;"

	# Param BDatosFid
	if ([string]::IsNullOrWhiteSpace($BaseDato) -or $BaseDato -eq "NULL" -or $BaseDato -eq $null) {
	    $paramBDFid = $null
	} else {
	    $paramBDFid = $BaseDato
	}
	# Normalizar paramBDFid a INT o NULL
	if ([string]::IsNullOrWhiteSpace($paramBDFid)) {
	    $paramBDFidSql = "NULL"
	}
	elseif ($paramBDFid -as [int]) {
	    $paramBDFidSql = [int]$paramBDFid
	}
	else {
	    throw "El parámetro paramBDFid ('$paramBDFid') no es un número válido."
	}
	Write-Host "[SQL-addSql] Procediendo en 102 Usr: $Usr, accesoSql: $accesoSql, paramBDFid: $paramBDFid :: rdu_infraProyFidensSolicitadosRDU"
$QuerySqlFidens = @"
EXEC dbo.rdu_infraProyFidensSolicitadosRDU
	'$Usr',
	'$accesoSql',
	'SQL',
	$paramBDFid;
"@
	$solicitados = Invoke-Sqlcmd -Query $QuerySqlFidens -ConnectionString $ConnProyFidens
	if (-not $solicitados) {
	    Write-Host "No hay referencias en ProyFidens 102." -ForegroundColor Yellow
            $fechaFin = "NULL"
	    $NumReg = "NULL"
	} else {
	    Write-Host "Hay referencias ubicadas en ProyFidens 102." -ForegroundColor Yellow
    	    $fechaFin = $solicitados.fechaFin
            $NumReg     = $solicitados.NumReg
	    # ---- Normalizar fechaFin ----
	    if ($null -eq $fechaFin -or $fechaFin -eq "" ) {
	        $fechaFinSql = "NULL"
	    }
	    else {
	        # Convertir a formato compatible SQL
	        # $fechaFinSql = "'" + $fechaFin.ToString("yyyy-MM-dd HH:mm:ss") + "'"
		if ($fechaFin -is [DateTime]) {
		    # Fecha válida
		    $fechaFinSql = "'" + $fechaFin.ToString("yyyy-MM-dd HH:mm:ss") + "'"
		}
		elseif ($null -eq $fechaFin -or $fechaFin -eq "" -or $fechaFin -is [System.DBNull]) {
		    # No tiene fecha
		    $fechaFinSql = "NULL"
		}
		else {
		    # Intentar parsear si viene como string
		    try {
		        $fechaParseada = [DateTime]::Parse($fechaFin)
		        $fechaFinSql = "'" + $fechaParseada.ToString("yyyy-MM-dd HH:mm:ss") + "'"
		    }
		    catch {
		        Write-Host "WARN: fechaFin no pudo convertirse → $fechaFin" -ForegroundColor Yellow
		        $fechaFinSql = "NULL"
		    }
		}
	    }
	    # ---- Normalizar NumReg ----
		# ---- Normalizar NumReg ----
		if ($NumReg -is [System.DBNull] -or $NumReg -eq $null -or $NumReg -eq "") {
		    $NumRegSql = "NULL"
		}
		elseif ($NumReg -as [int]) {
		    $NumRegSql = [int]$NumReg
		}
		else {
		    Write-Host "WARN: NumReg no válido → '$NumReg' (se enviará como NULL)" -ForegroundColor Yellow
		    $NumRegSql = "NULL"
		}
<#
	    if ($null -eq $NumReg -or $NumReg -eq "") {
	        $NumRegSql = "NULL"
	    }
	    elseif ($NumReg -as [int]) {
	        $NumRegSql = [int]$NumReg
	    }
	    else {
	        throw "NumReg devuelto por SQL no es un entero válido: $NumReg"
	    }
#>
            Write-Host "fechaFin: $fechaFinSql"
            Write-Host "NumReg: $NumRegSql"
	}

	# Param BDatos
	if ([string]::IsNullOrWhiteSpace($BaseDato) -or $BaseDato -eq "NULL" -or $BaseDato -eq $null) {
	    $paramBD = "NULL"
	} else {
	    $paramBD = $BaseDato
	}
	# Param Expira
	if ($fechaFinSql -eq $null -or $fechaFinSql -eq "NULL") {
		Write-Host "paramExp determinado por fechaFin en NULL y depende de Expira"
		if ($Expira -eq $null -or $Expira -eq "NULL" -or $Expira -eq "") {
		    $paramExp = "NULL"
		} else {
		    $paramExp = $Expira
		}
	} else {
		Write-Host "paramExp determinado por fechaFin"
		$paramExp = $fechaFinSql
	}
	Write-Host "[SQL-addSql] Procediendo en 49 Usr: $Usr, TipoAcceso: $TipoAcceso, paramBD: $paramBD, DuracionHoras: $DuracionHoras, paramExp: $paramExp, NumReg: $NumReg :: sp_infra_ini_asignar_permiso_temporal"
	$query = @"
EXEC sp_infra_ini_asignar_permiso_temporal 
    '$Usr',
    '$TipoAcceso',
    $paramBD,
    $DuracionHoras,
    $paramExp, 
    $NumReg;
"@
		# Registrar asignación de permiso
		$result = Invoke-Sqlcmd -Query $query -ConnectionString $ConnAcceso

		if ($result.IdPermiso -lt 0) {
		    Write-Host "Error SQL: $($result.ErrorMsg)" -ForegroundColor Red
		    exit 1
		} else {
		    Write-Host "Permiso asignado. ID = $($result.IdPermiso)" -ForegroundColor Green
		    Write-Host "[SQL-addSql] Procediendo en 102 NumReg: $NumReg, Estado: 2 :: rdu_infraProyectoFidensRegistrarEstado"
		    $queryProyFidens = @"
EXEC rdu_infraProyectoFidensRegistrarEstado
	$NumReg,
	2;
"@
	try {
	    Invoke-Sqlcmd -Query $queryProyFidens -ConnectionString $ConnProyFidens -ErrorAction Stop
	} catch {
	    Write-Host "Advertencia: No se pudo registrar en ProyFidens" -ForegroundColor Yellow
	    Write-ServerLog -Server $Server -Message "Advertencia: No se registró ProyFidens"
	}
}
