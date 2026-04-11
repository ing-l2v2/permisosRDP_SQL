<#
.SYNOPSIS
    Remueve un usuario de los grupos Administrators o Remote Desktop Users
    usando WinRM + CIM, con soporte para logs por servidor.
.PARAMETER Servidores
    Lista de servidores separados por coma o archivo de texto.
.PARAMETER Usuario
    Usuario a agregar o remover en formato dominio\usuario, .\usuario o equipo\usuario
.PARAMETER GrupoIn
    ADM (Administrators) | RDU ("Remote Desktop Users")
.DESCRIPTION
    Cambia dinámicamente entre:
        - Add-LocalGroupMember / Remove-LocalGroupMember (2016+)
        - net localgroup (2008/2012)

    Normaliza usuarios antes de enviarlos al servidor remoto.
.EXAMPLE
    .\GestionGrupos01.ps1 -Servidores servers.txt -Usuario ".\jlopez" -Accion add -Grupo Administrators
    .\GestionGrupos01.ps1 -Servidores "SRV-AUTOCLUB-UA,SRV-PR-BOL-01" -Usuario "FIDENSLAT\jtoledo" -Accion add -Grupo "Remote Desktop Users"
    Archivo servers.txt de ejemplo
    SRV-AUTOCLUB-UA
    SRV-PR-BOL-01
    10.0.0.53

Ejecutar Enable-PSRemoting -Force con powershell como administrator
Agregando credenciales al pc local
cmdkey /add:10.0.0.15 /user:lvilla /pass:lv..2021
cmdkey /add:10.0.0.86 /user:lvilla /pass:lv..2021
cmdkey /add:10.0.0.101 /user:lvilla /pass:lv..2021
cmdkey /add:10.0.0.102 /user:lvilla /pass:lv..2021
cmdkey /add:10.0.0.103 /user:lvilla /pass:lv..2021
cmdkey /add:10.0.0.80 /user:lvilla /pass:lv..2021
cmdkey /add:10.0.0.49 /user:FIDENSLAT\leonel.villa /pass:lv..2021
cmdkey /add:10.0.0.48 /user:FIDENSLAT\leonel.villa /pass:lv..2021
cmdkey /add:10.0.0.203 /user:FIDENSLAT\leonel.villa /pass:lv..2021
cmdkey /add:10.0.0.84 /user:FIDENSLAT\leonel.villa /pass:lv..2021
cmdkey /add:10.0.0.36 /user:FIDENSLAT\leonel.villa /pass:lv..2021
cmdkey /add:10.0.0.198 /user:FIDENSLAT\leonel.villa /pass:lv..2021
cmdkey /add:10.0.0.61 /user:FIDENSLAT\leonel.villa /pass:lv..2021
cmdkey /add:10.0.0.87 /user:FIDENSLAT\leonel.villa /pass:lv..2021
cmdkey /add:10.0.0.77 /user:FIDENSLAT\leonel.villa /pass:lv..2021
cmdkey /add:10.0.0.54 /user:FIDENSLAT\leonel.villa /pass:lv..2021
cmdkey /add:10.0.0.59 /user:FIDENSLAT\leonel.villa /pass:lv..2021
cmdkey /add:10.0.0.56 /user:FIDENSLAT\leonel.villa /pass:lv..2021
cmdkey /add:10.0.0.201 /user:FIDENSLAT\leonel.villa /pass:lv..2021

.\rdpRemove.ps1 -Servidores "10.0.0.49" -Usuario ".\FIDENSLAT\jtoledo" -GrupoIn RDU
.\rdpRemove.ps1 "10.0.0.49" ".\FIDENSLAT\jtoledo" ADM
.\drp_remove.ps1 -Servidores "10.0.0.77" -Usuario ".\FIDENSLAT\jtoledo" -GrupoIn RDU
.\rdpRemove.ps1 "10.0.0.86" ".\jtoledo" ADM
.\rdpRemove.ps1 "10.0.0.86" ".\jtoledo" RDU

$cred = Get-Credential   # ingresar FIDENSLAT\leonel.villa
.\GestionGrupos-WinRM.ps1 -Servidores "10.0.0.49" `
                           -Usuario ".\FIDENSLAT\jtoledo" `
                           -AccionIn R	 remove `
                           -GrupoIn RDU	 "Remote Desktop Users" 	desde aqui no iría `
                           -Credenciales $cred		No iría
$cred = Get-Credential   # ingresar lvilla
 .\GestionGrupos-WinRM.ps1 -Servidores "10.0.0.86" `
                           -Usuario ".\jtoledo" `
                           -Accion A	add `
                           -Grupo ADM	"Administrators" 	desde aqui no iría `
                           -Credenciales $cred		No iría
#>
param(
    [string]$Servidores,
    [string]$Usuario,
    [ValidateSet("ADM", "RDU")]
    [string]$GrupoIn
)
# ================================================================
# TRADUCCIÓN DE PARÁMETROS SIMPLIFICADOS
# ================================================================
switch ($GrupoIn.ToUpper()) {
    "ADM" { $Grupo = "Administrators" }
    "RDU" { $Grupo = "Remote Desktop Users" }
}
$Accion = "remove"    
# ==================================================================
# LOGGING
# ==================================================================
$Root = "E:\infraestructura\rdu"
$LogDir = "$Root\logs"
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
# NORMALIZAR USUARIO PARA SERVIDORES ANTIGUOS
# ==================================================================
function Normalizar-Usuario {
    param([string]$Usuario)
    # Formato ".\usuario"
    if ($Usuario -match "^\.\\(.+)$") {
        return $Matches[1]
    }
    # Formato "IP\usuario" -> solo retornar la parte de usuario
    if ($Usuario -match "^\d{1,3}(\.\d{1,3}){3}\\(.+)$") {
        return $Matches[1]
    }
    # Formato "EQUIPO\usuario"
    if ($Usuario -match "^[A-Za-z0-9_-]+\\(.+)$") {
        $equipo = $Usuario.Split("\")[0]
        if ($equipo -eq $env:COMPUTERNAME) {
            $noequipo = $Usuario.Split("\")[1]
            return $Usuario.Split("\")[1]
        }
    }
    # Usuario de dominio tal cual
    return $Usuario
}

# ==================================================================
# LEER SERVIDORES
# ==================================================================
if (Test-Path $Servidores) {
    $ServerList = Get-Content $Servidores
}
else {
    $ServerList = $Servidores.Split(",") | ForEach-Object { $_.Trim() }
}
# ==================================================================
# INFO
# ==================================================================
Write-Host "Usuario a gestionar: $Usuario" -ForegroundColor Cyan
Write-Host "Accion: REMOVE" -ForegroundColor Cyan
Write-Host "Grupo: $Grupo" -ForegroundColor Cyan
Write-Host "----------------------------------------"

# ==================================================================
# ACCIÓN REMOTA
# ==================================================================
function Gestionar-GrupoRemoto {
    param(
        [string]$Server,
        [string]$Usuario,
        [string]$Accion,
        [string]$Grupo
    )
    Write-Host "`n[$Server] Procesando..." -ForegroundColor Cyan
    Write-ServerLog -Server $Server -Message "Inicio $Accion para $Usuario en $Grupo"
    try {
        # Conectividad
        if (-not (Test-Connection -ComputerName $Server -Count 1 -Quiet)) {
            Write-Host "[$Server] No responde al ping $server" -ForegroundColor Magenta
            Write-ServerLog -Server $Server -Message "No responde al ping"
            return
        }
        # Normalizar usuario ANTES del envío
        # Si viene sin prefijo, asume ".\"
        if ($Usuario -notmatch "\\") {
            $Usuario = ".\" + $Usuario	   
        }
        $UsuarioNorm = Normalizar-Usuario $Usuario
        $UsuarioOriginal = $Usuario

        $ServidorSQL = "10.0.0.49"
        $servSqlFidens = "10.0.0.102"
        $BdRepo = "master"
        $UsrSql = "lvilla"
        $Pass = "L2v2..20&25.#"
        $PassFidens = "lv..2021"
        $Conn = "Server=$ServidorSQL;Database=$BdRepo;User ID=$UsrSql;Password=$Pass;TrustServerCertificate=True;"
        $ConnProyFidens = "Server=$servSqlFidens;Database=$BdRepo;User ID=$UsrSql;Password=$PassFidens;TrustServerCertificate=True;"
        # Código remoto
        $script = {
            param($UsuarioNorm, $Accion, $Grupo)
            function Usuario-En-Grupo {
                try {
                    Get-LocalGroupMember -Group $Grupo | Select-Object -ExpandProperty Name
                    $miembros = Get-LocalGroupMember -Group $Grupo -ErrorAction Stop | Select-Object -ExpandProperty Name
                }
                catch {
                    # $miembros = (cmd /c "net localgroup `"$Grupo`"" | Select-String -Pattern "^\s+\S+").ToString().Trim()	

                    $output = cmd /c "net localgroup `"$Grupo`""

                    <#
Write-Host "===== DEBUG OUTPUT ====="
$output | ForEach-Object { Write-Host "[OUTPUT] $_" }
#>

                    $miembros = ($output | Select-String -Pattern "^[A-Za-z0-9._-]+$") | ForEach-Object {
                        $_.ToString().Trim()
                    }	

                    <#
Write-Host "===== DEBUG MIEMBROS ====="
if ($miembros.Count -eq 0) {
    Write-Host "[MIEMBROS] (vacío)"
} else {
    $miembros | ForEach-Object { Write-Host "[MIEMBRO] $_" }
}
#>

                    if (-not $miembros) { $miembros = @() }  # evitar $null		
                }

                return ($miembros -contains $UsuarioNorm)
            }
            function Remove-U {
                try {
                    if (Get-Command Remove-LocalGroupMember -ErrorAction SilentlyContinue) {
                        Remove-LocalGroupMember -Group $Grupo -Member $UsuarioNorm -ErrorAction Stop
                    }
                    else {
                        cmd /c "net localgroup `"$Grupo`" `"$UsuarioNorm`" /delete" | Out-Null
                    }
                }
                catch {}
            }
            function Remove-UserFromGroup {
                param([string]$Grupo, [string]$UsuarioNorm)
                if (Get-Command Remove-LocalGroupMember -ErrorAction SilentlyContinue) {
                    Remove-LocalGroupMember -Group $Grupo -Member $UsuarioNorm -ErrorAction Stop
                }
                else {
                    $cmd = "net localgroup `"$Grupo`" `"$UsuarioNorm`" /delete"
                    cmd.exe /c $cmd | Out-Null
                }
            }
            # REMOVE previo si ya existe
            if (Usuario-En-Grupo) {
                Remove-U
                Return "REMOVE OK"
            }
            # NO ESTABA — TAMBIÉN ES ÉXITO
            return "REMOVE OK"
        }
		
        $UltimoOcteto = ($Server.Split("."))[-1]
        switch ($UltimoOcteto) {
            { $_ -in "80", "86", "102", "103", "101", "40", "15" } { 
                # Servidores fuera del dominio
                $UsrRemote = ".\lvilla"
                $PassRemote = 'lv..2021' | ConvertTo-SecureString -AsPlainText -Force
            }
            default { 
                $UsrRemote = "FIDENSLAT\leonel.villa" 
                $PassRemote = 'lv..2021' | ConvertTo-SecureString -AsPlainText -Force
            }
        }		
        $CredRemote = New-Object System.Management.Automation.PSCredential($UsrRemote, $PassRemote)
        # Ejecutar REMOVE en el servidor
        $result = Invoke-Command -ComputerName $Server `
		          -Credential $CredRemote `
            -ScriptBlock $script -ArgumentList $UsuarioNorm, $Accion, $Grupo -ErrorAction Stop
        if ($result -ne "REMOVE OK") {
            throw "Resultado remoto inesperado: $result"
        }
        # ============================================================
        # EJECUTAR SP
        # ============================================================
        $Sql = @"
EXEC dbo.rdu_infraRegistrarRevocacionRDU
     @usr = '$UsuarioOriginal',
     @serv = '$Server',
     @grp = '$Grupo';
"@ 
        Write-Host "[$servSqlFidens] QUERY SQL EJECUTADO:" -Foreground Green
        Write-Host $Sql
        try {
            $removidosPermisos = Invoke-Sqlcmd -ConnectionString $Conn -Query $Sql -ErrorAction Stop
            Write-Host "[$Server] SP ejecutado" -ForegroundColor Green
            Write-ServerLog -Server $Server -Message "SP ejecutado"
            if (-not $removidosPermisos) {
                Write-Host "No hay referencias para actualizar cierre en ProyFidens 102." -ForegroundColor Yellow
                $id = $null				
                $NumReg = "NULL"
                $CodUser = ""
            }
            else {
                $Id = if ($removidosPermisos.Id) { $removidosPermisos.Id } else { $null }
                if ($removidosPermisos.NumReg -eq $null -or $removidosPermisos.NumReg -eq "" -or $removidosPermisos.NumReg -eq "NULL" -or $removidosPermisos.NumReg -is [System.DBNull]) {
                    $NumReg = "NULL"
                    Write-Host "NumReg detectado NULL" -foregroundColor Yellow
                }
                elseif ($removidosPermisos.NumReg -is [int]) {
                    $NumReg = $removidosPermisos.NumReg
                    Write-Host "NumReg detectado $NumReg" -foregroundColor Yellow
                }
                else {
                    Write-Host "[$servSqlFidens rdpRemove] Revisar tipo de dato de NumReg $($removidosPermisos.NumReg.GetType().name) "  -ForegroundColor Yellow 
                }
                if ($removidosPermisos.CodUser -eq $null -or $removidosPermisos.CodUser -eq "" -or $removidosPermisos.CodUser -eq "NULL" -or $removidosPermisos.CodUser -is [System.DBNull]) {
                    $Coduser = "NULL"
                    Write-Host "CodUser detectado NULL" -foregroundColor Yellow
                }
                else {
                    $CodUser = "'$removidosPermisos.CodUser'"
                    Write-Host "CodUser detectado $CodUser" -foregroundColor Yellow
                }	    	    
                #		    if ($NumReg -eq $null -or $NumReg -eq "" -or $NumReg -eq "NULL" -or $solicitados.NumReg -is [System.DBNull] -or  $Cod_User -eq $null -or $Cod_User -eq "" -or $CodUser -eq "NULL" -or $solicitados.CodUser -is [System.DBNull] ) {
                if ($NumReg -eq $null -or $NumReg -eq "" -or $NumReg -eq "NULL" -or $solicitados.NumReg -is [System.DBNull] ) {
                    Write-Host "[$servSqlFidens rdpRemove] No se Asigno estado FINALIZADO por NumReg $NumReg.GetType().name " -ForegroundColor Red
                }
                else {
                    Write-Host "[$servSqlFidens rdpRemove] Asignando estado FINALIZADO en NumReg $NumReg " -ForegroundColor Green
                    Write-Host "[$servSqlFidens rdpRemove] Id: $Id, NumReg: $NumReg, Estado: 3 :: rdu_infraProyectoFidensRegistrarEstado"
				
                    $SqlProyFidens = @"
EXEC dbo.rdu_infraProyectoFidensRegistrarEstado
	@NumReg = $NumReg,
	@Estado = 3;
	@CodUser = $CodUser
"@
                    Write-Host "[$servSqlFidens] QUERY SQL EJECUTADO:" -Foreground Green
                    Write-Host $SqlProyFidens

                    try {
                        Invoke-Sqlcmd -Query $SqlProyFidens -ConnectionString $ConnProyFidens -ErrorAction Stop
                    }
                    catch {
                        Write-Host "Advertencia: No se pudo registrar en ProyFidens" -ForegroundColor Yellow
                        Write-ServerLog -Server $Server -Message "Advertencia: No se registró ProyFidens"
                    }
                }
            }        
        }
        catch {
            # ROLLBACK
            $sqlError = $_.Exception.Message
            Write-Host "[$Server] ERROR ejecutando SP: $sqlError" -ForegroundColor Red
            Write-ServerLog -Server $Server -Message "ERROR ejecutando SP: $sqlError"

            $rollback = { param($UsuarioNorm, $Grupo) 
                try {
                    if (Get-Command Remove-LocalGroupMember -ErrorAction SilentlyContinue) {
                        Remove-LocalGroupMember -Group $Grupo -Member $UsuarioNorm -ErrorAction Stop
                    }
                    else {
                        cmd /c "net localgroup `"$Grupo`" `"$UsuarioNorm`" /delete"
                    }
  	            
                }
                catch {}
            }
            Invoke-Command -ComputerName $Server -ScriptBlock $rollback -ArgumentList $UsuarioNorm, $Grupo
            throw "ERROR: SP falló, acceso revertido"
        }
        Write-Host "[$Server] OK: Usuario removido y registrado" -ForegroundColor Green
        Write-ServerLog -Server $Server -Message "Proceso OK"
        Write-Host "[$Server] $result" -ForegroundColor Green
        Write-ServerLog -Server $Server -Message $result
    }
    catch {
        $err = $_.Exception.Message
        Write-Host "[$Server] ERROR: $err" -ForegroundColor Red
        Write-ServerLog -Server $Server -Message "ERROR: $err"
    }
}

# ==================================================================
# LOOP PRINCIPAL
# ==================================================================
foreach ($srv in $ServerList) {
    if ([string]::IsNullOrWhiteSpace($srv)) { continue }
    Gestionar-GrupoRemoto -Server $srv -Usuario $Usuario -Accion $Accion -Grupo $Grupo
}
Write-Host "`nProceso finalizado." -ForegroundColor Cyan