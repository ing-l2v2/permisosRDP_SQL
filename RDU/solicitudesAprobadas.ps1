<#
Autor: Leonel + ChatGPT  
Script: Generador automático de comandos RDP / SQL
#>

#---------------------------------------------
# CONFIGURACIÓN
#---------------------------------------------
#$server = "10.0.0.102"
#$user = "lvilla"
#$pass = "lv..2021"
#$database = "ProyFidens"
$server = "10.0.0.56"
$user = "lvilla"
$pass = "L2v2..20&25.#"
$database = "ProyFidens"

# Fecha para archivos
$fecha = (Get-Date).ToString("yyyyMMdd")
$inicioProc = Get-Date

# Rutas de salida
$root = ".\reportes"
$salidas = "$root\salidas"
$htmlOut = "$root\permisos_$fecha.html"
$txtOut = "$salidas\rdp_$fecha.txt"

# ==========================================================
# GENERAR ARCHIVOS HTML + CSS + JS
# ==========================================================
# Rutas HTML/CSS/JS
$cssDir = "$root\css"
$jsDir = "$root\js"
$htmlOut = "$root\solicitudesAutorizadas.html"

# Crear carpetas si no existen
foreach ($p in @($root, $salidas)) {
  if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
}

#---------------------------------------------
# CONECTAR A SQL SERVER
#---------------------------------------------
$connectionString = "Server=$server;Database=$database;User ID=$user;Password=$pass;TrustServerCertificate=True;"

$query = @"
SELECT  
    CTA.AAC_IDENAAC AS NRO,
    SRV.ASE_IPPRIVADA AS SERVIDOR,
    CTA.ADM_IDPROY AS BD,
    LOWER(USR.TXT_ACC) AS USR,
    CONVERT(VARCHAR(10), CTA.ACC_FECHAFIN, 120) + ' ' + CTA.ACC_HORAFIN AS FFIN,
    -- CONVERT(VARCHAR(16), CTA.USU_SEG_FECHAINS, 120) AS FREG,
    CTA.AGE_SEG_CODIGO AS COD_USER,
    CTA.ESTADO,
    CTA.AAC_PERSMISO AS PERMISO,

    CASE WHEN LOWER(CTA.AAC_PERSMISO) LIKE '%rdp%' THEN
           CASE WHEN SRV.ASE_IPPRIVADA IN 
                 ('10.0.0.49','10.0.0.56','10.0.0.48','10.0.0.203',
                  '10.0.0.61','10.0.0.77','10.0.0.201')
                  THEN 'FIDENSLAT\' ELSE '.\' END
         ELSE '' END AS DOM,

    CASE WHEN LOWER(CTA.AAC_PERSMISO) LIKE '%rdp%' THEN 1 ELSE 0 END AS RDP,
    CASE WHEN LOWER(CTA.AAC_PERSMISO) LIKE '%sql%' THEN 1 ELSE 0 END AS SQL,
    CASE WHEN LOWER(CTA.AAC_PERSMISO) LIKE '%admin%' THEN 1 ELSE 0 END AS ADM,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
         AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% r %' OR LOWER( CTA.AAC_PERSMISO ) LIKE '%r%' )
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r / w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/ w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r /w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r, w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r,w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rwsp%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w, sp%'
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w, sm%'
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rwsm%'
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw sm%'
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw sp%' THEN 1 ELSE 0 END AS r,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
         AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% w %' OR LOWER( CTA.AAC_PERSMISO ) LIKE '% w %')
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r / w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/ w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r /w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r, w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r,w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rwsp%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w, sp%'
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw sp%' THEN 1 ELSE 0 END AS w,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
           AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% rw %' 
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%rw%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r/w%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r, w%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r,w%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r , w%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r / w%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r/ w%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r /w%')
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rwsp%' 
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rwsm%' 
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw sp%'
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw sm%'
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w, sp%' 
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w, sm%' 
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w sm%'
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w sp%' THEN 1 ELSE 0 END AS rw,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
      AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% sp %' 
      OR LOWER( CTA.AAC_PERSMISO ) LIKE '%sp%' )
      AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rwsp%' 
      AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw sp%'
      AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w, sp%'
      AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w sp%' THEN 1 ELSE 0 END AS sp,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
      AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% rw sp%' 
      OR LOWER( CTA.AAC_PERSMISO ) LIKE '% rwsp%' 
      OR LOWER( CTA.AAC_PERSMISO ) LIKE '%rwsp %'
      OR LOWER(CTA.AAC_PERSMISO) LIKE '%r/w, sp%'
      OR LOWER( CTA.AAC_PERSMISO ) LIKE '% r/w sp %') THEN 1 ELSE 0 END AS rwsp,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
       AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% sp upd%' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% sm %' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% sp modif%') THEN 1 ELSE 0 END AS sm,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
       AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% rw sp upd%' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% rwsp upd %' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% rwsm %' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% rwsp modif %') THEN 1 ELSE 0 END AS rwsm,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
         AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% job%' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% jobs%') THEN 1 ELSE 0 END AS job,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
         AND LOWER( CTA.AAC_PERSMISO ) LIKE '% sysadmin %' THEN 1 ELSE 0 END AS sysad,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
         AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% prf %' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% profil %'
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '%trace%') THEN 1 ELSE 0 END AS prf,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '% owner %' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% propietario %' THEN 1 ELSE 0 END AS own,
    
    CASE WHEN MAIL.consumo=0 THEN '' ELSE MAIL.consumo END AS ath
    
FROM ProyFidens.dbo.ADM_ACTIVACION_CUENTA CTA
JOIN ProyFidens.dbo.SYS_ACCOUNT USR ON CTA.AGE_SEG_CODIGO = USR.COD_USER AND USR.STATUS=1
JOIN ProyFidens.dbo.ADM_SERVIDOR SRV ON CTA.ASE_IDENASE = SRV.ASE_IDENASE AND SRV.ASE_ESTADO=1
LEFT OUTER JOIN master.dbo.infra_auth_email MAIL ON CTA.AGE_SEG_CODIGO=MAIL.coduser_solic     
    AND MAIL.fecha_ins>=DATEADD(MINUTE, -75, GETDATE())
    AND CTA.USU_SEG_FECHAINS BETWEEN DATEADD(MINUTE, -75, MAIL.fecha_correo) AND MAIL.fecha_ins
    AND MAIL.consumo = 1
WHERE CTA.ACC_FECHAFIN >= CAST(GETDATE() AS date)
  AND CTA.ESTADO IN (1)
ORDER BY LOWER(USR.TXT_ACC) ASC, CTA.AAC_IDENAAC ASC
"@

$dt = New-Object System.Data.DataTable
$conn = New-Object System.Data.SqlClient.SqlConnection($connectionString)
$cmd = New-Object System.Data.SqlClient.SqlCommand($query, $conn)
$adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
$adapter.Fill($dt) | Out-Null

#---------------------------------------------
# PROCESAR RESULTADOS Y GENERAR VARIABLES
#---------------------------------------------

$salidasMemoria = @()

# Abrir el archivo UNA sola vez → evita bloqueo de Dropbox
# $sw = New-Object System.IO.StreamWriter($txtOut, $false, [System.Text.Encoding]::UTF8)

# ================================
# PROGRESO + TIEMPO ESTIMADO
# ================================
# $total = $dt.count
$total = $dt.Rows.count
$startTime = Get-Date
$index = 0

foreach ($row in $dt) {

  $index++
  $percent = [math]::Round(($index / $total) * 100, 2)
  # ===== Tiempo estimado =====
  $elapsed = (Get-Date) - $startTime
  if ($percent -gt 0) {
    $remaining = $elapsed.TotalSeconds * (100 - $percent) / $percent
    $eta = [TimeSpan]::FromSeconds($remaining)
    $etaText = "{0:hh\:mm\:ss}" -f $eta
  }
  else {
    $etaText = "Calculando..."
  }
  Write-Progress `
    -Activity "Procesando informe solicitudes aprobadas en AdminFidens" `
    -Status "Progreso: $percent% | ETA: $etaText | Base: $row " `
    -PercentComplete $percent


  $servidor = $row.SERVIDOR
  
  $usr = $row.USR
  $NumReg = $row.NRO
  $CodUser = $row.COD_USER
  $Expira = $row.FFIN
  $bd = $row.BD
  $dom = $row.DOM
  $adm = if ($row.ADM -eq 1) { "ADM" } else { "RDU" }

  #-----------------------------------------
  # RDP
  #-----------------------------------------
  if ($row.RDP -eq 1) {
    $linea = ".\rdpAdd.ps1 $servidor $dom$usr $adm 48 `$null $NumReg"
    # $sw.WriteLine($linea)
    $salidasMemoria += $linea
  }

  #-----------------------------------------
  # SQL – BASE COMÚN
  #-----------------------------------------
  if ($row.SQL -eq 1) {
    $ultimoOcteto = $servidor.Split('.')[3]

    # acceso RW/R/W
    $perm = ""
    if ($row.rwsp -eq 1) { $perm = "RWSP" }
    elseif ($row.rw -eq 1) { $perm = "RW" }
    elseif ($row.r -eq 1) { $perm = "R" }
    elseif ($row.w -eq 1) { $perm = "W" }
    elseif ($row.sp -eq 1) { $perm = "SP" }
    if ($row.rw -eq 0 -and $row.r -eq 1 -and $row.w -eq 1) {
      $row.rw = 1
      $row.r = 0
      $row.w = 0
    }
    if ($row.rwsp -eq 0 -and $row.rw -eq 1 -and $row.sp -eq 1) {
      $row.rwsp = 1
      $row.rw = 0
      $row.sp = 0
    }
    
    if ($perm -ne "") {      
      #$servidor.ToCharArray() | ForEach-Object { "[{0}] {1}" -f $_, ([int][char]$_) }
      # if ($servidor -match "10\s*-" -and $servidor -match "(fidqaclien|fidqa)$") {
      # if ($servidor -match "10\s*-fidqaclien") {      
      if ($servidor -match "^10\s*-") {
        Write-Host "$servidor sqlAzAdd"
        $sql01 = ".sqlAzAdd.ps1 sql-ginger.database.windows.net base-dato $usr $perm $NumReg $CodUser $Expira"
      }
      else {
        $sql01 = ".\sqlAdd.ps1 $ultimoOcteto $usr $perm $bd 48 `$null"
      }
      # $sw.WriteLine($sql01)
      $salidasMemoria += $sql01
    }
    
    if ($row.sm -eq 1) {
      if ($servidor -match "^10\s*-") {
        $s = ".sqlAzAdd.ps1 sql-ginger.database.windows.net base-dato $usr $perm $NumReg $CodUser $Expira"
      }
      else {
        $s = ".\sqlAdd.ps1 $ultimoOcteto $usr SM $bd 48 `$null"
      }
      # $sw.WriteLine($s)
      $salidasMemoria += $s
    }
    
    if ($row.rwsm -eq 1) {
      if ($servidor -match "^10\s*-") {
        $s = ".sqlAzAdd.ps1 sql-ginger.database.windows.net base-dato $usr $perm $NumReg $CodUser $Expira" 
      }
      else {
        $s = ".\sqlAdd.ps1 $ultimoOcteto $usr RWSM $bd 48 `$null"        
      }
      # $sw.WriteLine($s)
      $salidasMemoria += $s
    }

    if ($row.job -eq 1) {
      $s = ".\sqlAdd.ps1 $ultimoOcteto $usr JOB $bd 48 `$null"
      # $sw.WriteLine($s)
      $salidasMemoria += $s
    }

    if ($row.prf -eq 1) {
      $s = ".\sqlAdd.ps1 $ultimoOcteto $usr PRF $bd 48 `$null"
      # $sw.WriteLine($s)
      $salidasMemoria += $s
    }

    if ($row.sysad -eq 1) {
      $s = ".\sqlAdd.ps1 $ultimoOcteto $usr ALL $bd 48 `$null"
      # $sw.WriteLine($s)
      $salidasMemoria += $s
    }

    if ($row.own -eq 1) {
      $s = ".\sqlAdd.ps1 $ultimoOcteto $usr OWN $bd 48 `$null"
      # $sw.WriteLine($s)
      $salidasMemoria += $s
    }
  }
}

# Cerrar barra de progreso
Write-Progress -Activity "Procesando informe solicitudes aprobadas en AdminFidens " -Completed -Status "Completado"

# Cerrar archivo → obligatorio para liberar recurso
# $sw.Close()

# Write-Host "Archivo TXT generado en: $txtOut" -ForegroundColor Cyan
# return $salidasMemoria









# Crear carpetas si no existen
foreach ($p in @($cssDir, $jsDir)) {
  if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
}

$finProc = Get-Date
$duracionProc = ($finProc - $inicioProc).ToString("hh\:mm\:ss")
# ==========================================================
# GENERAR HTML
# ==========================================================

$html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='UTF-8'>
<title>Solicitudes Autorizadas $fecha</title>
<link rel='stylesheet' href='css/rdp.css'>
<script src='js/rdp.js'></script>
</head>

<body>

<h2>Solicitudes Autorizadas - $fecha.</h2>

<input type='text' id='txtFiltro' placeholder='Buscar en todo el reporte...'>

<!--  div class="contenedor-tabla" -->
<table class="table table-sm table-fixed" id="tabla">
<thead>
<tr>
"@

# Encabezados
foreach ($col in $dt.Columns) {
  $html += "<th class='fixed-col'>$($col.ColumnName)</th>"
}

$html += "<th>Accion</th>
</tr></thead><tbody>"

# Filas
foreach ($row in $dt) {
  $html += "<tr>"
  foreach ($col in $dt.Columns) {

    $val = $row[$col.ColumnName]
    # Write-Host "DEBUG Valor de $col.ColumnName  valor de col $col con val $val "

    # Si es número 0/1 → checkbox
    if (($val -eq 0 -or $val -eq 1) -and -not($col.ColumnName -eq "ESTADO") -and -not($col.ColumnName -eq "ath")) {
      $chk = if ($val -eq 1) { "checked" } else { "" }
      $html += "<td style='text-align:center'><input type='checkbox' $chk></td>"
    }
    else {
      $html += "<td>$val</td>"
    }
  }
  $html += "<td><button class='miniBtn' onclick='generarFila(this)'> > </button></td>"
  $html += "</tr>"
}

$html += @"
</tbody>
</table>
<!--  /div -->

<!--button class='btn' onclick='generarComandos()'>Generar Comandos</button-->
<div style='margin-top:15px;'>
    <button id='btnGenerar' onclick='generarTodo()' class='btn'>Generar Comandos</button>
</div>

<div style='margin-top:15px;'>
  <p><strong>Informe generado en: </strong> <span id='totalProceso'>$($duracionProc)</span></p><br><br>
</div>

<!-- MODAL PARA MOSTRAR COMANDOS -->
<div id="cmdModal" class="modal" style="display:none;
     position:fixed;top:0;left:0;width:100%;height:100%;
     background:rgba(0,0,0,0.6);padding-top:70px;z-index:9999;">
  
  <div class="modal-content" style="background:white;margin:auto;
       padding:20px;border-radius:8px;width:50%;position:relative;">
    
    <span id="closeModal" 
          style="position:absolute;top:10px;right:15px;
                 font-size:22px;cursor:pointer;">&times;</span>

    <h3>Comandos generados</h3>

    <textarea id="cmdContent" readonly 
              style="width:100%;height:120px;margin-top:10px;"></textarea>

    <button id="copyBtn" class="miniBtn" 
            style="margin-top:15px;padding:8px 15px;">
        Copiar
    </button>
  </div>
</div>


</body>
</html>
"@

Set-Content -Path $htmlOut -Value $html -Encoding UTF8

Write-Host "HTML generado en: $htmlOut" -ForegroundColor Green


# ==========================================================
# ABRIR EL HTML AUTOMÁTICAMENTE
# ==========================================================
Invoke-Item $htmlOut