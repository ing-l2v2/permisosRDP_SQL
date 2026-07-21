<#
.SYNOPSIS
    Agrega un usuario a los grupos Administrators o Remote Desktop Users
    usando WinRM + CIM, con soporte para credenciales de dominio o locales
    y logs por servidor.
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

winrm set winrm/config/client @{TrustedHosts="10.0.0.*"}

o

$old = (winrm get winrm/config/client | Select-String TrustedHosts).ToString().Split('=')[1].Trim()
winrm set winrm/config/client @{TrustedHosts="$old,10.0.0.*"}

Limpiar el portapapeles desde el cmd
cmd /c echo off | clip

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

.\rdpAdd.ps1 -Servs "10.0.0.49" -User ".\FIDENSLAT\jtoledo" -GrupIn RDU
.\rdpAdd.ps1 -Servs "10.0.0.77" -User ".\FIDENSLAT\jtoledo" -GrupIn RDU
.\rdpAdd.ps1 -Servs "10.0.0.77" -User ".\FIDENSLAT\jtoledo" -GrupIn ADM
.\rdpAdd.ps1 -Servs "10.0.0.86" -User ".\jtoledo" -GrupIn RDU
.\rdpAdd.ps1 "10.0.0.102" ".\cberruz" -GrupIn RDU

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
    [string]$GrupoIn,
    [Nullable[int]]$DuracionHoras,
    [Nullable[datetime]]$Expira,
    [Nullable[int]]$idPryFidens
)

if ($DuracionHoras -eq $null) {
    $DuraHorasSql = 48
}
else { 
    $DuraHorasSql = $DuracionHoras
}
if ($Expira -eq $null) { 
    $ExpiraSql = "NULL"
}
else { 
    $ExpiraSql = "'" + $Expira.ToString("yyyy-MM-dd HH:mm:ss") + "'"
}


$Accion = "add"
switch ($GrupoIn.ToUpper()) {
    "ADM" { $Grupo = "Administrators" }
    "RDU" { $Grupo = "Remote Desktop Users" }
}
# .\GestionGrupos-WinRM.ps1 $Servidores $Usuario $Accion $GrupoIn

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
                Write-Host "[$Server rdpAdd] ERROR: No se pudo escribir en el log después de $maxRetry intentos" -ForegroundColor Red
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
$LogFileSqlAdd = "$LogDirSqlAdd\accesosASIGNADOS.txt"
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
        # Write-Host "[rdpAdd] Normalizar-Usuario $Usuario formato .\usuario" -ForegroundColor Cyan
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
            # $noequipo = $Usuario.split("\")[1]
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

# Caso especial de Huber Caycho
if ($Usuario -eq ".\hcaytcho") {
    $Usuario = ".\hcaycho"
}
# ==================================================================
# INFO
# ==================================================================
Write-Host "----------------------------------------------------------------"
Write-Host "RDP Usuario: $Usuario    Servidor: $Servidores" -ForegroundColor Cyan
Write-Host "Accion: $Accion     Grupo: $Grupo" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------"

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
    Write-Host "`n[$Server rdpAdd] Procesando..." -ForegroundColor Cyan
    # Write-ServerLog -Server $Server -Message "[$Server] Inicio proceso ADD de RDP para $Usuario en $Grupo"
    try {
        # Conectividad
        if (-not (Test-Connection -ComputerName $Server -Count 1 -Quiet)) {
            Write-Host "[$Server rdpAdd] No responde al ping para un test de conexion" -ForegroundColor Magenta
            Write-ServerLog -Server $Server -Message "[$Server rdpAdd] No responde al ping"
            return
        }
        # Normalizar usuario
        $UsuarioNorm = Normalizar-Usuario $Usuario
        $UsuarioOriginal = $Usuario
        # ============================================================
        # OBTENER CONTRASEÑA SEGÚN ÚLTIMO OCTETO
        # ============================================================
        $ServidorSQL = "10.0.0.49"
        $servSqlFidens = "10.0.0.56"
        $BdRepo = "master"
        $UsrSql = "lvilla"
        $Pass = "L2v2..20&25.#"
        $PassFidens = "L2v2..20&25.#"
        $Conn = "Server=$ServidorSQL;Database=$BdRepo;User ID=$UsrSql;Password=$Pass;TrustServerCertificate=True;"
        $ConnProyFidens = "Server=$servSqlFidens;Database=$BdRepo;User ID=$UsrSql;Password=$PassFidens;TrustServerCertificate=True;"

        if (-not (Test-Connection -ComputerName $servSqlFidens -Count 1 -Quiet)) {
            Write-Host "[$servSqlFidens] No responde al ping [$servSqlFidens]" -ForegroundColor Magenta
            Write-ServerLog -Server $servSqlFidens -Message "No responde al ping $servSqlFidens "
            return
        }
        
        # Validar duplicidad y no revocar si ya existe asignado
        #    56 Previamente buscar requerimiento 56 para ver si existe o no una solicitud para cotegarla
        #       Recibe FechaFin DATETIME, NumReg INT y CodUser VARCHAR(5)
        $sql56 = @"
EXEC dbo.rdu_infraProyFidensSolicitadosRDU
	@User = '$UsuarioOriginal',
	@Serv = '$Server',
	@Grup = 'RDP',
    @SubPry = NULL;
"@
        # Write-Host $sql56 -foregroundColor Cyan
        $consulta56 = Invoke-Sqlcmd -Query $sql56 -ConnectionString $ConnProyFidens
        if (-not $consulta56) {
            Write-Host "[$servSqlFidens rdpAdd] No hay referencias en 56.ProyFidens. Operación sin origen." -ForegroundColor Magenta
            Write-ServerLog -Server $servSqlFidens -Message "[$servSqlFidens rdpAdd] No hay referencia en 56.ProyFidens. Operacion sin origen"
            $pryFidFechaFin = "NULL"
            $pryFidNumReg = "NULL"
            $pryFidCodUser = "NULL"

            $NumReg = "NULL"
            $CodUser = "NULL"
        }
        else {
            #$Write-Host "[$servSqlFidens rdpAdd] Hay referencias en ProyFidens del Servidor 56. Depende de NumReg" -ForegroundColor Green
            $pryFechaFin = ConvertirToValorSql($consulta56["FechaFin"])
            $pryFidNumReg = ConvertirToValorSql($consulta56["NumReg"])
            $pryFidCodUser = ConvertirToValorSql($consulta56["CodUser"])
            $fechaFin = $pryFechaFin
            $ExpiraSql = "$fechaFin"
            $NumReg = $pryFidNumReg
            $CodUser = $pryFidCodUser
            Write-Host "-----------------------------------------" -ForegroundColor Cyan
            Write-Host "DEBUG FechaFin cruda: >>>$pryFechaFin<<<" -ForegroundColor Cyan
            Write-Host "pryFechaFin $pryFechaFin   pryFidNumReg $pryFidNumReg    pryFidCodUser $pryFidNumReg " -ForegroundColor Cyan
            Write-Host "fechaFin $fechaFin   ExpiraSql $ExpiraSql   NumReg $NumReg    CodUser $CodUser" -ForegroundColor Cyan
            Write-Host "-----------------------------------------" -ForegroundColor Cyan
        }
        #    Luego validar si existe ya una solicitud generada como ASIGNADO en 49, para mantener requerimiento y solo actualizarla
        $sql49 = @"
EXEC dbo.rdu_infra_duplicado_permiso_RDU
	@Usuario = '$UsuarioOriginal',
	@Servidor = '$Server',
	@Grupo = '$Grupo';
"@
        # Write-Host $sql49 -foregroundColor Cyan
        $duplica49 = Invoke-Sqlcmd -Query $sql49 -ConnectionString $Conn
        if (-not $duplica49) {
            $dupDuplicado = 0
            $dupNumReg = "NULL"
            $dupCodUser = "NULL"
            $dupEst = "NULL"
            $dupExpira = "NULL"
            $dupRevocado = "NULL"
            $dupUsuario = "NULL"
            $dupGrupo = "NULL"
            $dupId = "NULL"
        }
        else {
            # Obtiene información del registro duplicado
            $row = $duplica49 | Select-Object -First 1

            $dupDuplicado = if ($row.Duplicado -is [System.DBNull]) { 0 } else { [int]$row.Duplicado }
            $dupNumReg = if ($row.NumReg -is [System.DBNull]) { $null } else { [int]$row.NumReg }
            $dupId = if ($row.Id -is [System.DBNull]) { $null } else { [int]$row.Id }
            # $dupCodUser = if ($row.CodUser -is [System.DBNull]) { $null } else { $row.CodUser }

            # $dupDuplicado = [int]$duplica49.Duplicado
            # $dupNumReg = [int]$duplica49.NumReg
            $dupCodUser = ConvertirToValorSql($duplica49["CodUser"])
            $dupEst = ConvertirToValorSql($duplica49["Est"])
            $dupExpira = ConvertirToValorSql($duplica49["Expira"])
            $dupRevocado = ConvertirToValorSql($duplica49["Revocado"])
            $dupUsuario = ConvertirToValorSql($duplica49["Usuario"])
            $dupGrupo = ConvertirToValorSql($duplica49["Grupo"])
            #$dupId = [int]$duplica49.Id

            if ($null -eq $dupNumReg -or $dupNumReg -is [System.DBNull]) {
                Write-Host "NO DUPLICADO dupNumReg genera null no se registra 56.ProyFidens" -ForegroundColor Green
            }
            else {
                if ($dupDuplicado -eq 1) {
                    # Registra estado FINALIZADO al duplicado existente en 56.proyFidens
                    $sqlDupliFinaliza = @"
EXEC rdu_infraProyectoFidensRegistrarEstado
	@NumReg = $dupNumReg,
	@Estado = 3,
	@CodUser = $dupCodUser,
	@FechaFin = NULL;
"@                    
                    # Write-Host $sqlDupliFinaliza
                    $rduEstadoDupliFinalizado = Invoke-Sqlcmd -Query $sqlDupliFinaliza -ConnectionString $ConnProyFidens
                    if (-not $rduEstadoDupliFinalizado) {
                        Write-Host "Error inesperado al intentar registrar estado FINALIZADO 56.rdu_infraProyectoFidensRegistrarEstado por Duplicado."
                        Write-ServerLog "Error inesperado al intentar registrar estado SOLICITADO con rdpAdd 56.rdu_infraProyectoFidensRegistrarEstado"
                    }
                    else {
                        $FueDuplicado = ""
                        if ($dupDuplicado -eq 1) {
                            $FueDuplicado = "CASO DUPLICIDAD [$dupDuplicado]"
                        }
                        $dupEstado = ConvertirToValorSql($rduEstadoDupliFinalizado["Estado"])
                        Write-Host "DUPLICADO 1 ESTADO $dupEstado" -ForegroundColor Green
                        $dupFechaFin = ConvertirToValorSql($rduEstadoDupliFinalizado["FFIN"])
                        $dupHoraFin = ConvertirToValorSql($rduEstadoDupliFinalizado["HFIN"])
                        Write-Host "`n=========================================================" -ForegroundColor Green
                        Write-Host "    Duplicado![$dupId] Servidor: $Server Usuario: $UsuarioOriginal Grupo: $refGrupo    $FueDuplicado" -ForegroundColor Green
                        Write-Host "      NumReg: $dupNumReg    Estado: $dupEstado | $refEstado    Fecha Fin: $dupFechaFin    Hora: $dupHoraFin" -ForegroundColor Green
                        Write-Host "=========================================================`n" -ForegroundColor Green
                        Write-ServerLog -Server $Server -Message "Proceso completado Ok. $UsuarioOriginal en $refGrupo, NumReg: $pryNumReg, Estado: $pryEstado, Expira: $pryFechaFin, HoraExpira: $pryHoraFin"
                    }
                }                
            }
        }

        <#
        $UltimoOcteto = ($Server.Split("."))[-1]
        switch ($UltimoOcteto) {
            {$_ -in "49","56","61"} { $Pass = "L2v2..20&25.#" }
            default                 { $Pass = "lv..2021" }
        }
	#>
        # ============================================================
        # SCRIPT REMOTO PARA ADD / REMOVE / VALIDAR
        # ============================================================
        $script = {
            param($UsuarioNorm, $Grupo, $Accion)
            function Usuario-En-Grupo {
                try {
                    $miembros = Get-LocalGroupMember -Group $Grupo -ErrorAction Stop | Select-Object -ExpandProperty Name
                }
                catch {
                    # $miembros = (cmd /c "net localgroup `"$Grupo`"" | Select-String -Pattern "^\s+\S+").ToString().Trim()
                    $output = cmd /c "net localgroup `"$Grupo`""
                    $miembros = ($output | Select-String -Pattern "^\s+\S+") | ForEach-Object {
                        $_.ToString().Trim()
                    }

                    if (-not $miembros) { $miembros = @() }  # evitar $null		
                }
                return ($miembros -contains $UsuarioNorm)
            }
            function Add-U {
                try {
                    if (Get-Command Add-LocalGroupMember -ErrorAction SilentlyContinue) {
                        Add-LocalGroupMember -Group $Grupo -Member $UsuarioNorm -ErrorAction Stop
                    }
                    else {
                        cmd /c "net localgroup `"$Grupo`" `"$UsuarioNorm`" /add" | Out-Null
                    }
                }
                catch {
                    throw "ADD_FAIL: $($_.Exception.Message)"
                }
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
                catch {
                    return # evitar error si no existe
                }
            }
            # REMOVE previo si ya existe
            # if (Usuario-En-Grupo) {
            #    Remove-U
            # }

            # ADD
            if ($Accion -eq "add") {
                Add-U
                return "ADD_OK"
            }
            throw "Acción no válida"
        }

        # Ejecutar ADD en servidor
        if ($dupDuplicado -eq 0) {
            $result = Invoke-Command -ComputerName $Server -ScriptBlock $script `
                -ArgumentList $UsuarioNorm, $Grupo, $Accion -ErrorAction Stop
            if ($result -ne "ADD_OK") {
                throw "Resultado remoto inesperado: $result"
            }
        }
        if ($null -eq $NumReg -or $NumReg -eq "NULL") { 
            if ($null -eq $idPryFidens -or $idPryFidens -eq "NULL" -or $idPryFidens -eq "") {
                if ($null -eq $NumReg -or $dupNumReg -eq "NULL") {
                    $NumReg = "NULL"
                }
                else {
                    $NumReg = $dupNumReg
                }
            }
            else {
                $NumReg = $idPryFidens
            }
        }
        if ($CodUser -eq "NULL") { $CodUser = $dupCodUser }
        # Registra en 49 y recibe NumReg, CodUser, Est, FechaFin e idAcceso
        $Sql49 = @"
EXEC dbo.rdu_infraRegistrarAsignacionRDU
     @Usuario = '$UsuarioOriginal',
     @Servidor = '$Server',
     @Grupo = '$Grupo',
     @DuracionHoras = $DuraHorasSql,
     @Expira = $ExpiraSql,
     @NumReg = $NumReg,
     @CodUser = $CodUser;
"@

        # Write-Host "[$ServidorSQL] QUERY SQL EJECUTADO: $accesoSQL" -Foreground Yellow
        # Write-Host $Sql49 -Foreground Cyan

        try {
            $estadoOk = Invoke-Sqlcmd -ConnectionString $Conn -Query $Sql49 -ErrorAction Stop

            if (-not $estadoOk) {
                Write-Host "Error inesperado al Registrar Estado ASIGNO referencial de control en 49, no se inserto por 49.rdu_infraRegistrarAsignacionRDU" -ForegroundColor Magenta
                $FechaUpd = "NULL"
            }
            else {
                foreach ($r in $estadoOk) {
                    # $refNumReg = ConvertirToValorSql($r["NumReg"])      
                    # $refCodUser = ConvertirToValorSql($r["CodUser"])
                    $refEstado = ConvertirToValorSql($r["Est"])
                    $refExpira = ConvertirToValorSql($r["FechaFin"])
                    $refGrupo = ConvertirToValorSql($r["Grupo"])
                    $refDuplicado = ConvertirToValorSql($r["Duplicado"])
                    $idAcceso = ConvertirToValorSql($r["idAcceso"])
                    $refExpira = ConvertirToValorSql($r["Expira"])
                    $FechaUpd = ConvertirToValorSql($r["FechaFin"])
                }
            }
            #Write-Host "[$Server] rdpAdd] SP Ejecutado OK:: NumReg: $NumReg, Estado: 2 :: rdu_infraRegistrarAsignacionRDU" -ForegroundColor Cyan
            #Write-ServerLog -Server $Server -Message "SP ejecutado OK:: rdu_infraRegistrarAsignacionRDU Usuario [$UsuarioOriginal] NumReg [$NumReg] Estado [2]"

            # if ($NumReg -eq $null -or $NumReg -eq "" -or $NumReg -eq "NULL" -or $NumReg -is [System.DBNull]" -or  $Cod_User -eq $null -or $Cod_User -eq "" -or $CodUser -eq "NULL" -or $solicitados.CodUser -is [System.DBNull] ) {
            if ($NumReg -is [System.DBNull] -or $null -eq $NumReg -or $NumReg -eq "" -or $NumReg -eq "NULL" ) {
                Write-Host "[$ServidorSQL rdpAdd] No registrado estado ASIGNADO por NumReg $NumReg / $CodUser " -ForegroundColor Magenta
                Write-Host "`n=========================================================" -ForegroundColor Green
                Write-Host "    ASignado permiso RDP![$idAcceso] Servidor: $Server    Usuario: $UsuarioNorm    Grupo: $refGrupo    $FueDuplicado" -ForegroundColor Green
                Write-Host "         NumReg: NULL|NULL    Estado: $refEstado    Fecha Fin: $refExpira" -ForegroundColor Green
                Write-Host "=========================================================`n" -ForegroundColor Green
                Write-ServerLog -Server $ServidorSQL -Message "49 no registro estado ASIGNADO por Numreg $NumReg"
                if ($null -ne $idPryFidens -and -not $idPryFidens -is [System.DBNull]) {
                    Write-Host "ASigna por no encontrar $idPryFidens"
                    & ".\sqlUpdateNumRegToIsPermiso" -IdPermiso $idAcceso -NumReg $idPryFidens
                }
            }
            else {
                # Write-Host "[$servSqlFidens rdpAdd] Asigno estado EJECUTADO en NumReg $NumReg " -ForegroundColor Cyan
                # Registra el estado y genera email si CodUser no es null, falta agregar FechaFin nueva que recibe en EstadoOk.FechaFin
                $queryProyFidens = @"
EXEC rdu_infraProyectoFidensRegistrarEstado
	@NumReg = $NumReg,
	@Estado = 2,
	@CodUser = $CodUser,
	@FechaFin = $FechaUpd;
"@
                # Write-Host "[$servProyFidens rdpAdd] QUERY SQL EJECUTADO rdu_infraProyectoFidensRegistrarEstado" -Foreground Yellow
                # Write-Host $queryProyFidens
                $rduEstado = Invoke-Sqlcmd -Query $queryProyFidens -ConnectionString $ConnProyFidens
                if (-not $rduEstado) {
                    Write-Host "Error inesperado al intentar registrar estado SOLICITADO 56.rdu_infraProyectoFidensRegistrarEstado"
                    Write-ServerLog "Error inesperado al intentar registrar estado SOLICITADO con rdpAdd 56.rdu_infraProyectoFidensRegistrarEstado"
                }
                else {
                    $FueDuplicado = ""
                    if ($dupDuplicado -eq 1) {
                        $FueDuplicado = "CASO DUPLICIDAD"
                    }
                    $pryNumReg = ConvertirToValorSql($rduEstado["NumReg"])
                    $pryEstado = ConvertirToValorSql($rduEstado["Estado"])
                    $pryFechaFin = ConvertirToValorSql($rduEstado["FFIN"])
                    $pryHoraFin = ConvertirToValorSql($rduEstado["HFIN"])

                    $limpiaFFin = $pryFechaFin.Trim("'").Trim()
                    $limpiaHFin = $pryHoraFin.Trim("'").Trim()
                    $dt = [datetime]::Parse($limpiaFFin)
                    $FechaPry = $dt.Date
                    $dt = [datetime]::Parse($limpiaHFin)
                    $HoraPry = $dt.ToString("HH:mm")
                    Write-Host "`n=========================================================" -ForegroundColor Yellow
                    Write-Host "    Exito![$idAcceso] Servidor: $Server    Usuario: $UsuarioOriginal    Grupo: $refGrupo    $FueDuplicado" -ForegroundColor Yellow
                    Write-Host "        NumReg: $pryNumReg    Estado: $pryEstado | $refEstado    Fecha Fin: $FechaPry    Hora: $HoraPry" -ForegroundColor Yellow
                    Write-Host "=========================================================" -ForegroundColor Yellow
                    Write-ServerLog -Server $Server -Message "Proceso completado Ok. $UsuarioOriginal en $refGrupo, NumReg: $pryNumReg, Estado: $pryEstado, Expira: $pryFechaFin, HoraExpira: $pryHoraFin"
                }
            }
        }
        catch {
            # ROLLBACK
            Write-Host "[$Server rdpAdd] ERROR en SP → rollback rdu_infraRegistrarAsignacionRDU RefDuplicado $refDuplicado" -ForegroundColor Magenta
            Write-ServerLog -Server $Server -Message "[$Server rdpAdd] ERROR SP → rollback rdu_infraRegistrarAsignacionRDU"

            $rollback = { param($UsuarioOriginal, $Grupo) 
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
            throw "ERROR: SP fallo, acceso revertido, no se asigno el acceso"
        }
        #Write-Host "[$Server] OK: Usuario agregado y registrado" -ForegroundColor Green
        #Write-ServerLog -Server $Server -Message "Proceso OK"
    }
    catch {
        $err = $_.Exception.Message
        Write-Host "[$Server] catch rdpAdd ERROR: $err" -ForegroundColor Magenta
        Write-ServerLog -Server $Server -Message "ERROR: $err"
    }
}

# ==================================================================
# LOOP PRINCIPAL
# ==================================================================
# 1) Unir servidores manuales y los de ServerList
$servidoresTotales = ( @("10.0.0.49", "10.0.0.56") + $ServerList) | Sort-Object -Unique
# 2) Limpiar la lista → quitar vacíos, espacios y duplicados
$servidoresFinal = $servidoresTotales | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
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

    Write-AzureLog ".\rdpAdd -Servidores `"$srv`" -Usuario `"$Usuario`" -GrupoIn `"$GrupoIn`" -DuracionHoras $DuracionHoras -Expira `"$Expira`" "
}
#Write-Host "Proceso de asignacion de permiso concluido." -ForegroundColor Cyan
Write-Host "* * * = = = - - - Proceso de asignacion de permiso concluido - - - = = = * * *`n`n" -ForegroundColor Yellow

#$server = "10.0.0.56"
#mstsc /v:$server