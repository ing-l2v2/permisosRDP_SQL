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
                    Write-Host "[$Server] ERROR: No se pudo escribir en el log despu�s de $maxRetry intentos" -ForegroundColor Red
                    return
                }
                Start-Sleep -Milliseconds $delay
            }
        }
    }
)
Import-Module SqlServer
$ConnProyFidens = "Server=$servSqlFidens; Database=$BdRepo; User ID=$UsrSql; Password=$PassFidens; TrustServerCertificate=True;"

foreach ($r in $Origenes) {
    $accesoSql = "$Serv$($r.Servidor)"
    Write-Host "================================================================" -foregroundColor Yellow
    Write-Host "Servidor: $accesoSql"  -foregroundColor Yellow
    Write-Host "================================================================" -foregroundColor Yellow
    $ConnAcceso = "Server=$accesoSql; Database=$BdRepo; User ID=$UsrSql; Password=$($r.Pass); TrustServerCertificate=True;"
    
    Write-Host "[$accesoSql sqlMasivoRemove] QUERY SQL EJECUTADO sp_infra_list_revocados_sql" -Foreground Yellow
    
    $revocados = Invoke-Sqlcmd -Query "EXEC sp_infra_list_revocados_sql" -ConnectionString $ConnAcceso

    if (-not $revocados) {
        Write-Host "[$accesoSql] No existen accesos expirados para revocar." -ForegroundColor Yellow
        continue
    }
    foreach ($fila in $revocados) {
        $NumReg = $fila.NumReg
        $Estado = $fila.Estado
        $Usuario = $fila.Usuario
        $HoraHigh = $fila.HoraHigh
        $Procesado = $fila.Procesado
        $CodUser = $fila["CodUser"]
        if ($CodUser -eq $null -or $CodUser -eq "" -or $CodUser -eq "NULL" -or $CodUser -is [System.DBNull]) {
            $Coduser = "NULL"
            Write-Host "CodUser detectado NULL" -foregroundColor Yellow
        }
        elseif ($CodUser -is [string]) {
            $CodUser = "'$fila.CodUser'"
            Write-Host "CodUser detectado $CodUser" -foregroundColor Yellow
        }
        else {
            Write-Host "[$servSqlFidens sqlMasivoRemove] Revisar tipo de dato de CodUser $($CodUser.GetType().name) "  -ForegroundColor Yellow 
        }
        Write-Host "DEBUG Valor real CodUser: $($fila["CodUser"]) Tipo: $($fila["CodUser"].GetType().FullName)"
        <#
	$CodUser = if (
	    $CodUser -eq $null -or
	    $CodUser -eq "" -or
	    $CodUser -is [System.DBNull]
	) { "NULL" } else { "'$fila.CodUser'" }
#>
        try {
            Write-Host "[$accesoSql] Revocando $Usuario en grupo SQL" -foregroundColor -Cyan
            #if ($NumReg -eq $null -or $NumReg -eq "" -or $NumReg -eq "NULL" -or $NumReg -is [System.DBNull] -or  $Cod_User -eq $null -or $Cod_User -eq "" -or $CodUser -eq "NULL" -or $CodUser -is [System.DBNull] ) {
            if ($null -eq $NumReg -or $NumReg -eq "" -or $NumReg -eq "NULL" -or $NumReg -is [System.DBNull] ) {
                Write-Host "[$servSqlFidens sqlRemoveProyFidens] No se Asigno estado EJECUTADO por NumReg $NumReg.GetType().name " -ForegroundColor Magenta
            }
            else {
                Write-Host "[$servSqlFidens sqlRemoveProyFidens] Asignando estado EJECUTADO en NumReg $NumReg " -ForegroundColor Green
	    
                $SqlFidens = @"
EXEC dbo.rdu_infraProyectoFidensRegistrarEstado
     @NumReg = $NumReg,
     @Estado = $Estado,
     @CodUser = $CodUser;
"@	    
                # Write-Host "[$servProyFidens sqlMasivoRemove] QUERY SQL EJECUTADO rdu_infraProyectoFidensRegistrarEstado" -Foreground Yellow
                Write-Host $SqlFidens

                try {
                    $removidosPermisos = Invoke-Sqlcmd -ConnectionString $ConnProyFidens -Query $SqlFidens
                    Write-Host "[$servSqlFidens sql-remove-proy-fidens] SP ejecutado" -ForegroundColor Cyan
                    Write-ServerLog -Server $servSqlFidens -Message "[$servSqlFidens sql-remove-proy-fidens] SP ejecutado"
                    if (-not $removidosPermisos) {
                        Write-Host "No hay referencias para actualizar ESTADO $Estado en ProyFidens." -ForegroundColor Yellow
                        $NumRegFidens = "NULL"
                    }
                    else {
                        $NumRegFidens = if ($removidosPermisos.NumReg) { $removidosPermisos.NumReg }     else { "NULL" }
                        Write-Host "ProyFidens actualizado Estado. NumRegFidens: $NumRegFidens" -ForegroundColor Yellow
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