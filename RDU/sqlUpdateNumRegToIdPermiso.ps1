param(
  [int]$IdPermiso,
  [int]$NumReg  
)

$serv49 = "10.0.0.49"
$serv102 = "10.0.0.102"
$repo49 = "master"
$repo102 = "ProyFidens"
$usrSql = "lvilla"
$Pass49 = "L2v2..20&25.#"
$Pass102 = "lv..2021"

Import-Module SqlServer
$Conn49 = "Server=$serv49; Database=$repo49; User ID=$UsrSql; Password=$Pass49; TrustServerCertificate=True;"
$Conn102 = "Server=$serv102; Database=$repo102; User ID=$UsrSql; Password=$Pass102; TrustServerCertificate=True;"

$sql102 = @"
  DECLARE @Numreg INT;
  DECLARE @CodUser VARCHAR(5);
  DECLARE @Expira DATETIME;

  SELECT @NumReg = AAC_IDENAAC, @CodUser = AGE_SEG_CODIGO, 
  @Expira = CONVERT(VARCHAR(10), ACC_FECHAFIN, 120) + ' ' + ACC_HORAFIN 
  FROM ADM_ACTIVACION_CUENTA 
  WHERE AAC_IDENAAC = $NumReg;

  UPDATE ADM_ACTIVACION_CUENTA
    SET ESTADO = 2
    WHERE AAC_IDENAAC = @NumReg;

  EXEC [ProyFidens].[dbo].[SYS_ADM_EMAIL_SOLICITUD_ACCESO_PRODUCCION] @CodUser, @NumReg;

  SELECT @Numreg AS NumReg, @CodUser AS CodUser, @Expira AS Expira;
"@

Write-Host $sql102 -foregroundColor White
$proy = Invoke-Sqlcmd -Query $sql102 -ConnectionString $Conn102
if (-not $proy) {
  Write-Host "Sin resultados en 102.proyFidens para NumReg $NumReg"
}
else {
  foreach ($r in $proy) {
    $NumRegItem = [int]$r["NumReg"]
    $CodUser = $r["CodUser"]
    $Expira = $r["Expira"]
    $sql49 = @"
    UPDATE dbo.infraAccesosTempRDU 
    SET NumReg=$NumRegItem ,
    CodUser='$CodUser', 
    Estado = 'ASIGNADO',
    Revocado = NULL,
    Observacion = NULL,
    Expira='$Expira' 
    WHERE Id=$IdPermiso;  
    SELECT Id FROM dbo.infraAccesosTempRDU;
"@
    Write-Host $sql49 -foregroundColor White
    $rdp = Invoke-Sqlcmd -Query $sql49 -ConnectionString $Conn49
    if (-not $rdp) {
      Write-Host "No se actualizo accesosRDU por falta de id $IdPermiso"
    }
    else {
      Write-Host "Modificacion exitosa!" -ForegroundColor Yellow
    }
  }

}
