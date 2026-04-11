<#
.SYNOPSIS
    Gestiona usuarios en grupos Administrators o Remote Desktop Users
    usando WinRM + CIM, con soporte para credenciales de dominio o locales
    y logs por servidor.
.PARAMETER Servidores
    Lista de servidores separados por coma o archivo de texto.
.PARAMETER Usuario
    Usuario a agregar o remover en formato dominio\usuario, .\usuario o equipo\usuario
.PARAMETER Accion
    A (add) | R (remove)
.PARAMETER Grupo
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

.\GestionGrupos-WinRM.ps1 -Servidores "10.0.0.49" -Usuario ".\FIDENSLAT\jtoledo" -AccionIn A -GrupoIn RDU
.\GestionGrupos-WinRM.ps1 -Servidores "10.0.0.77" -Usuario ".\FIDENSLAT\jtoledo" -AccionIn A -GrupoIn RDU
.\GestionGrupos-WinRM.ps1 -Servidores "10.0.0.86" -Usuario ".\jtoledo" -AccionIn A -GrupoIn RDU
.\GestionGrupos-WinRM.ps1 -Servidores "10.0.0.86" -Usuario ".\jtoledo" -AccionIn A -GrupoIn ADM
.\GestionGrupos-WinRM.ps1 -Servidores "10.0.0.86" -Usuario ".\jtoledo" -AccionIn R -GrupoIn ADM

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
    [ValidateSet("a","r")]
    [string]$AccionIn,
    [ValidateSet("ADM","RDU")]
    [string]$GrupoIn

#    [ValidateSet("add","remove")]
#    [string]$Accion,
#    [ValidateSet("Administrators","Remote Desktop Users")]
#    [string]$Grupo
    # [Parameter(Mandatory = $true)]
    # [System.Management.Automation.PSCredential]$Credenciales
)

# ================================================================
# TRADUCCIÓN DE PARÁMETROS SIMPLIFICADOS
# ================================================================
switch ($AccionIn.ToUpper()) {
    "A" { $Accion = "add" }
    "R" { $Accion = "remove" }
}
switch ($GrupoIn.ToUpper()) {
    "ADM" { $Grupo = "Administrators" }
    "RDU" { $Grupo = "Remote Desktop Users" }
}    
# ==================================================================
# LOGGING
# ==================================================================
$LogDir = ".\logs"
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
function Write-ServerLog {
    param([string]$Server, [string]$Message)
    $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Add-Content -Path "$LogDir\$Server.log" -Value "$timestamp | $Message"
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
} else {
    $ServerList = $Servidores.Split(",") | ForEach-Object { $_.Trim() }
}
# ==================================================================
# INFO
# ==================================================================
Write-Host "Usuario a gestionar: $Usuario" -ForegroundColor Cyan
Write-Host "Accion: $Accion" -ForegroundColor Cyan
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
        # $Credenciales
    )
    Write-Host "`n[$Server] Procesando..." -ForegroundColor Cyan
    Write-ServerLog -Server $Server -Message "Inicio acción $Accion para $Usuario en $Grupo"
    try {
        # Conectividad
        if (-not (Test-Connection -ComputerName $Server -Count 1 -Quiet)) {
            Write-Host "[$Server] No responde al ping" -ForegroundColor Magenta
            Write-ServerLog -Server $Server -Message "No responde al ping"
            return
        }
        # Normalizar usuario ANTES del envío
        $UsuarioNorm = Normalizar-Usuario $Usuario
        # Código remoto
        $script = {
            param($UsuarioNorm, $Accion, $Grupo)
            function Add-UserToGroup {
                param([string]$Grupo,[string]$UsuarioNorm)
                if (Get-Command Add-LocalGroupMember -ErrorAction SilentlyContinue) {
                    Add-LocalGroupMember -Group $Grupo -Member $UsuarioNorm -ErrorAction Stop
                } else {
                    $cmd = "net localgroup `"$Grupo`" `"$UsuarioNorm`" /add"
                    cmd.exe /c $cmd | Out-Null
                }
            }
            function Remove-UserFromGroup {
                param([string]$Grupo,[string]$UsuarioNorm)
                if (Get-Command Remove-LocalGroupMember -ErrorAction SilentlyContinue) {
                    Remove-LocalGroupMember -Group $Grupo -Member $UsuarioNorm -ErrorAction Stop
                } else {
                    $cmd = "net localgroup `"$Grupo`" `"$UsuarioNorm`" /delete"
                    cmd.exe /c $cmd | Out-Null
                }
            }
            if ($Accion -eq 'add') {
                Add-UserToGroup -Grupo $Grupo -UsuarioNorm $UsuarioNorm
                return "OK: Usuario agregado"
            }
            elseif ($Accion -eq 'remove') {
                Remove-UserFromGroup -Grupo $Grupo -UsuarioNorm $UsuarioNorm
                return "OK: Usuario removido"
            }
            throw "Acción no válida"
        }
        # Ejecutar en el servidor
#       $result = Invoke-Command -ComputerName $Server -Credential $Credenciales `
#                  -ScriptBlock $script -ArgumentList $UsuarioNorm,$Accion,$Grupo -ErrorAction Stop
        $result = Invoke-Command -ComputerName $Server `
                  -ScriptBlock $script -ArgumentList $UsuarioNorm,$Accion,$Grupo -ErrorAction Stop
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
    # Gestionar-GrupoRemoto -Server $srv -Usuario $Usuario -Accion $Accion -Grupo $Grupo -Credenciales $Credenciales
}
Write-Host "`nProceso finalizado." -ForegroundColor Cyan