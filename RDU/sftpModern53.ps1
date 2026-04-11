<#
En el servidor 10.0.0.53
Tengo instalado el OpenSSH10.0.p2 en paralelo con OpenSSH9.5.p1 (nativo de Windows)
El OpenSSH 10.0.p2 se encuentra en la ruta C:\OpenSSH-Modern\OpenSSH-Win64 ahí reside el ssh.exe, el sftp.exe, etc.
Esta instalacion se hizo descomprimiento el contenido del archivo OpenSSH-Win64.zip
Tengo el archivo de configuracion del OpenSSH 10.0.p2 en la ruta  C:\ProgramData\ssh_modern\etc\sshd_config
Los archivos de claves del servidor se encuentran en C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key allí tambien residen los ssh_host_*_key.pub
Los archivos de claves publicas de los usuarios en este caso un usuario para prueba definido como psilva se encuentran en C:\ProgramData\ssh_modern\etc\authorized_keys
Se tiene la ruta para C:\ProgramData\ssh_modern\logs
El usuario que se creo para prueba psilva es un usuario windows sin password pero con claves pub y privada, psilva pertenece al grupo de usuarios sftp-users
Se asigna el directorio D:/SFTP_MODERN/WORK/%u que depende del usuario psilva para operar y en si de todos los usuarios.
En base a todo lo anterior y con sshd_config que te compartiré en las líneas siguientes, favor indicame sin dar tantas vueltas los permisos que se deben otorgar a las rutas y a los contenidos de los directorios.
C:\OpenSSH-Modern
C:\OpenSSH-Modern\OpenSSH-Win64
C:\ProgramData\ssh_modern
C:\ProgramData\ssh_modern\etc
C:\ProgramData\ssh_modern\keyhost
C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key
C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key.pub
C:\ProgramData\ssh_modern\logs
D:\SFTP_MODERN
D:\SFTP_MODERN\WORK
D:\SFTP_MODERN\WORK\%u

Te repito el caso es de OpenSSH 10.0.p2 que estará en paralelo con el OpenSSH 9.5.p1

Comparto el archivo sshd_config 
# ================================
#  PUERTO Y DIRECCIONES
# ================================
Port 2222
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# ================================
#  AUTENTICACIÓN
# ================================
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
AuthenticationMethods publickey

PermitRootLogin no

# ================================
#  LOGS
# ================================
SyslogFacility LOCAL0
LogLevel VERBOSE

# ================================
#  LLAVES HOST
# ================================
HostKey C:/ProgramData/ssh_modern/keyhost/ssh_host_ed25519_key
HostKey C:/ProgramData/ssh_modern/keyhost/ssh_host_ecdsa_key
HostKey C:/ProgramData/ssh_modern/keyhost/ssh_host_rsa_key

# ================================
#  CIFRADOS
# ================================
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes128-ctr

# ================================
#  MACs
# ================================
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com

# ================================
#  KEX
# ================================
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# ================================
#  ALGORITMOS DE CLAVE PÚBLICA
# ================================
PubkeyAcceptedAlgorithms ssh-ed25519,ecdsa-sha2-nistp256,rsa-sha2-256,rsa-sha2-512
HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp256,rsa-sha2-256,rsa-sha2-512

# ================================
#  SEGURIDAD
# ================================
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PermitTunnel no
GatewayPorts no
AllowStreamLocalForwarding no

# ================================
#  SFTP 
# ================================
Subsystem sftp C:/OpenSSH-Modern/OpenSSH-Win64/sftp-server.exe

# ================================
#  DEFAULTS
# ================================
StrictModes yes
PermitTTY yes
PrintMotd no
PrintLastLog no

# ================================
#  UBICACION CORRECTA DE KEYS
# ================================
AuthorizedKeysFile C:/ProgramData/ssh_modern/etc/authorized_keys/%u

# ================================
#  SFTP CHROOT POR GRUPO
# ================================
Match Group sftp-users
    ChrootDirectory D:/SFTP_MODERN/WORK/%u
    ForceCommand internal-sftp
    AuthorizedKeysFile C:/ProgramData/ssh_modern/etc/authorized_keys/%u
    PasswordAuthentication no
    PubkeyAuthentication yes
    PermitTTY no


Espero no des tantas vueltas y la solucion me la compartas a la brevedad posible.
En el firewall de windows tengo abierto los puertos 10021 y 2222 este ultimo es para OpenSSH 10.0.p2

PS C:\Windows\system32> Get-Service sshd*
Status   Name               DisplayName
------   ----               -----------
Running  sshd               OpenSSH SSH Server
Stopped  sshd_modern        OpenSSH Modern (10.0.p2)

Adicional te comparto el servicio al intentar levantarlo sshd_modern
PS C:\Windows\system32> Start-Service sshd_modern
Start-Service : Service 'OpenSSH Modern (10.0.p2) (sshd_modern)' cannot be started due to the following error: Cannot
start service sshd_modern on computer '.'.
At line:1 char:1
+ Start-Service sshd_modern
+ ~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : OpenError: (System.ServiceProcess.ServiceController:ServiceController) [Start-Service],
   ServiceCommandException
    + FullyQualifiedErrorId : CouldNotStartService,Microsoft.PowerShell.Commands.StartServiceCommand

PS C:\Windows\system32> netstat -ano | findstr :2222
PS C:\Windows\system32> netstat -ano | findstr :10021
  TCP    0.0.0.0:10021          0.0.0.0:0              LISTENING       3708
  TCP    10.0.0.53:10021        52.190.44.200:22656    ESTABLISHED     3708
  TCP    10.0.0.53:10021        172.172.102.135:39684  ESTABLISHED     3708
  TCP    [::]:10021             [::]:0                 LISTENING       3708

#>

psexec64 -i -s cmd.exe

icacls C:\OpenSSH-Modern /inheritance:r
icacls C:\OpenSSH-Modern /grant:r "SYSTEM:(F)"
icacls C:\OpenSSH-Modern /grant:r "ADMINISTRATORS:(F)"
icacls C:\OpenSSH-Modern /setowner "ADMINISTRATORS"
icacls C:\OpenSSH-Modern          # Solo SYSTEM y ADMINISTRATORS FULL

takeown /F "C:\OpenSSH-Modern\OpenSSH-Win64" /R /D Y
icacls C:\OpenSSH-Modern\OpenSSH-Win64 /inheritance:r
icacls C:\OpenSSH-Modern\OpenSSH-Win64 /grant:r "SYSTEM:(F)"
icacls C:\OpenSSH-Modern\OpenSSH-Win64 /grant:r "ADMINISTRATORS:(F)"
icacls C:\OpenSSH-Modern\OpenSSH-Win64 /grant:r "Users:(RX)"
icacls C:\OpenSSH-Modern\OpenSSH-Win64 /setowner "ADMINISTRATORS"
icacls C:\OpenSSH-Modern\OpenSSH-Win64

# Estaba con SYSTEM y ADMINISTRATORS (FULL), sshd_modern (RX)
icacls C:\ProgramData\ssh_modern /inheritance:r
icacls C:\ProgramData\ssh_modern /grant "SYSTEM:(F)" "ADMINISTRATORS:(F)" /T
icacls C:\ProgramData\ssh_modern /grant "NT SERVICE\sshd_modern:(RX)"
icacls C:\ProgramData\ssh_modern /remove:g "leonel.villa" "FIDENSLAT\leonel.villa" "FIDENSLAT\leonel.villa"
icacls C:\ProgramData\ssh_modern /setowner "SYSTEM"
icacls C:\ProgramData\ssh_modern

icacls C:\ProgramData\ssh_modern\etc /inheritance:r
icacls C:\ProgramData\ssh_modern\etc /grant "SYSTEM:(F)"
icacls C:\ProgramData\ssh_modern\etc /grant "ADMINISTRATORS:(F)"
icacls C:\ProgramData\ssh_modern\etc /grant "NT SERVICE\sshd_modern:(RX)"
icacls C:\ProgramData\ssh_modern\etc /remove:g "FIDENSLAT\Domain Admins"
icacls C:\ProgramData\ssh_modern\etc /setowner "SYSTEM"
icacls C:\ProgramData\ssh_modern\etc

icacls C:\ProgramData\ssh_modern\etc\sshd_config /inheritance:r
icacls C:\ProgramData\ssh_modern\etc\sshd_config /grant "SYSTEM:(F)"
icacls C:\ProgramData\ssh_modern\etc\sshd_config /grant "ADMINISTRATORS:(F)"
icacls C:\ProgramData\ssh_modern\etc\sshd_config /grant "NT SERVICE\sshd_modern:(RX)"
icacls C:\ProgramData\ssh_modern\etc\sshd_config /remove:g "FIDENSLAT\Domain Admins"
icacls C:\ProgramData\ssh_modern\etc\sshd_config

icacls C:\ProgramData\ssh_modern\etc\authorized_keys /inheritance:r
icacls C:\ProgramData\ssh_modern\etc\authorized_keys /grant "SYSTEM:(F)"
icacls C:\ProgramData\ssh_modern\etc\authorized_keys /grant "ADMINISTRATORS:(F)"
icacls C:\ProgramData\ssh_modern\etc\authorized_keys /grant "NT SERVICE\sshd_modern:(RX)"
icacls C:\ProgramData\ssh_modern\etc\authorized_keys /setowner "SYSTEM"
icacls C:\ProgramData\ssh_modern\etc\authorized_keys

icacls C:\ProgramData\ssh_modern\etc\authorized_keys\psilva /inheritance:r
icacls C:\ProgramData\ssh_modern\etc\authorized_keys\psilva /grant "SYSTEM:(F)"
icacls C:\ProgramData\ssh_modern\etc\authorized_keys\psilva /grant "NT SERVICE\sshd_modern:(RX)"
#icacls C:\ProgramData\ssh_modern\etc\authorized_keys\psilva /grant "SRV_REPLICA-01\psilva:(R)"
icacls C:\ProgramData\ssh_modern\etc\authorized_keys\psilva

icacls C:\ProgramData\ssh_modern\keyhost /inheritance:r
icacls C:\ProgramData\ssh_modern\keyhost /grant "SYSTEM:(F)"
icacls C:\ProgramData\ssh_modern\keyhost /remove:g "ADMINISTRATORS"
icacls C:\ProgramData\ssh_modern\keyhost /remove:g "SRV-REPLICA-01\Administrator"
icacls C:\ProgramData\ssh_modern\keyhost /setowner "SYSTEM"
icacls C:\ProgramData\ssh_modern\keyhost

# Generar llaves en la ruta 100% probado, primero eliminar las existentes revisar en lineas mas abajo
takeown /F "C:\ProgramData\ssh_modern\keyhost" /R /D Y
icacls "C:\ProgramData\ssh_modern\keyhost" /reset /T
icacls "C:\ProgramData\ssh_modern\keyhost" /setowner "Administrator" /T /C

# Remover llaves revisar en lineas mas abajo
Remove-Item "C:\ProgramData\ssh_modern\keyhost\ssh_host_*"

$path = "C:\ProgramData\ssh_modern\keyhost"
ssh-keygen.exe -t ed25519 -f "$path\ssh_host_ed25519_key"
ssh-keygen.exe -t ecdsa   -f "$path\ssh_host_ecdsa_key"  
ssh-keygen.exe -t rsa     -f "$path\ssh_host_rsa_key" 

icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key /inheritance:r
icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key /grant "SYSTEM:(F)"
icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key /setowner "SYSTEM"
icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key /remove:g "ADMINISTRATORS"
icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key
icacls "$path\ssh_host_*" /grant "NT SERVICE\sshd_modern:(R)"

icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key.pub /inheritance:r
icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key.pub /grant "SYSTEM:(F)"
icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key.pub /grant "ADMINISTRATORS:(F)"
icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key.pub /grant "USERS:(R)"
icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key.pub /setowner "SYSTEM"
icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key.pub

icacls C:\ProgramData\ssh_modern\logs /inheritance:r
icacls C:\ProgramData\ssh_modern\logs /grant "SYSTEM:(F)"
icacls C:\ProgramData\ssh_modern\logs /grant "ADMINISTRATORS:(F)"
icacls C:\ProgramData\ssh_modern\logs /grant "NT SERVICE\sshd_modern:(W)"
icacls C:\ProgramData\ssh_modern\logs /remove:g "FIDENSLAT\Domain Admins"
icacls C:\ProgramData\ssh_modern\logs /setowner "SYSTEM"
icacls C:\ProgramData\ssh_modern\logs

icacls D:\SFTP_MODERN /inheritance:r
icacls D:\SFTP_MODERN /grant "SYSTEM:(F)"
icacls D:\SFTP_MODERN /grant "ADMINISTRATORS:(F)"
icacls D:\SFTP_MODERN /remove:g "FIDENSLAT\Domain Admins"
icacls D:\SFTP_MODERN /setowner "ADMINISTRATORS"
icacls D:\SFTP_MODERN

icacls D:\SFTP_MODERN\WORK /inheritance:r
icacls D:\SFTP_MODERN\WORK /grant "SYSTEM:(F)"
icacls D:\SFTP_MODERN\WORK /grant "ADMINISTRATORS:(F)"
# icacls D:\SFTP_MODERN\WORK /grant "NT SERVICE\sshd_modern:(RX)"
icacls D:\SFTP_MODERN\WORK /remove:g "FIDENSLAT\Domain Admins"
icacls D:\SFTP_MODERN\WORK /remove "NT SERVICE\sshd_modern"
icacls D:\SFTP_MODERN\WORK /setowner "ADMINISTRATORS"
icacls D:\SFTP_MODERN\WORK

# Primero eliminar todos los permisos
takeown /F "D:\SFTP_MODERN\WORK\psilva" /R /D Y
icacls "D:\SFTP_MODERN\WORK\psilva" /reset /t
icacls "D:\SFTP_MODERN\WORK\psilva" /inheritance:r /grant:r SYSTEM:F /t
icacls "D:\SFTP_MODERN\WORK\psilva" /remove:g *S-1-1-0 /t

icacls D:\SFTP_MODERN\WORK\psilva /setowner "SYSTEM"
icacls D:\SFTP_MODERN\WORK\psilva /inheritance:r
icacls D:\SFTP_MODERN\WORK\psilva /grant:r "SYSTEM:(F)"
icacls D:\SFTP_MODERN\WORK\psilva /grant:r "ADMINISTRATORS:(F)"
#icacls D:\SFTP_MODERN\WORK\psilva /grant "NT SERVICE\sshd_modern:(RX)"
#icacls D:\SFTP_MODERN\WORK\psilva /grant "psilva:(RX)"
icacls D:\SFTP_MODERN\WORK\psilva

icacls D:\SFTP_MODERN\WORK\psilva\data /inheritance:r
icacls D:\SFTP_MODERN\WORK\psilva\data /grant:r "psilva(OI)(CI)(M)"
icacls D:\SFTP_MODERN\WORK\psilva\data /grant:r "SYSTEM:(OI)(CI)(RX)"
icacls D:\SFTP_MODERN\WORK\psilva\data /grant "ADMINISTRATORS:(OI)(CI)(RX)"
icacls D:\SFTP_MODERN\WORK\psilva\data

# Chequeo inmediato
Unblock-File "C:\OpenSSH-Modern\OpenSSH-Win64\sftp-server.exe"
Unblock-File "C:\OpenSSH-Modern\OpenSSH-Win64\ssh.exe"
Unblock-File "C:\OpenSSH-Modern\OpenSSH-Win64\sshd.exe"
Unblock-File "C:\OpenSSH-Modern\OpenSSH-Win64\ssh-keygen.exe"
#Luego
Get-AuthenticodeSignature "C:\OpenSSH-Modern\OpenSSH-Win64\sshd.exe"

Get-Content -Path "C:\ProgramData\ssh_modern\logs\sshd.log" -Tail 20


Si no levanta
Start-Process -FilePath "C:\OpenSSH-Modern\OpenSSH-Win64\sshd.exe" -ArgumentList "-ddd" -NoNewWindow
# Verificar si powershell esta elevado debe dar True
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

icacls "C:\OpenSSH-Modern" /grant "Administrators:(OI)(CI)(F)" /t
icacls "C:\OpenSSH-Modern" /grant "SYSTEM:(OI)(CI)(F)" /t

# Desbloquear si copiaste o descargaste
Get-ChildItem "C:\OpenSSH-Modern\OpenSSH-Win64" -Recurse | Unblock-File

# Ejecucion directa en consola
C:\OpenSSH-Modern\OpenSSH-Win64\sshd.exe -ddd


# Detengo y elimino el servicio defectuoso
Stop-Service sshd_modern -Force
sc.exe stop sshd_modern
sc.exe delete sshd_modern
sc.exe delete sshd_modern
# Creo el servicio correctamente usando CMD como Administrator
sc.exe create sshd_modern binPath= "\"C:\OpenSSH-Modern\OpenSSH-Win64\sshd.exe\" -f \"C:\ProgramData\ssh_modern\etc\sshd_config\" -D" DisplayName= "OpenSSH Modern (10.0.p2)" start= auto obj= "LocalSystem"

sc config sshd_modern binPath= "\"C:\OpenSSH-Modern\OpenSSH-Win64\sshd.exe\" -f \"C:\ProgramData\ssh_modern\etc\sshd_config\""

# Nuevo creacion del servicio
sc.exe create sshd_modern ^
binPath= "C:\OpenSSH-Modern\OpenSSH-Win64\sshd.exe -f C:\ProgramData\ssh_modern\etc\sshd_config -D" ^
DisplayName= "OpenSSH Modern (10.0.p2)" ^
start= auto obj= LocalSystem

Revisar version en cmd
"C:\OpenSSH-Modern\OpenSSH-Win64\ssh.exe" -V


icacls C:\OpenSSH-Modern          # Solo SYSTEM y ADMINISTRATORS FULL
icacls C:\OpenSSH-Modern\OpenSSH-Win64
icacls C:\ProgramData\ssh_modern\etc
icacls C:\ProgramData\ssh_modern\etc\sshd_config
icacls C:\ProgramData\ssh_modern\etc\authorized_keys
icacls C:\ProgramData\ssh_modern\etc\authorized_keys\psilva
icacls C:\ProgramData\ssh_modern\keyhost
icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key
icacls C:\ProgramData\ssh_modern\keyhost\ssh_host_*_key.pub
icacls C:\ProgramData\ssh_modern\logs
icacls D:\SFTP_MODERN
icacls D:\SFTP_MODERN\WORK
icacls D:\SFTP_MODERN\WORK\psilva
icacls D:\SFTP_MODERN\WORK\psilva\data

#Paquete oficial de Visul C++ redist.x64
https://aka.ms/vs/17/release/vc_redist.x64.exe
# Buscar dll faltantes con PS
gci "C:\Windows\System32" -Filter "vcruntime140*.dll"
gci "C:\Windows\System32" -Filter "msvcp140*.dll"
gci "C:\Windows\System32" -Filter "concrt140*.dll"



# Checklist
# Verifica que el archivo exista y tenga contenido
Test-Path "C:\ProgramData\ssh_modern\etc\authorized_keys\psilva"
# Verifica que tenga contenido y no saltos de línea extra
Get-Content "C:\ProgramData\ssh_modern\etc\authorized_keys\psilva"
# Si hay saltos de linea corregir con
(Get-Content "C:\ProgramData\ssh_modern\etc\authorized_keys\psilva" | Out-String).Replace("`r", "") | Set-Content "C:\ProgramData\ssh_modern\etc\authorized_keys\psilva" -NoNewline

# Permisos de authorized_keys y carpeta
# Carpeta etc
icacls "C:\ProgramData\ssh_modern\etc"
# Archivo de la clave
icacls "C:\ProgramData\ssh_modern\etc\authorized_keys\psilva"
# Debe incluir:
# NT SERVICE\sshd_modern: RX (lectura/ejecución)
# BUILTIN\Administrators: F
# NT AUTHORITY\SYSTEM: F


# ELIMINAR LAS LLAVES
# 1. Primero tomar propiedad sobre la carpeta y los archivos privados
takeown /F "C:\ProgramData\ssh_modern\keyhost\ssh_host_ed25519_key"
takeown /F "C:\ProgramData\ssh_modern\keyhost\ssh_host_ecdsa_key"
takeown /F "C:\ProgramData\ssh_modern\keyhost\ssh_host_rsa_key"

takeown /F "C:\ProgramData\ssh_modern\keyhost" /R /D Y
icacls "C:\ProgramData\ssh_modern\keyhost" /grant administrators:F /T
icacls "C:\ProgramData\ssh_modern\keyhost" /setowner "Administrators" /T /C
icacls "C:\ProgramData\ssh_modern\keyhost" /reset /T
# 2 Remover llaves
Remove-Item "C:\ProgramData\ssh_modern\keyhost\ssh_host_*" -Force
# 3 Verificar que quedo vacia
gci "C:\ProgramData\ssh_modern\keyhost"
# 4 Generar llaves en la ruta 100% probado
$keyGen = "C:\OpenSSH-Modern\OpenSSH-Win64\ssh-keygen.exe"
$path = "C:\ProgramData\ssh_modern\keyhost"
& $keyGen -t ed25519 -f "$path\ssh_host_ed25519_key"
& $keyGen -t ecdsa   -f "$path\ssh_host_ecdsa_key"  
& $keyGen -t rsa     -f "$path\ssh_host_rsa_key"

# REVISAR QUIEN ES EL OWNER DE ARCHIVO
(Get-Acl "C:\ProgramData\ssh_modern\keyhost\ssh_host_ed25519_key").Owner

Arranque manual del binario
cd "C:\OpenSSH-Modern\OpenSSH-Win64"
.\sshd.exe -f C:\ProgramData\ssh_modern\etc\sshd_config -D

# Verificacion con las claves del keyhost
cd C:\OpenSSH-Modern\OpenSSH-Win64
.\sshd.exe -T -f C:\ProgramData\ssh_modern\etc\sshd_config | findstr hostkey

# Luego puedo ver la fingerprint con
ssh-keygen -lf C:\ProgramData\ssh_modern\keyhost\ssh_host_ed25519_key.pub

Remove-Item "C:\Windows\System32\config\systemprofile\.ssh\known_hosts"

ssh -i C:/Users/lvill/.ssh/psilva -p 2222 psilva@10.0.0.53 -vvv

# ELIMINAR LLAVE psilva
Remove-Item "C:\ProgramData\ssh_modern\etc\Authorized_keys\psilva" -Force
# 2 Generar llaves en la ruta 100% probado
$keyGen = "C:\OpenSSH-Modern\OpenSSH-Win64\ssh-keygen.exe"
$pathOut = "C:\infraestructura\keys"
& $keyGen -t ed25519 -C "psilva@SRV-REPLICA-01" -f "$pathOut\psilva"
# 3 Registrar la llave publica (pub) en C:\ProgramData\ssh_modern\etc\authorized_keys con el nombre psilva sin extensión
Get-Content "C:\infraestructura\keys\psilva.pub" | Out-File -Append "C:\ProgramData\ssh_modern\etc\authorized_keys\psilva" -Encoding ascii
# 4 Verificar contenido
type C:\ProgramData\ssh_modern\etc\authorized_keys\psilva
# 5 La llave privada se envia al pc remoto que accederá
# 6 Permisos para pub psilva
icacls C:\ProgramData\ssh_modern\etc\authorized_keys\psilva
(Get-Acl C:\ProgramData\ssh_modern\etc\authorized_keys\psilva).Owner


netstat -ano | findstr ":2222"
TCP    0.0.0.0:2222           0.0.0.0:0              LISTENING       10516
TCP    [::]:2222              [::]:0                 LISTENING       10516

netstat -ano | findstr ":10021"
TCP    0.0.0.0:10021          0.0.0.0:0              LISTENING       3708
TCP    10.0.0.53:10021        52.190.44.200:22656    ESTABLISHED     3708
TCP    10.0.0.53:10021        152.230.27.218:60773   ESTABLISHED     3708
TCP    10.0.0.53:10021        152.230.27.218:65053   ESTABLISHED     3708
TCP    10.0.0.53:10021        172.172.102.135:44534  ESTABLISHED     3708
TCP    [::]:10021             [::]:0                 LISTENING       3708

tasklist /FI "PID eq 7180"
tasklist /FI "PID eq 3708"

(Get-Process -Id 7180).Path

Stop-Service sshd_modern
sc.exe delete sshd_modern

New-Service `
    -Name sshd_modern `
    -DisplayName "OpenSSH Modern" `
    -BinaryPathName '"C:\OpenSSH-Modern\OpenSSH-Win64\sshd.exe" -f "C:\ProgramData\ssh_modern\etc\sshd_config"' `
    -StartupType Automatic

# Opcion B
$bin = '"C:\OpenSSH-Modern\OpenSSH-Win64\sshd.exe" -f "C:\ProgramData\ssh_modern\etc\sshd_config"'
New-Service -Name sshd_modern -DisplayName "OpenSSH Modern" -BinaryPathName $bin -StartupType Automatic

Start-Service sshd_modern

tasklist | findstr sshd

reg query "HKLM\SYSTEM\CurrentControlSet\Services\sshd_modern" /v ImagePath

ssh -p 2222 -vvv localhost


# Detengo ambos servicios 
Stop-Service sshd -Force
Stop-Service sshd_modern -Force
# Confirmado que no hay servicios sshd activos
taskkill /IM sshd.exe /F
# Puerto libre
netstat -ano | findstr ":2222"
# Arranco solo el moderno
Start-Service sshd_modern
tasklist /FI "PID eq 8136"
(Get-Process -Id 8136).Path

# Validando Servidor
ssh -p 2222 -vvv localhost

# Validando en Cliente
ssh -vvv -p 2222 -i C:\Users\lvill\.ssh\psilva psilva@10.0.0.53
ssh -i C:/Users/lvill/.ssh/psilva -p 2222 psilva@10.0.0.53 -vvv


sftp -i C:\Users\lvill\.ssh\psilva -P 2222 psilva@10.0.0.53
sftp -P 2222 psilva@10.0.0.53

takeown /F "D:\SFTP_MODERN\WORK\psilva" /R /D Y
icacls "D:\SFTP_MODERN\WORK\psilva" /grant administrators:F /T
icacls "D:\SFTP_MODERN\WORK\psilva" /inheritance:r
icacls "D:\SFTP_MODERN\WORK\psilva" /setowner psilva
icacls "D:\SFTP_MODERN\WORK\psilva" /grant "psilva:(OI)(CI)(F)"
icacls "D:\SFTP_MODERN\WORK\psilva" /remove:g "SYSTEM"
icacls "D:\SFTP_MODERN\WORK\psilva" /remove:g "Administrators"


(Get-Acl D:\SFTP_MODERN\WORK).Owner
(Get-Acl D:\SFTP_MODERN\WORK\psilva 2>$null)


ssh -vvv -i C:\Users\lvill\.ssh\psilva -p 2222 psilva@10.0.0.53

ssh -i C:\Users\lvill\.ssh\psilva -p 2222 -vvv psilva@10.0.0.53 2>&1 | ForEach-Object {
    if ($_ -match "Remote protocol version") { "Servidor SSH: $($_ -replace 'debug1: ', '')" }
    if ($_ -match "SFTP protocol version") { "Protocolo SFTP: $($_ -replace 'debug1: ', '')" }
    if ($_ -match "host key algorithms") { "Algoritmos host key: $($_ -replace 'debug2: ', '')" }
    if ($_ -match "ciphers ctos") { "Cifrado cliente->servidor: $($_ -replace 'debug2: ', '')" }
    if ($_ -match "ciphers stoc") { "Cifrado servidor->cliente: $($_ -replace 'debug2: ', '')" }
    if ($_ -match "MACs ctos") { "MAC cliente->servidor: $($_ -replace 'debug2: ', '')" }
    if ($_ -match "MACs stoc") { "MAC servidor->cliente: $($_ -replace 'debug2: ', '')" }
    if ($_ -match "Authen") { "Métodos de autenticación: $($_ -replace 'debug1: Authentications that can continue: ', '')" }
}

# Similar a la anterior pero mas resumida
ssh -i C:\Users\lvill\.ssh\psilva -p 2222 -vvv psilva@10.0.0.53 2>&1 | ForEach-Object {
    if ($_ -match "Remote protocol version") { $_ -replace "debug1: ", "" | Write-Host }
    if ($_ -match "SFTP protocol version") { $_ -replace "debug1: ", "" | Write-Host }
    if ($_ -match "ciphers ctos") { "Cifrado cliente->servidor: $($_ -replace 'debug2: ciphers ctos: ', '')" | Write-Host }
    if ($_ -match "ciphers stoc") { "Cifrado servidor->cliente: $($_ -replace 'debug2: ciphers stoc: ', '')" | Write-Host }
    if ($_ -match "MACs ctos") { "MAC cliente->servidor: $($_ -replace 'debug2: MACs ctos: ', '')" | Write-Host }
    if ($_ -match "MACs stoc") { "MAC servidor->cliente: $($_ -replace 'debug2: MACs stoc: ', '')" | Write-Host }
    if ($_ -match "Authen") { "Autenticación permitida: $($_ -replace 'debug1: Authentications that can continue: ', '')" | Write-Host }
}


# Version tipo tabla resumida
# Ejecutar SSH en modo verbose y extraer solo lo relevante para la tabla
$info = ssh -i C:\Users\lvill\.ssh\psilva -p 2222 -vvv psilva@10.0.0.53 2>&1
# Extraer y convertir a string
$serverVersion = ($info | Select-String "Remote protocol version").Line -replace "debug1: ", ""
$sftpVersion = ($info | Select-String "SFTP protocol version").Line -replace "debug1: ", ""
$ctosCipher = ($info | Select-String "ciphers ctos").Line -replace "debug2: ciphers ctos: ", "" -replace "\s+", ", "
$stocCipher = ($info | Select-String "ciphers stoc").Line -replace "debug2: ciphers stoc: ", "" -replace "\s+", ", "
$ctosMac = ($info | Select-String "MACs ctos").Line -replace "debug2: MACs ctos: ", "" -replace "\s+", ", "
$stocMac = ($info | Select-String "MACs stoc").Line -replace "debug2: MACs stoc: ", "" -replace "\s+", ", "
$authMethods = ($info | Select-String "Authentications that can continue").Line -replace "debug1: Authentications that can continue: ", "" -replace "\s+", ", "

# Crear objeto resumido
[PSCustomObject]@{
    Servidor         = $serverVersion
    "SFTP v."        = $sftpVersion
    "Cifrado C->S"   = $ctosCipher
    "Cifrado S->C"   = $stocCipher
    "MAC C->S"       = $ctosMac
    "MAC S->C"       = $stocMac
    "Auth Permitida" = $authMethods
} | Format-Table -AutoSize




psexec64 -i -s cmd.exe
New-LocalUser -Name "carga_cia_bci_2222" -NoPassword
Add-LocalGroupMember -Group "sftp-users" -Member "carga_cia_bci_2222"
Get-LocalGroupMember -Group "sftp-users"
$keyGen = "C:\OpenSSH-Modern\OpenSSH-Win64\ssh-keygen.exe"
$pathOut = "C:\infraestructura\keys"
& $keyGen -t ed25519 -C "carga_cia_bci_2222@SRV-REPLICA-01" -f "$pathOut\carga_cia_bci_2222"
# 3 Registrar la llave publica (pub) en C:\ProgramData\ssh_modern\etc\authorized_keys con el nombre psilva sin extensión
Get-Content "C:\infraestructura\keys\carga_cia_bci_2222.pub" | Out-File -Append "C:\ProgramData\ssh_modern\etc\authorized_keys\carga_cia_bci_2222" -Encoding ascii
# 4 Verificar contenido
type C:\ProgramData\ssh_modern\etc\authorized_keys\carga_cia_bci_2222
# 5 La llave privada se envia al pc remoto que accederá
# 6 Permisos para pub carga_cia_bci_2222
icacls C:\ProgramData\ssh_modern\etc\authorized_keys\carga_cia_bci_2222
(Get-Acl C:\ProgramData\ssh_modern\etc\authorized_keys\carga_cia_bci_2222).Owner

mkdir D:\SFTP_MODERN\WORK\carga_cia_bci_2222\upload
icacls D:\SFTP_MODERN\WORK\carga_cia_bci_2222\upload /inheritance:r
icacls D:\SFTP_MODERN\WORK\carga_cia_bci_2222\upload /grant:r "carga_cia_bci_2222:(OI)(CI)(M)"
icacls D:\SFTP_MODERN\WORK\carga_cia_bci_2222\upload /grant:r "SYSTEM:(OI)(CI)(RX)"
icacls D:\SFTP_MODERN\WORK\carga_cia_bci_2222\upload /grant "ADMINISTRATORS:(OI)(CI)(RX)"
icacls D:\SFTP_MODERN\WORK\carga_cia_bci_2222\upload

takeown /F "D:\SFTP_MODERN\WORK\carga_cia_bci_2222" /R /D Y
icacls "D:\SFTP_MODERN\WORK\carga_cia_bci_2222" /grant administrators:F /T
icacls "D:\SFTP_MODERN\WORK\carga_cia_bci_2222" /inheritance:r
icacls "D:\SFTP_MODERN\WORK\carga_cia_bci_2222" /setowner carga_cia_bci_2222
icacls "D:\SFTP_MODERN\WORK\carga_cia_bci_2222" /grant "carga_cia_bci_2222:(OI)(CI)(F)"
icacls "D:\SFTP_MODERN\WORK\carga_cia_bci_2222" /remove:g "SYSTEM"
icacls "D:\SFTP_MODERN\WORK\carga_cia_bci_2222" /remove:g "Administrators"

(Get-Acl D:\SFTP_MODERN\WORK).Owner
(Get-Acl D:\SFTP_MODERN\WORK\carga_cia_bci_2222 2>$null)

sftp -i C:\Users\lvill\.ssh\carga_cia_bci_2222 -P 2222 carga_cia_bci_2222@10.0.0.53