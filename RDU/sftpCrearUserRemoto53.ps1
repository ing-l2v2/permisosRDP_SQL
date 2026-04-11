param(
  [Parameter(Mandatory = $true)]
  [string]$Usuario,
  [string]$Descripcion      # Descripcion del usuario
  # [string]$CorreosDestino   # Correo(s) donde se enviara el zip
)

$Usuario = $Usuario.Substring(0, [Math]::Min(20, $Usuario.Length))
$Descripcion = $Descripcion.Substring(0, [Math]::Min(48, $Descripcion.Length))

# Servidor donde se ejecutara el proceso
# $Server = "10.0.0.53"

# Carpeta donde se generaran las llaves
$KeyFolder = "C:\infraestructura\keys"
# Carpeta authorized_keys
$AuthKeys = "C:\ProgramData\ssh_modern\etc\authorized_keys"
# Carpeta raiz del SFTP
$SftpRoot = "D:\SFTP_MODERN\WORK\$Usuario"

# Invoke-Command -ComputerName $Server -ScriptBlock {
#   param($Usuario, $KeyFolder, $AuthKeys, $SftpRoot)
Write-Host "=== INICIANDO PROCESO PARA $Usuario ===" -ForegroundColor Cyan

# Write-Host "Validando si el usuario existe..." -ForegroundColor Cyan
if (Get-LocalUser -Name $Usuario -ErrorAction SilentlyContinue) {
  Write-Host "El usuario $Usuario ya existe" -ForegroundColor Red
}
else {
  # Write-Host "DEBUG: Creando usuario local..." -ForegroundColor Green
  New-LocalUser -Name $Usuario -NoPassword -Description $Descripcion | Out-Null
}

# Write-Host "Validando grupo sftp-users..." -ForegroundColor Cyan
if (-not (Get-LocalGroupMember -Group "sftp-users" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$Usuario" })) {
  Add-LocalGroupMember -Group "sftp-users" -Member $Usuario
  # Write-Host "DEBUG: Usuario anadido al grupo sftp-users" -ForegroundColor Yellow
}
else {
  Write-Host "Usuario ya estaba en sftp-users" -ForegroundColor Cyan
}

# GENERAR LLAVES
$keyGen = "C:\OpenSSH-Modern\OpenSSH-Win64\ssh-keygen.exe"
if (-not (Test-Path $KeyFolder)) { New-Item -ItemType Directory -Path $KeyFolder }

# Write-Host "Generando llaves SSH..." -ForegroundColor Yellow
Remove-Item "$KeyFolder\$Usuario" -Force -Recurse -ErrorAction SilentlyContinue
& $keyGen -t ed25519 -C "$Usuario@SRV-REPLICA-01" -f "$KeyFolder\$Usuario" -q -N '""'

# Registrar public key
$destPub = "$AuthKeys\$Usuario"
if (Test-Path "$destPub") {
  Write-Host "Removiendo llave publica en $destPub ..." -ForegroundColor Green
  Remove-Item "$destPub" -Force -Recurse
}
Write-Host "Registrando llave publica en $destPub ..." -ForegroundColor Cyan
Get-Content "$KeyFolder\$Usuario.pub" | Out-File -Encoding ascii $destPub
# Write-Host " DEBUG:   * * * Llave registrada en authorized_keys" -ForegroundColor Cyan

<#
$Fecha = (Get-Date -Format "yyyyMMdd")
$LocalZipPath = ".\llavesprivadas"
$ZipFile = "$LocalZipPath\${Usuario}_$Fecha.zip"
# Crear carpeta si no existe
if (-not (Test-Path $LocalZipPath)) {
  New-Item -ItemType Directory -Path $LocalZipPath | Out-Null
}
# Comprimir la llave privada
Compress-Archive -Path "$KeyFolder\$Usuario" -DestinationPath $ZipFile -Force
#>

# Creacion de carpeta SFTP
Write-Host "Creando estructura SFTP para $Usuario..." -ForegroundColor Cyan
$UploadDir = "$SftpRoot\upload"
mkdir $UploadDir -Force | Out-Null

# Permisos Upload
icacls $UploadDir /inheritance:r
icacls $UploadDir /grant:r "${Usuario}:(OI)(CI)(M)"
icacls $UploadDir /grant:r "SYSTEM:(OI)(CI)(RX)"
icacls $UploadDir /grant "Administrators:(OI)(CI)(RX)"

# Permisos de carpeta raiz del usuario
takeown /F $SftpRoot /R /D Y | Out-Null
icacls $SftpRoot /grant administrators:F /T
icacls $SftpRoot /inheritance:r
icacls $SftpRoot /setowner $Usuario
icacls $SftpRoot /grant "${Usuario}:(OI)(CI)(F)"
icacls $SftpRoot /remove:g "SYSTEM"
icacls $SftpRoot /remove:g "Administrators"

Write-Host "Usuario creado correctamente" -ForegroundColor Green
Write-Host "Llave publica instalada en authorized_keys" -ForegroundColor Green
Write-Host "Carpeta SFTP lista en $SftpRoot" -ForegroundColor Green
Write-Host "Copia la llave privada: $KeyFolder\$Usuario" -ForegroundColor Green


# Generación de instrucciones y archivo zip a partir de instrucciones y PrivateKey
$LocalZipPath = "C:\infraestructura\keys_zips"
if (-not (Test-Path $LocalZipPath)) {
  New-Item -ItemType Directory -Path $LocalZipPath -Force | Out-Null
}
# ==== ARCHIVOS DE LLAVES ====
$PrivateKey = "$KeyFolder\$Usuario"
# $PublicKey = "$KeyFolder\$Usuario.pub"

$Instrucciones = @"
INSTRUCCIONES PARA ACCESO SFTP
------------------------------
Usuario: $Usuario
Servidor Publico: 200.6.96.236
Puerto: 2222

Cuando encuentre <su_usuario_local> significa que debe usar su usuario de sesion Windows en el PC remoto el cual accedera por SFTP.

1. Coloque el archivo PRIVADO del zip en:
   - Windows: C:\Users\<su_usuario_local>\.ssh\
   - Linux/Mac: ~/.ssh/  

1.1 Opcional crear un archivo config en la ruta
   - Windows: C:\Users\<su_usuario_local>\.ssh\
   - Linux/Mac: ~/.ssh/
  En el archivo config editar el contenido
  # Usuario $Usuario al servidor SFTP 53 200.6.96.236
    Host fidens-$Usuario
    HostName 200.6.96.236
    Port 2222
    User $Usuario
    IdentityFile C:\Users\<su_usuario_local>\.ssh\$Usuario

2. Conexion por CMD, version extendida:
   sftp -i C:\Users\<su_usuario_local>\.ssh\$Usuario -P 2222 $Usuario@200.6.96.236

2.1 Opcion por CMD relacionado con el paso opcional 1.1 con archivo config implementado. Version reducida
   sftp fidens-$Usuario

3. Conexion por FileZilla:
   - Protocolo: SFTP
   - Host: 200.6.96.236
   - Usuario: $Usuario
   - Puerto: 2222
   - Autenticacion por LLAVE PRIVADA
   - Archivo de clave: llave privada incluida en este ZIP

4. Conexion por WinSCP:
   - Protocolo: SFTP
   - Host: 200.6.96.236
   - User: $Usuario
   - Port: 2222
   - Autenticacion por LLAVE PRIVADA
   - Archivo de clave: llave privada incluida en este ZIP

5. Al iniciar sesion SFTP el usuario podra almacenar en la ruta upload, no en la ruta raiz.

6. No olvidar cerrar sesion en las conexiones SFTP si es mediante CMD usar el comando bye

IMPORTANTE:
Nunca compartir la llave privada. No editarla. No enviarla por WhatsApp o correo sin cifrado.
"@
$FileInst = "$LocalZipPath\instrucciones_${Usuario}.txt"
# $Instrucciones | Out-File $FileInst -Encoding utf8NoBOM

# Set-Content -Path $FileInst -Value $Instrucciones -Encoding UTF8
# [System.IO.File]::WriteAllText($FileInst, $Instrucciones, (New-Object System.Text.UTF8Encoding($false)))

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($FileInst, $Instrucciones, $utf8Bom)

# ==== CREAR ZIP FINAL ====
$ZipFile = "$LocalZipPath\$Usuario.zip"
<#
Compress-Archive `
  -Path $PrivateKey, $PublicKey, $FileInst `
  -DestinationPath $ZipFile -Force
#>
Compress-Archive `
  -Path $PrivateKey, $FileInst `
  -DestinationPath $ZipFile -Force

# Eliminar archivo de instrucciones y privateKey
if (Test-Path $FileInst) {
  Remove-Item $FileInst -Force -ErrorAction SilentlyContinue
}
if (Test-Path $PrivateKey) {
  Remove-Item $PrivateKey -Force -ErrorAction SilentlyContinue
}

# } -ArgumentList $Usuario, $KeyFolder, $AuthKeys, $SftpRoot

# Conexion remota con servidor como administrador, pass a usar Ohdef_107
# net use \\10.0.0.53\c$ /user:10.0.0.53\Administrator *
# dir \\10.0.0.53\c$

# Forma 3 de comprobada
<#
Copy-Item `
  "C:\Users\lvill\Dropbox\AtencionFidens\ScriptSQL\permisos\RDU\sftpCrearUserRemoto53.ps1" `
  "\\10.0.0.53\C$\infraestructura\" -Force

PsExec64.exe \\10.0.0.53 -s powershell.exe `
  -Command "& 'C:\infraestructura\sftpCrearUserRemoto53.ps1' -Usuario 'derco_bci_prueba' -Descripcion 'Requerido pvalle, cliente Derco'"

# Se ejecuta una sola vez en el 10.0.0.53
New-SmbShare -Name keys_zips -Path "C:\infraestructura\keys_zips" -FullAccess "Administrators"  

$Usuario = "cargaCiaBci"
$LocalFolder = "C:\Temp\llavesgeneradas"
$RemoteFolder = "\\10.0.0.53\keys_zips"
Copy-Item "$RemoteFolder\$Usuario.zip" -Destination $LocalFolder -Force
#>

# Requisitos en servidor 10.0.0.53
<#
  # WinRM habilitado
  Enable-PSRemoting -Force
  # Firewall habilitando puerto 5985 (HTTP) o 5986 (HTTPS)
  Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -Enabled True
  # Tu usuario debe estar autorizado para remoting
  Set-PSSessionConfiguration -Name Microsoft.PowerShell -ShowSecurityDescriptorUI


  Registrar auditoria en un archivo
  Enviar email al finalizar
  Validar que no existan carpetas previas
  Integrarlo a un portal web interno
  Generar un ZIP con la llave privada para entregar
#>

<#
  Diagnostico rapido en PS
  #   Servidor responde
  Test-Connection 10.0.0.53 -Count 2
  #   Hay puerto SMB abierto
  Test-Connection 10.0.0.53 -Count 2
  #   Tu usuario tiene admin en ese servidor
  whoami /groups | findstr /i admin
  #   Ver si hay sesion SMB colgada, si aparece algo como \\10.0.0.53\IPC$ ->  Error debes limpiarlo
  net use
  #     limpiarlo con
  net use \\10.0.0.53\IPC$ /delete
  #   Desconectar con confirmacion
  net use \\10.0.0.53\c$ /delete /y
#>