# ============================================================
# Script: outlookAutorizando.ps1
# Autor: ChatGPT (ajustado para Leonel)
# Modo: Sin caracteres especiales (ASCII only)
# Encoding recomendado: UTF8
# Funcion: Detectar solicitudes y aprobaciones en correos Outlook
# ============================================================
param(
  [Nullable[int]]$nhoras
)

Write-Host "Iniciando lectura de Outlook..."

# Ruta de salida
$basePath = ".\solicitudes"
$csvFile = "$basePath\solicitudes.csv"
$sqlFile = "$basePath\solicitudes.sql"

if ($null -eq $nhoras -or $nhoras -eq 0) {
  $horasAtras = 24
}
else {
  $horasAtras = $nhoras
}

# Crear carpeta si no existe
if (-not (Test-Path $basePath)) {
  New-Item -Path $basePath -ItemType Directory | Out-Null
}

# Crear encabezados si los archivos no existen
if (-not (Test-Path $csvFile)) {
  "fecha_recepcion,fecha_solicitud,correo_solicitante,nombre_solicitante,correo_aprobador,nombre_aprobador,asunto,texto_solicitud,texto_aprobador" | Out-File -FilePath $csvFile -Encoding UTF8
}

if (-not (Test-Path $sqlFile)) {
  "/* Archivo de solicitudes */" | Out-File -FilePath $sqlFile -Encoding UTF8
}

# Palabras que validan una solicitud
$keywordsSolicitud = "autorizar", "acceso", "autorizacion", "autorización"

# Palabras que validan aprobacion
$keywordsAprobacion = "ok", "autorizo", "apruebo", "aprobado", "autorizado"

# Aprobadores validos
$aprobadoresValidos = @(
  "wgarcia@fidens-insurtech.com",
  "mcobos@fidens-insurtech.com"
)

# CC obligatorio
$ccRequerido = "infraestructura@fidenslat.com"

# Outlook COM
$outlook = New-Object -ComObject Outlook.Application
$ns = $outlook.GetNamespace("MAPI")
$inbox = $ns.GetDefaultFolder(6)
$items = $inbox.Items

# Ordenar por fecha DESC
$items.Sort("[ReceivedTime]", $false)

# Filtrar ultimas N horasAtras
$desde = (Get-Date).AddHours(-$horasAtras)

$items = $items | Where-Object { $_.ReceivedTime -ge $desde }

Write-Host "Correos cargados: $($items.Count)"

# Funcion para extraer texto limpio del solicitante
function Limpia-Texto($textoRaw) {
  $texto = $textoRaw

  # Eliminar firmas
  $cortes = @(
    "enviado desde",
    "sent from",
    "regards",
    "saludos",
    "atentamente",
    "best regards",
    "firma electrónica",
    "---",
    "____"
  )
  foreach ($c in $cortes) {
    $i = $texto.ToLower().IndexOf($c)
    if ($i -ge 0) {
      $texto = $texto.Substring(0, $i)
    }
  }

  # Quitar líneas vacías
  $texto = $texto -replace "(`r`n){2,}", "`r`n"

  # Reemplazar saltos por separadores
  $texto = $texto -replace "`r`n", "**"

  return $texto.Trim()
}

$contador = 0

# ================================
# PROGRESO + TIEMPO ESTIMADO
# ================================
$total = $items.count
$startTime = Get-Date
$index = 0

# Write-Host "=== MODO DEBUG ACTIVADO ==="
foreach ($mail in $items) {

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
    -Activity "Procesando informe de Accesos SQL" `
    -Status "Progreso: $percent% | ETA: $etaText | Base: $mail " `
    -PercentComplete $percent


  # Write-Host "======================================================"
  # Write-Host "Correo recibido: $($mail.Subject)"
  # Write-Host "Remitente: $($mail.SenderEmailAddress)"
  $ccLista = @()
  if ($null -ne $mail.CC) {
    foreach ($c in $mail.CC) {
      if ($c.Address) { $ccLista += $c.Address }
    }
  }
  $ccTexto = ($ccLista -join ",")
  # Write-Host "CC: $ccTexto"

  # 1) FILTRO DE APROBADOR
  # Buscar el correo previo (solicitud)  
  $correoAprobador = $mail.SenderEmailAddress
  if (-not $correoAprobador) { $correoAprobador = "" }
  else { $correoAprobador = $correoAprobador.ToLower() }

  $nombreAprobador = $mail.SenderName
  if (-not $nombreAprobador) { $nombreAprobador = "" }
  else { $nombreAprobador = $nombreAprobador.ToLower() }

  # Confirmar que el remitente sea un aprobador permitido
  if ($correoAprobador -notin $aprobadoresValidos) {
    # Write-Host "DEBUG 1. X DESCARTADO: No es aprobador valido"
    continue  # no es valido
  }
  # Write-Host "DEBUG 1. Aprobador valido"

  # 2) FILTRO DE CC
  # Validar CC obligatorio
  $ccTexto = ($mail.Recipients | ForEach-Object { $_.Address }) -join " "
  if ($ccTexto.ToLower() -notmatch $ccRequerido) {
    # Write-Host "DEBUG 2. X DESCARTADO: No tiene CC requerido"
    continue
  }
  # Write-Host "DEBUG 2. CC valido ($ccTexto)"
    
  # 3) PALABRAS CLAVE DE APROBACION
  # Validar palabras clave de aprobacion
  $bodyLower = $mail.Body.ToLower()
  # Aprobacion valida = aprobador valido + keywords de aprobacion  
  $esAprobacion = $false
  foreach ($k in $keywordsAprobacion) {
    if ($bodyLower.Contains($k)) {
      $esAprobacion = $true
      break
    }
  }
  if (-not $esAprobacion) { 
    # Write-Host "DEBUG 3. X DESCARTADO: No contiene palabras de aprobacion"
    continue 
  }
  # Write-Host "DEBUG 3. Tiene palabras clave de aprobacion $bodyLower" 
  
  
  # 4) DIVISION DEL HILO
  # Buscar en el hilo
  $textoSolicitud = ""
  # Patrones universales para cortar hilos (Outlook, iPhone, Android, Mac)
  #$pattern = "(?ms)(^On .* wrote:$|^El .* escribi[oó]:$|^From:|^De:|^----Mensaje original----|^Enviado desde mi iPhone)"
  #$pattern = "(?ms)(^De:.*?$|^De .*?:$|^From:.*?$|^-----Mensaje original-----|^On .* wrote:|^El .* escribi[oó]:)"
  #$partes = $mail.Body -split $pattern  

  # Detectar inicio del hilo buscando "De:", "From:" o "Enviado:"
  $lineas = $mail.Body -split "`r`n"
  $lineaInicioHilo = $lineas | Where-Object {
    $_ -match '^De:' -or 
    $_ -match '^From:' -or 
    $_ -match '^Enviado:' -or 
    $_ -match '^-----Mensaje original-----'
  } | Select-Object -First 1

  if (-not $lineaInicioHilo) {
    # Write-Host "DEBUG 4. X DESCARTADO: No se detectó inicio del hilo"
    continue
  }

  $indexHilo = [array]::IndexOf($lineas, $lineaInicioHilo)
  
  if ($indexHilo -lt 1) {
    # Write-Host "4. X DESCARTADO: No se detecto el inicio del hilo"
    continue
  }
  # Cuerpo del aprobador
  $cuerpoAprobador = Limpia-Texto(($lineas[0..($indexHilo - 1)] -join "`r`n"))
  # Cuerpo del solicitante (desde el hilo en adelante)
  $textoSolicitud = Limpia-Texto(($lineas[$indexHilo..($lineas.Count - 1)] -join "`r`n"))
  # Write-Host "DEBUG 4 Texto solicitud: $textoSolicitud"

  # Extraer fecha del solicitante desde la línea del encabezado del hilo
  $fechaSolicitud = ""

  $regexFechaEs = "^El (.*?)[,`r`n]"
  $regexFechaEn = "^On (.*?)[,`r`n]"

  $mFeEs = [regex]::Match($mail.Body, $regexFechaEs)
  $mFeEn = [regex]::Match($mail.Body, $regexFechaEn)

  if ($mFeEs.Success) {
    $fechaSolicitud = $mFeEs.Groups[1].Value.Trim()
  }
  elseif ($mFeEn.Success) {
    $fechaSolicitud = $mFeEn.Groups[1].Value.Trim()
  }

  # 5) EXTRAER SOLICITUD
  #  $textoSolicitud = Limpia-Texto($partes[1])
  #  Write-Host "Texto solicitud: $textoSolicitud"

  # 6) EXTRAER CORREO SOLICITANTE
  # Extraer correo solicitante
  $correoSolicitante = ""
  $nombreSolicitante = ""
  
  $regexCorreo = "\b[a-zA-Z0-9._%+-]+@(fidenslat\.com|fidens-insurtech\.com)\b"
  $matchCorreo = [regex]::Match($textoSolicitud, $regexCorreo)

  # Buscar correo del solicitante dentro del bloque de textoSolicitud
  $matchCorreo = [regex]::Match($textoSolicitud, $regexCorreo)
  if (-not $matchCorreo.Success) {
    # Write-Host "DEBUG 6. X DESCARTADO: No se detecto correo del solicitante"
    continue
  }  
  $correoSolicitante = $matchCorreo.Value
  # Write-Host "DEBUG 6. Detectado correo del solicitante"

  
  # 7) OBTENER NOMBRE DEL SOLICITANTE
  # Obtener nombre si viene en formato 'Nombre Apellido <correo>'
  # Buscar nombre si existe en formato: Nombre Apellido <correo>
  $regexNombre = "(.*)<$correoSolicitante>"
  $matchNombre = [regex]::Match($textoSolicitud, $regexNombre)
  #$matchNombre = [regex]::Match($partes[1], "(.*)<$correoSolicitante>")
  if (-not $matchNombre.Success) {
    # Write-Host "DEBUG 7. X DESCARTADO: No se detecto NOMBRE DEL SOLICITANTE"
    continue
  }
  #Write-Host "DEBUG 7. Nombre del solicitante detectado: $($matchNombre.Groups[1].Value.Trim())"
  $nombreSolicitante = $matchNombre.Groups[1].Value.Trim()

  # 8) PALABRAS CLAVE DE SOLICITUD
  # Validar que el texto del solicitante tenga keywords
  $textoLower = $textoSolicitud.ToLower()
  $esSolicitudValida = $false
  foreach ($k in $keywordsSolicitud) {
    if ($textoLower.Contains($k)) { $esSolicitudValida = $true }
  }
  if (-not $esSolicitudValida) { 
    # Write-Host "DEBUG  8. X DESCARTADO: Texto del solicitante NO contiene keywords"
    continue 
  }

  # Write-Host "DEBUG 8. Solicitud valida"
  # Write-Host "CORREO COMPLETO PROCESADO"

  # Registrar en CSV
  <#
  $lineaCsv = (
    $mail.ReceivedTime.ToString("yyyy-MM-dd HH:mm:ss") + "," +
    $fechaSolicitud + "," +
    $correoSolicitante + "," +
    $nombreSolicitante + "," +
    $correoAprobador + "," +
    $nombreAprobador + "," +
    $mail.Subject.Replace(",", " ") + "," +
    $textoSolicitud.Replace(",", " ") + "," +
    $cuerpoAprobador.Replace(",", " ")
  )
  Add-Content -Path $csvFile -Value $lineaCsv -Encoding UTF8
  #>

  # Registrar en Archivo SQL
  $usuario = $correoSolicitante.Replace("'", "").Trim()
  $usuario = ($usuario -split "@")[0].ToLower()
  $usuarioAuth = $correoAprobador.Replace("'", "").Trim()
  $usuarioAuth = ($usuarioAuth -split "@")[0].ToLower()
  $fecha_email = $mail.ReceivedTime.ToString("yyyy-MM-dd HH:mm:ss")
  $asunto = $mail.Subject.Replace("'", "''")
  $txt_solic = $textoSolicitud.Replace("'", "''")
  $txt_solic = $txt_solic.Replace("<", "").Replace(">", "")
  $txt_auth = $cuerpoAprobador.Replace("'", "''")
  $txt_auth = $txt_auth.Replace("<", "").Replace(">", "")  
  #---------------------------------------------
  # CONFIGURACIÓN
  #---------------------------------------------
  $server = "10.0.0.102"
  $user = "lvilla"
  $pass = "lv..2021"
  $database = "master"
  Import-Module SqlServer
  $connectionString = "Server=$server;Database=$database;User ID=$user;Password=$pass;TrustServerCertificate=True;"

  $sql102 = @"
  IF NOT EXISTS (
    SELECT 1 
    FROM dbo.infra_auth_email 
    WHERE fecha_correo = '$fecha_email' 
      AND usr_solic = '$usuario'
  )
  BEGIN
    INSERT INTO dbo.infra_auth_email (fecha_correo, coduser_solic, usr_solic, coduser_auth, usr_auth, asunto, txt_solicitud, txt_auth, consumo)
    SELECT '$fecha_email', (SELECT COD_USER FROM ProyFidens.dbo.SYS_ACCOUNT WHERE LOWER(TXT_ACC) = '$usuario'), 
    '$usuario', (SELECT COD_USER FROM ProyFidens.dbo.SYS_ACCOUNT WHERE LOWER(TXT_ACC) = '$usuarioAuth'), 
    '$usuarioAuth', '$asunto', '$txt_solic', '$txt_auth', 1;

    SELECT Id FROM dbo.infra_auth_email WHERE fecha_correo = '$fecha_email' AND usr_solic='$usuario';
  END
  ELSE
  BEGIN
    SELECT 0 as Id;
  END;
"@

  # Write-Host $sql102 -ForegroundColor Yellow
  $auth102 = Invoke-Sqlcmd -Query $sql102 -ConnectionString $connectionString
  if (-not $auth102 -or $auth102.Count -eq 0) {
    Write-Host "No se registro autorizacion en 102.infra_auth_email"
  }
  else {
    foreach ($row in $auth102) {
      $idReg = $row["Id"]
      if ($idReg -ne 0) {
        # Cargar linea de inserción en archivo sql
        $sql = "INSERT INTO solicitudes (fecha_correo, coduser_solic, usr_solic, coduser_auth, usr_auth, asunto, txt_solicitud, txt_auth, consumo) " +
        "SELECT '" + $fecha_email + "', " +
        "(SELECT COD_USER FROM ProyFidens.dbo.SYS_ACCOUNT WHERE LOWER(TXT_ACC) = '" + $usuario + "'), '" +
        $usuario + "','" +
        "(SELECT COD_USER FROM ProyFidens.dbo.SYS_ACCOUNT WHERE LOWER(TXT_ACC) = '" + $usuarioAuth + "'), '" +
        $usuarioAuth + "','" +
        $asunto + "','" +
        $txt_solic + "','" +
        $txt_auth + "');"

        Add-Content -Path $sqlFile -Value $sql -Encoding UTF8
        # FIN de Cargar linea de inserción en archivo sql

        $contador++
        Write-Host "Procesando: $contador items autorizacion valida."
      }
    }
  }
}
# Cerrar barra de progreso
Write-Progress -Activity "Procesados Correos de autorizaciones outlook " -Completed -Status "Completado"

Write-Host "-------------  Finalizado -------------------------"
Write-Host "Procesados: $contador correos validos"
Write-Host "CSV: $csvFile"
Write-Host "SQL: $sqlFile"


<#
  Ante problemas de outlook
  Cerrar outlook y ejecutar
  taskkill /IM outlook.exe /F
  taskkill /IM teams.exe /F

  Comprobar que outlook y ps estan usando el mismo perfil MAPI
  $outlook = New-Object -ComObject Outlook.Application
  $session = $outlook.Session
  $session.CurrentUser

#>