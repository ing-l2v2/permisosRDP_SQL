param(
  [string]$Servidor,       # Ej: sql-ginger.database.windows.net
  [Parameter(Mandatory = $true)]
  [string]$BaseDatoIn,       # Nombre de la BD en Azure
  [string]$Usr,            # Usuario que recibirá permisos
  [ValidateSet("R", "W", "RW", "SP", "SM", "PRF", "ALL")]
  [string]$TipoAcceso,
  [int]$NumReg,
  [string]$CodUser,
  [string]$Expira
  #[string]$PasswordUsuario # Solo si hay que crearlo
)

$BaseDato = $BaseDatoIn -split ","
<#
Write-Host "BDS RECIBIDAS:"
$BaseDato | ForEach-Object { Write-Host $_ }

Write-Host "BDS RECIBIDAS:"
foreach ($bdIn in $BaseDato) {
  Write-Host " - $bdIn"
}
#>

Write-Host "COUNT = $($BaseDato.Count)"

Import-Module SqlServer

Write-Host "== Asignando permisos en Azure SQL ==" -ForegroundColor Cyan
Write-Host "Servidor: $Servidor    Bases: $($BaseDato -join " ")"  -ForegroundColor Cyan
Write-Host "Usuario: $Usr    Tipo: $TipoAcceso    NumReg: $NumReg    CodUser: $CodUser    Expira: $Expira"  -ForegroundColor Cyan
Write-Host "------------------------------------------"  -ForegroundColor Cyan

$roles = switch ($TipoAcceso) {
  "R" { @("db_datareader") }
  "W" { @("db_datawriter") }
  "RW" { @("db_datareader", "db_datawriter") }
  "SP" { @("EXECUTE") }
  "SM" { @("ALTER", "CREATE TABLE", "VIEW DEFINITION") }
  "PRF" { @("VIEW DATABASE STATE") }
  "ALL" { @("db_owner") }
}

# ==========================================================
# CONFIGURACION LOG
# ==========================================================
$LogDir = ".\reportes\azure"
$LogFile = "$LogDir\sqlAzAdd.txt"
if (!(Test-Path $LogDir)) {
  New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
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
      if (!(Test-Path $LogFile)) {
        Set-Content -Path $LogFile -Value $linea
        return
      }
      # leer contenido actual
      $contenido = Get-Content $LogFile -ErrorAction Stop
      # insertar arriba
      $nuevo = @($linea) + $contenido
      # escribir nuevamente
      Set-Content -Path $LogFile -Value $nuevo -ErrorAction Stop
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
Write-AzureLog ".\sqlAzAdd.ps1 -Servidor `"$Servidor`" -BaseDato `"$($BaseDato -join '" "')`" -Usr `"$Usr`" -TipoAcceso `"$TipoAcceso`" -NumReg `"$NumReg`" -CodUser `"$CodUser`" "
Write-AzureLog  "`$Lista = `@( `"$($BaseDato -join '" "')`" )" 
#====================================================
#  PROCESAR UNA O VARIAS BASES DE DATOS
#====================================================
foreach ($bd in $BaseDato) {
  Write-Host "`n>>> Procesando base: $bd" -ForegroundColor Magenta

  # Conexión
  $Conn = "Server=tcp:$Servidor,1433;Database=$bd;User ID=csilva;Password=Ohdef_1007;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

  # Crear usuario si no existe en la base
  $Check = @"
  IF NOT EXISTS(SELECT * FROM sys.database_principals WHERE name = '$Usr')
  BEGIN
  --    CREATE USER [$Usr] WITH PASSWORD = 'Temp#12345';
    CREATE USER [$Usr] FOR LOGIN [$Usr];
    SELECT 1;
  END
  ELSE
  BEGIN
    SELECT 2;
  END;
  --SELECT * FROM sys.database_principals WHERE name = '$Usr'
"@


  $usrEstatus = Invoke-Sqlcmd -Query $Check -ConnectionString $Conn
  if ($usrEstatus -eq 1) {
    Write-Host "Usuario $Usr agregado a la base de datos $bd" -ForegroundColor Yellow
  }

  # Aplicar roles según TipoAcceso
  $permisosOk = 0
  foreach ($r in $roles) {
    if ($r -eq "EXECUTE") {
      $sql = "GRANT EXECUTE TO [$Usr]"
    }
    elseif ($r -in @("ALTER", "CREATE TABLE", "VIEW DEFINITION")) {
      $sql = "GRANT $r TO [$Usr]"
    }
    else {
      # Roles nativos
      $sql = "EXEC sp_addrolemember '$r', '$Usr'"
    }
    
    Write-Host "Aplicando: $sql" -ForegroundColor Yellow
    try {
      Invoke-Sqlcmd -Query $sql -ConnectionString $Conn
      Write-Host ">>> Permisos aplicados en $bd" -ForegroundColor Green
      
      Write-AzureLog ".\sqlAzAdd.ps1 -Servidor `"$Servidor`" -BaseDato `"$bd`" -Usr `"$Usr`" -TipoAcceso `"$TipoAcceso`" -NumReg $NumReg -CodUser `"$CodUser`" -Expira `"$Expira`" "  
      $ejecucion = ".\sqlAzAdd.ps1 -Servidor `"$Servidor`" -BaseDato `"$bd`" -Usr `"$Usr`" -TipoAcceso `"$TipoAcceso`" -NumReg $NumReg -CodUser `"$CodUser`" -Expira `"$Expira`" "

    }
    catch {
      Write-Host "Permiso no fue asignado por ausencia de base $bd, error en catch" -ForegroundColor Magenta
      $permisosOk = 1
      continue
    }
  }
  if ($permisosOk -eq 0) {
    Write-Host "`nPermisos asignados exitosamente en todas las bases." -ForegroundColor Cyan

    $serv102 = "10.0.0.102"
    $serv49 = "10.0.0.49"
    $user = "lvilla"
    $pass = "lv..2021"
    $pass49 = "L2v2..20&25.#"
    $database = "ProyFidens"
    $database49 = "master"
    $connString102 = "Server=$serv102;Database=$database;User ID=$user;Password=$pass;TrustServerCertificate=True;"
    $connString49 = "Server=$serv49;Database=$database49;User ID=$user;Password=$pass49;TrustServerCertificate=True;"
    # Si es un exito verificar si existe duplicado ASIGNADO con mismo servidor, base, usuario y tipoacceso
    $query49 = @"
        SELECT TOP 1 IdAzure, Servidor, Usuario, PermisoAsignado, BaseDatos, Estado, Expira, NumReg, CodUser 
        FROM master.dbo.infraAccesosAzure
        WHERE Servidor = '$Servidor'
        AND Usuario = '$Usr'
        AND BaseDatos = '$bd'
        AND PermisoAsignado = '$TipoAcceso'
        AND Estado = 'ASIGNADO'
        ORDER BY Estado ASC;
"@
    Write-Host $query49
    $asignadosPrev = Invoke-Sqlcmd -Query $query49 -ConnectionString $connString49
    #Write-Host "Tipo devuelto:" $asignadosPrev.GetType().FullName
    #Write-Host "Cantidad registros:" $asignadosPrev.Count
    if ($null -eq $asignadosPrev -or $asignadosPrev.Count -eq 0) {
      Write-Host "No hay presencia de permisos previos o duplicados" -ForegroundColor Blue
    }
    else {
      Write-Host "Actualizando en 49 REVOCADO a previos o duplicados" -ForegroundColor Blue
      $prevNumReg = $asignadosPrev["NumReg"]
      $prevCodUser = $asignadosPrev["CodUser"]
      $prevCodUser = $prevCodUser -replace "'", "''"
      $prevExpira = $asignadosPrev["Expira"]
      # Al existir ubicarlo en finalizado en 102 el duplicado
      $sqlDelDupli49 = @"
    UPDATE master.dbo.infraAccesosAzure
        SET Estado = 'REVOCADO', Revocado = GETDATE(), Observacion='FORZADO REVOCADO'
        WHERE NumReg = $prevNumReg;
    SELECT * FROM master.dbo.infraAccesosAzure WHERE NumReg = $prevNumReg;
"@        
      Write-Host $sqlDelDupli49
      $revocadoDupli49 = Invoke-Sqlcmd -Query $sqlDelDupli49 -ConnectionString $connString49
      if ($null -eq $revocadoDupli49 -or $revocadoDupli49.Count -eq 0) {
        Write-Host "No se revoco nada del 49 por duplicidad."
      }

      $sqlPrevRev102 = @"
        SELECT TOP 1 AAC_IDENAAC AS NUMREG, AGE_SEG_CODIGO AS CODUSER, SRV.ASE_IPPRIVADA AS IPPRIV,
      SRV.ASE_DESCRIPCION AS SERVERNAME, LOWER(USR.TXT_ACC) AS USUARIO, CTA.ADM_IDPROY AS IDBD,
      CTA.AAC_PERSMISO AS PERMISO,
        CASE
            WHEN ISDATE(CONVERT(varchar(10), CTA.ACC_FECHAFIN, 120) + ' ' + CTA.ACC_HORAFIN) = 1
            THEN CONVERT(datetime, CONVERT(varchar(10), CTA.ACC_FECHAFIN, 120) + ' ' + CTA.ACC_HORAFIN)
            ELSE NULL
        END AS EXPIRA,
      CTA.ESTADO
    FROM ProyFidens.dbo.ADM_ACTIVACION_CUENTA CTA
    INNER JOIN ProyFidens.dbo.SYS_ACCOUNT USR ON CTA.AGE_SEG_CODIGO=USR.COD_USER AND USR.STATUS=1
    INNER JOIN ProyFidens.dbo.ADM_SERVIDOR SRV ON CTA.ASE_IDENASE=SRV.ASE_IDENASE AND SRV.ASE_ESTADO=1
    WHERE LOWER(USR.TXT_ACC) = '$Usr'
    AND AAC_IDENAAC < $NumReg
    AND AAC_PERSMISO LIKE '%SQL%'
    AND SRV.ASE_DESCRIPCION LIKE 'sql-ginger.database.windows.net'
    ORDER BY AAC_IDENAAC DESC;
"@
      Write-Host $sqlPrevRev102
      $finalizadoPrevios = Invoke-Sqlcmd -Query $sqlPrevRev102 -ConnectionString $connString102
      if ($null -eq $finalizadoPrevios) {
        Write-Host "No existió registros por finalizar en 102"
      }
      else {
        $prevNumReg = $finalizadoPrevios["NUMREG"]
        $prevCodUser = $finalizadoPrevios["CODUSER"]

        $sqlFinalDupli102 = @"
  UPDATE ProyFidens.dbo.ADM_ACTIVACION_CUENTA
      SET ESTADO = 3
    WHERE AAC_IDENAAC = $prevNumReg AND ESTADO IN (2,3);
  
    EXEC [ProyFidens].[dbo].[SYS_ADM_EMAIL_SOLICITUD_ACCESO_PRODUCCION] '$prevCodUser', $prevNumReg;

    SELECT * FROM ProyFidens.dbo.ADM_ACTIVACION_CUENTA WHERE AAC_IDENAAC = $prevNumReg;
"@
        Write-Host $sqlFinalDupli102 
        $finalizadoDupli = Invoke-Sqlcmd -Query $sqlFinalDupli102 -ConnectionString $connString102
        if ($null -eq $finalizadoDupli -or $finalizadoDupli.Count -eq 0) {
          Write-Host "No se pudo finalizar en 102 el $prevNumReg" -ForegroundColor Magenta
        }
      }
    }
    # Si no existe o ya se finalizo
    $sql49 = @" 
      INSERT INTO master.dbo.infraAccesosAzure (Servidor, Usuario, TipoAsignacion, PermisoAsignado, BaseDatos, Expira, Estado, NumReg, CodUser, Ejecutar)
      SELECT '$Servidor', '$Usr', 'DB_ROLE', '$TipoAcceso', '$bd', '$Expira', 'ASIGNADO', $NumReg, '$CodUser', '$ejecucion';

      SELECT TOP 1 IdAzure FROM master.dbo.infraAccesosAzure WHERE Servidor = '$Servidor'
        AND Usuario = '$Usr'
        AND BaseDatos = '$bd'
        AND PermisoAsignado = '$TipoAcceso'
        AND Estado = 'ASIGNADO'
        ORDER BY Estado ASC;
"@
    Write-Host $sql49
    $asignados = Invoke-Sqlcmd -Query $sql49 -ConnectionString $connString49
    if (-not $asignados) {
      Write-Host "No se registro como ASIGNADO" -ForegroundColor Magenta
    }
    else {
      $idAzure = $asignados["idAzure"]
      # Asignar el item presente con fecha de expiración
      $sqlEjecutado102 = @"
  UPDATE ProyFidens.dbo.ADM_ACTIVACION_CUENTA
	  SET ESTADO = 2
  WHERE AAC_IDENAAC = $NumReg AND ESTADO = 1;

  EXEC [ProyFidens].[dbo].[SYS_ADM_EMAIL_SOLICITUD_ACCESO_PRODUCCION] '$CodUser', $NumReg;

  SELECT * FROM ProyFidens.dbo.ADM_ACTIVACION_CUENTA WHERE AAC_IDENAAC = $NumReg;
"@
      Write-Host $sqlEjecutado102
      $play102 = Invoke-Sqlcmd -Query $sqlEjecutado102 -ConnectionString $connString102
      if (-not $play102 -or $play102.Count -eq 0) {
        Write-Host "No se pudo Ejecutado en 102 el $NumReg" -ForegroundColor Magenta
      }
      else {
        Write-Host "-----------------------------------------------------------------------------------------------------------" -ForegroundColor Yellow
        Write-Host "    Exito ProyFidens::[$idAzure] Usuario: $Usr    Servidor: $Servidor    BD: $bd" -ForegroundColor Yellow    
        Write-Host "    NumReg: $NumReg    CodUser: $Cod    FechaFin: $Expira" -ForegroundColor Yellow
        Write-Host "-----------------------------------------------------------------------------------------------------------" -ForegroundColor Yellow
      }
    }
  }
  else {
    Write-Host "`nPermisos fallo en al menos una base $bd." -ForegroundColor Magenta
  }
}