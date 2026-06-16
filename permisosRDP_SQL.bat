@echo off
cd /d "c:\permisosRDP_SQL/RDU"

rem Ejecuta tu menuPermisos.ps1 sin bloquear
start "" powershell.exe -ExecutionPolicy Bypass -File "C:\permisosRDP_SQL\RDU\menuPermisos.ps1"

rem Abre una nueva ventana CMD en paralelo, ubicada en tu ruta y lista para usar PowerShell
rem start "" cmd /k "cd /d C:\permisosRDP_SQL\RDU && powershell.exe"
start "" cmd /c "cd /d C:\permisosRDP_SQL\RDU && powershell.exe -NoExit -Command ""function bye { exit }"""