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
cmdkey /add:10.0.0.53 /user:FIDENSLAT\leonel.villa /pass:lv..2021
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

#. "$PSScriptRoot\SyncCreds.ps1"

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
                Write-Host "[$Server rdpRemove] ERROR: No se pudo escribir en el log después de $maxRetry intentos" -ForegroundColor Red
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
            # $noequipo = $Usuario.Split("\")[1]
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
Write-Host "    Accion: REMOVE Usuario: $Usuario    Grupo: $Grupo" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------" -ForegroundColor Cyan

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
    Write-Host "`n[$Server rdpRemove] Procesando..." -ForegroundColor Cyan
    # Write-ServerLog -Server $Server -Message "[$Server rdpRemove] Inicio $Accion para $Usuario en $Grupo y $Accion"
    try {
        # Conectividad
        if (-not (Test-Connection -ComputerName $Server -Count 1 -Quiet)) {
            Write-Host "[$Server] No responde al ping [$Server]" -ForegroundColor Magenta
            Write-ServerLog -Server $Server -Message "No responde al ping $Server "
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
        $servSqlFidens = "10.0.0.56"
        $BdRepo = "master"
        $UsrSql = "lvilla"
        $Pass = "L2v2..20&25.#"
        $PassFidens = "L2v2..20&25.#"   # Para acceso a ProyFidens 10.0.0.56
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
        # Ejecutar REMOVE en el servidor
        $result = Invoke-Command -ComputerName $Server `
            -ScriptBlock $script -ArgumentList $UsuarioNorm, $Accion, $Grupo -ErrorAction Stop

        if ($result -ne "REMOVE OK") {
            Write-Host "Resultado remoto inesperado, no REMOVE OK $result "
            throw "Resultado remoto inesperado: $result"
        }
        else {
            # ============================================================
            # EJECUTAR SP
            # ============================================================
            # Write-Host "[$Server rdp-remove] Usuario Original: $UsuarioOriginal, Serv: $Server, Grupo: $Grupo :: rdu_infraRegistrarRevocacionRDU"
            # Registra la revocacion de RDP en servidor 49 y recibe NumReg, CodUser, FechaFin y Est
            $Sql = @"
EXEC dbo.rdu_infraRegistrarRevocacionRDU
    @usr = '$UsuarioOriginal',
    @serv = '$Server',
    @grp = '$Grupo';
"@
            Write-Host $Sql
            try {
                $removidosPermisos = Invoke-Sqlcmd -ConnectionString $Conn -Query $Sql -ErrorAction Stop
                # Write-Host "[$Server rdpRemove] SP ejecutado rdu_infraRegistrarRevocacionRDU" -ForegroundColor Cyan
                # Write-ServerLog -Server $Server -Message "[$Server rdpRemove] SP ejecutado rdu_infraRegistrarRevocacionRDU"
                if (-not $removidosPermisos) {
                    Write-Host "[$ServidorSQL rdpRemove] No hay referencias no se actualizara 56.ProyFidens por 49." -ForegroundColor Yellow
                    $NumReg = "NULL"
                    $CodUser = "NULL"
                    $idAcceso = "NULL"
                }
                else {
                    # $removidosPermisos | Format-List *
                    # Write-Host "====================================================================================================" -ForegroundColor Cyan
                    # $removidosPermisos | Format-Table *
                    $NumReg = ConvertirToValorSql($removidosPermisos["NumReg"])
                    $CodUser = ConvertirToValorSql($removidosPermisos["CodUser"])
                    $idAcceso = ConvertirToValorSql($removidosPermisos["Id"])
                    # Write-Host "[DEBUG $ServidorSQL rdpRemove] Referencias para actualizar 56.ProyFidens. NumReg $NumReg, CodUser $CodUser, Id $idAcceso" -ForegroundColor Yellow
                    #    if ($NumReg -eq $null -or $NumReg -eq "" -or $NumReg -eq "NULL" -or $removidosPermisos -is [System.DBNull] -or  $Cod_User -eq $null -or $Cod_User -eq "" -or $CodUser -eq "NULL" -or $removidosPermisos.CodUser -is [System.DBNull] ) {
                    if ($NumReg -is [System.DBNull] -or $null -eq $NumReg -or $NumReg -eq "" -or $NumReg -eq "NULL") {
                        Write-Host "[$ServidorSQL rdpRemove] No se asigna estado REVOCADO por NumReg NULL, revisar nombre de usuario FIDENSLAT O LOCAL." -ForegroundColor Magenta
                        Write-Host "---------------------------------------------------------------------------------------------" -ForegroundColor Green
                        Write-Host "OK Revocado::[$idAcceso] Usuario: $UsuarioOriginal    Servidor: $Server    NumReg: $NumReg | $CodUser" -ForegroundColor Green
                        Write-Host "---------------------------------------------------------------------------------------------" -ForegroundColor Green
                        Write-ServerLog -Server $ServidorSQL -Message "No se asigna REVOCADO en 49 POR NumReg NULL"
                    }
                    else {
                        # Write-Host "[DEBUG $servSqlFidens rdpRemove] Asignando estado FINALIZADO en NumReg $NumReg rdu_infraProyectoFidensRegistrarEstado" -ForegroundColor Cyan
                        $SqlProyFidens = @"
EXEC dbo.rdu_infraProyectoFidensRegistrarEstado
    @NumReg = $NumReg,
    @Estado = 3,
    @CodUser = $CodUser,
    @FechaFin = NULL;
"@
                        # Write-Host "[$servSqlFidens] QUERY SQL EJECUTADO:" -Foreground Green
                        Write-Host $SqlProyFidens
                        $revocado = Invoke-Sqlcmd -Query $SqlProyFidens -ConnectionString $ConnProyFidens
                        if (-not $revocado ) {
                            Write-Host "Sin referencia para actualizar ESTADO Finalizado en 56.ProyFidens." -ForegroundColor Red
                        }
                        else {
                            $revNumReg = ConvertirToValorSql($revocado["NumReg"])
                            $revEstado = ConvertirToValorSql($revocado["Estado"])
                            $revFFIN = ConvertirToValorSql($revocado["FFIN"])
                            $revHFIN = ConvertirToValorSql($revocado["HFIN"])

                            $limpiaFFin = $revFFIN.Trim("'").Trim()
                            $limpiaHFin = $revHFIN.Trim("'").Trim()
                            $dt = [datetime]::Parse($limpiaFFin)
                            $FechaPry = $dt.Date
                            $dt = [datetime]::Parse($limpiaHFin)
                            $HoraPry = $dt.ToString("HH:mm")
                            Write-Host "---------------------------------------------------------------------------------------------" -ForegroundColor Yellow
                            Write-Host "Registro OK ProyFidens::[$idAcceso] Usuario: $UsuarioOriginal    Servidor: $Server    NumReg: $revNumReg" -ForegroundColor Yellow
                            Write-Host "CodUser: $CodUser    Estado: $revEstado    FechaFin: $FechaPry    HFIN: $HoraPry" -ForegroundColor Yellow
                            Write-Host "---------------------------------------------------------------------------------------------" -ForegroundColor Yellow                                
                        }
                        # Write-Host "[DEBUG $servSqlFidens rdpRemove]: Actualizado en ProyFidens un FINALIZADO" -ForegroundColor Yellow
                    }
                }
            }
            catch {
                # ROLLBACK
                $sqlError = $_.Exception.Message
                Write-Host "[$Server] ERROR ejecutando SP: $sqlError" -ForegroundColor Magenta
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
                throw "ERROR: SP fallido, acceso revertido"
            }
            Write-Host "[$Server] OK: Usuario removido y registrado" -ForegroundColor Green
            # Write-ServerLog -Server $Server -Message "Proceso OK"
            # Write-Host "[$Server] $result" -ForegroundColor Green
            # Write-ServerLog -Server $Server -Message $result
        }
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
# 1) Unir servidores manuales y los de ServerList
$servidoresTotales = ( @("10.0.0.49", "10.0.0.56") + $ServerList ) | Sort-Object -Unique
# 2) Limpiar la lista → quitar vacíos, espacios y duplicados
$servidoresFinal = $servidoresTotales |
Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
# 3) Sincronizar credenciales una sola vez para todos
# Sync-RemoteCredencialGrupo -Servidores $servidoresFinal
# 4) Ejecutar el proceso para cada servidor
. "$PSScriptRoot\ServidoresCredenciales.ps1"
foreach ($cmdServ in $servidoresFinal) {    
    $accCreds = $Global:ServidoresCredenciales[$cmdServ]
    $accUsr = $accCreds.User
    $accPass = $accCreds.Password
    Write-Host "Validando $cmdServ..."
    # Start-Process cmdkey -ArgumentList "/add:$cmdServ", "/user:$accUsr", "/pass:$accPass" -NoNewWindow -Wait
    Start-Process cmdkey -ArgumentList "/add:$cmdServ", "/user:$accUsr", "/pass:$accPass" -NoNewWindow -Wait -RedirectStandardOutput "NUL"
}
foreach ($srv in $ServerList) {
    # if ([string]::IsNullOrWhiteSpace($srv)) { continue }
    # Sync-RemoteCredencialGrupo -Servidores @($srv)
    Gestionar-GrupoRemoto -Server $srv -Usuario $Usuario -Accion $Accion -Grupo $Grupo
    Write-AzureLog ".\rdpRemove -Servidores `"$srv`" -Usuario `"$Usuario`" -GrupoIn `"$GrupoIn`" "
}
Write-Host "`nProceso finalizado." -ForegroundColor Cyan

#cmdkey /delete:TERMSRV/10.0.0.56
#Write-Log "Credencial RDP removida para 10.0.0.56"