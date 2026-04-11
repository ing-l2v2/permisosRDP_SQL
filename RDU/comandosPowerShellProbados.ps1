Add-LocalGroupMember -Group "Administrators" -Member "FIDENSLAT\kcuenca"
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "FIDENSLAT\jtoledo"

Add-LocalGroupMember -Group "Administrators" -Member ".\kcuenca"
Add-LocalGroupMember -Group "Remote Desktop Users" -Member ".\kcuenca"

Remove-LocalGroupMember -Group "Administrators" -Member "FIDENSLAT\kcuenca"
Remove-LocalGroupMember -Group "Remote Desktop Users" -Member "FIDENSLAT\jtoledo"

Remove-LocalGroupMember -Group "Administrators" -Member ".\kcuenca"
Remove-LocalGroupMember -Group "Remote Desktop Users" -Member ".\kcuenca"

net localgroup Administrators "FIDENSLAT\kcuenca" /add
net localgroup "Remote Desktop Users" "FIDENSLAT\kcuenca" /add

net localgroup Administrators .\kcuenca /add
net localgroup "Remote Desktop Users" .\kcuenca /add

# Politicas endurecidas equipos antiguos 2008/2012 sin modulo LocalAccounts ([ADSI])
#Administrators
$group = [ADSI]"WinNT://$env:COMPUTERNAME/Administrators,group"
$group.Add("WinNT://NOMBRE_DOMINIO/usuario,user")
# Remote Desktop Users
$group = [ADSI]"WinNT://$env:COMPUTERNAME/Remote Desktop Users,group"
$group.Add("WinNT://NOMBRE_DOMINIO/usuario,user")

# Verificar que el usuario fue asignado
#Windows 2012+
Get-LocalGroupMember -Group "Administrators"
Get-LocalGroupMember -Group "Remote Desktop Users"
#Windows 2008