<#
	.\PruebaConexion49.ps1 -Usuario "kikiriqui" `
                           -Servidor "10.0.0.49" `
                           -Grupo "Administrators"
#>
<#
param(
    [string]$Usuario,
    [string]$Servidor,
    [string]$Grupo
)
#>
Import-Module SqlServer

# Conexión con SQL Authentication
<#
$serverSql = "10.0.0.$Servidor"
switch ($Servidor) {
	{$_ -in "49","56","61"} { $Pass = "L2v2..20&25.#" }
	{$_ -in "77","80","86","102"} { $Pass = "lv..2021" }
	{$_ -in "15","36","40","48","54","60","84","87","101","186","198","203"} { $Pass = "lv..2021" }
}
#>
# ==================================================================
# 		CONVERSION A VALOR SQL
# ==================================================================
function ConvertirToValorSql {
    param(
        [Parameter(Mandatory=$false)]
        $Value
    )
    # 		    NULL o vacío
    # ------------------------------------------
    if ($Value -is [System.DBNull] -or $Value -eq $null -or $Value -eq "") { return "NULL" }    
    # BOOL / BIT;    # true → 1    # false → 0
    # ------------------------------------------
    if ($Value -is [bool]) { return ($(if($Value){1}else{0})) }
    # 			INT
    # ------------------------------------------
    if ($Value -is [int] -or $Value -is [long]) { return $Value }
    # 		DECIMAL / FLOAT / NUMÉRICOS
    # ------------------------------------------
    if ($Value -is [double] -or $Value -is [float] -or $Value -is [decimal]) {
        return $Value.ToString().Replace(",",".")  # SQL exige punto
    }
    # 			DATETIME
    # ------------------------------------------    
    if ($Value -is [datetime]) {
        return "'" + $Value.ToString("yyyy-MM-dd HH:mm") + "'"
    }
    # 	STRING — verificar si representa fecha
    # ------------------------------------------
    if ($Value -is [string]) {
        $parsedDate = $null
        if ([datetime]::TryParse($Value, $parsedDate)) {
            return "'" + $parsedDate.ToString("yyyy-MM-dd HH:mm") + "'"
        }
        # No es fecha → tratar como texto
        return "'" + $Value.Replace("'", "''") + "'"
    }
    # Último recurso (otros tipos)
    # ------------------------------------------
    return "'" + $Value.ToString().Replace("'", "''") + "'"
    #return $Value.ToString()
}

$serverSql = "10.0.0.49"
$UserBd = "lvilla"
$Pass = "L2v2..20&25.#"
$Conn = "Server=$serverSql;Database=master;User ID=$UserBD;Password=$Pass;TrustServerCertificate=True;"

# Registrar asignación
# Invoke-Sqlcmd -Query "EXEC rdu_infraRegistrarAsignacionRDU '$Usuario','$ServerSql','$Grupo'" -ConnectionString $Conn
$prueba = Invoke-Sqlcmd -Query "EXEC sp_infra_prueba 100" -ConnectionString $Conn
if (-not $prueba) {
	Write-Host "[$servSqlFidens rdp_add] No hay referencias de solicitados. No se actualiza Estado" -ForegroundColor Yellow
        $FechaUpd = "NULL"
   	$NumReg = "NULL"
	$CodUser = "NULL"
	$Est = "NULL"
} else {	
   	$NumReg = ConvertirToValorSql( $prueba["NumReg"] )
	$CodUser = ConvertirToValorSql( $prueba["CodUser"] )
	$Est = ConvertirToValorSql( $prueba["Est"] )
	$FechaUpd = ConvertirToValorSql( $prueba["FechaFin"] )
	Write-Host "[$serverSql] Revisar el tipo de dato de CodUser $($prueba["CodUser"].GetType().name) " -ForegroundColor Magenta	

	Write-Host "FechaUpd: $FechaUpd, NumReg: $NumReg, CodUser: $CodUser, Est: $Est" -foregroundColor Cyan
		    $SqlProyFidens = @"
EXEC dbo.rdu_infraProyectoFidensRegistrarEstado
	@NumReg = $NumReg,
	@Estado = 3,
	@CodUser = $CodUser,
	@FechaFin = $FechaUpd;
"@
	Write-Host $SqlProyFidens
}

<#
try {
    # $adsi = [ADSI]"WinNT://$Servidor/$Grupo,group"
    # $adsi.Add("WinNT://$Usuario,user")
    Write-Host "Acceso asignado correctamente"
}
catch {
    $msg = $_.Exception.Message.Replace("'", "")
    Invoke-Sqlcmd -Query "
        UPDATE AccesosTemporales 
        SET Estado='ERROR',MensajeError='$msg'
        WHERE Usuario='$Usuario' AND Servidor='$Servidor' AND Grupo='$Grupo' AND Estado='ASIGNADA'
    " -ConnectionString $Conn

    Write-Host "ERROR: $msg" -ForegroundColor Red
}
#>