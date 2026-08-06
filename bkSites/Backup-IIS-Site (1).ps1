<#
Backup-IIS-Site.ps1
Versión inicial reutilizable.

Parámetros principales al inicio.
#>

param()

$Site="zenitdesa"
$BackupRoot="C:\Infraestructura"
$WinRAR="C:\Program Files\WinRAR\WinRAR.exe"

Import-Module WebAdministration

$ts=Get-Date -Format "yyyyMMdd_HHmmss"
$Server=$env:COMPUTERNAME
$outDir=Join-Path $BackupRoot "${Site}_${Server}_${ts}"
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$log=Join-Path $outDir "Backup.log"
$appFile=Join-Path $outDir "aplicaciones.txt"
$listFile=Join-Path $outDir "rar_list.txt"
$rar=Join-Path $BackupRoot ("{0}_{1}_{2}.rar"-f $Site,$Server,$ts)

function Log($m){
 $l="{0} {1}"-f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$m
 $l|Tee-Object -FilePath $log -Append
}

if(!(Test-Path $WinRAR)){throw "No existe WinRAR"}

& "$env:windir\System32\inetsrv\appcmd.exe" list app /config /site.name:$Site > $appFile

$content=Get-Content $appFile -Raw
$xml=[xml]("<root>$content</root>")

$set=New-Object 'System.Collections.Generic.HashSet[string]'

foreach($a in $xml.root.application){
 foreach($vd in $a.virtualDirectory){
   $p=$vd.physicalPath
   if([string]::IsNullOrWhiteSpace($p)){continue}
   if(Test-Path $p){
      $null=$set.Add($p)
      Log "Incluye: $p"
   }else{
      Log "No existe: $p"
   }
 }
}

$list=@()
foreach($p in $set){ $list+=$p }
$list|Set-Content $listFile

# Crear rar usando lista de archivos/directorios.
# -ep1 elimina la ruta base almacenada.
# -r recursivo
# -x exclusiones
& $WinRAR a -r -ep1 -ibck -x*temp* -x*upload* -x*.rar -x*.zip $rar "@$listFile"

Log "RAR generado: $rar"
Log "Fin."
