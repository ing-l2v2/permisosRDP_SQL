@echo off

set TARGET=C:\permisosRDP_SQL\permisosRDP_SQL.bat
set SHORTCUT=%APPDATA%\Microsoft\Windows\Start Menu\Programs\PermisosRDP_SQL.lnk

powershell "$s=(New-Object -COM WScript.Shell).CreateShortcut('%SHORTCUT%'); $s.TargetPath='%TARGET%'; $s.Save()"

echo Acceso directo creado en el Menu Inicio.
pause