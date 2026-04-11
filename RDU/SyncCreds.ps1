<#
===============================================================================
  MODULE: SyncCreds.ps1 (Version Estable - Sin acentos)
  OBJETIVO:
    - Administrar credenciales RDP/SMB/SQL
    - Detectar credenciales faltantes o invalidas
    - Restaurarlas automaticamente
    - Registrar log diario en ./log
    - 100% compatible sin acentos ni caracteres Unicode problemáticos
===============================================================================
#>

# ==========================
# CONFIGURACION PRINCIPAL
# ==========================
$Global:CredencialesServidores = @{
  "10.0.0.15"  = @{ User = "lvilla"; Password = "lv..2021" }
  "10.0.0.36"  = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.40"  = @{ User = "lvilla"; Password = "lv..2021" }
  "10.0.0.48"  = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.49"  = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.53"  = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.54"  = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.56"  = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.59"  = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.60"  = @{ User = "lvilla"; Password = "lv..2021" }
  "10.0.0.61"  = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.77"  = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.80"  = @{ User = "lvilla"; Password = "lv..2021" }
  "10.0.0.86"  = @{ User = "lvilla"; Password = "lv..2021" }
  "10.0.0.84"  = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.87"  = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.101" = @{ User = "lvilla"; Password = "lv..2021" }
  "10.0.0.102" = @{ User = "lvilla"; Password = "lv..2021" }
  "10.0.0.103" = @{ User = "lvilla"; Password = "lv..2021" }
  "10.0.0.186" = @{ User = "lvilla"; Password = "lv..2021" }
  "10.0.0.192" = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.201" = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.203" = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
  "10.0.0.246" = @{ User = "FIDENSLAT\leonel.villa"; Password = "lv..2021" }
}

# =======================================================
# FUNCION: escribir log diario
# =======================================================
function Write-Log {
  param([string]$Message)

  $logDir = Join-Path $PSScriptRoot "log"
  if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
  }

  $logFile = Join-Path $logDir ("log_{0}.txt" -f (Get-Date -Format "yyyyMMdd"))
  $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

  $line = "$timestamp - $Message"
  $maxRetries = 5
  $retryDelay = 200  # ms

  for ($i = 1; $i -le $maxRetries; $i++) {
    try {
      $file = [System.IO.File]::Open($logFile, 'Append', 'Write', 'None')
      $writer = New-Object System.IO.StreamWriter($file)
      $writer.WriteLine($line)
      $writer.Close()
      $file.Close()
      return
    }
    catch {
      Start-Sleep -Milliseconds $retryDelay
    }
  }

  # Si aun falla, no interrumpe el script
  Write-Host "Warning: No se pudo escribir en el log despues de varios intentos." -ForegroundColor Yellow
}

# =======================================================
# FUNCION: detectar si existe la credencial
# =======================================================
function Test-CredentialExists {
  param([string]$Server)

  $targets = @($Server, "TERMSRV/$Server")

  foreach ($t in $targets) {
    $exists = (cmdkey /list:$t 2>$null) -match $t
    if ($exists) {
      Write-Log "Credencial encontrada para $t"
      return $true
    }
  }

  Write-Log "No existe credencial para $Server"
  return $false
}

# =======================================================
# FUNCION: restaurar credencial
# =======================================================
function Restore-Credential {
  param([string]$Server, [string]$User, [string]$Password)

  Write-Host "[+] Restaurando credencial $Server..." -ForegroundColor Yellow
  Write-Log "Restaurando credencial para $Server"

  cmdkey /add:$Server /user:$User /pass:$Password | Out-Null
  cmdkey /generic:TERMSRV/$Server /user:$User /pass:$Password | Out-Null

  Write-Log "Credencial restaurada correctamente para $Server"
}

# =======================================================
# FUNCION: probar conectividad real
# =======================================================
function Test-RemoteCredential {
  param([string]$Server)

  $icmp = Test-Connection -ComputerName $Server -Count 1 -Quiet -ErrorAction SilentlyContinue
  if (-not $icmp) {
    Write-Log "Sin respuesta ICMP desde $Server"
    return $false
  }

  $rdp = Test-NetConnection -ComputerName $Server -Port 3389 -ErrorAction SilentlyContinue
  if ($rdp.TcpTestSucceeded) {
    Write-Log "Puerto 3389 OK en $Server"
    return $true
  }

  $sql = Test-NetConnection -ComputerName $Server -Port 1433 -ErrorAction SilentlyContinue
  if ($sql.TcpTestSucceeded) {
    Write-Log "Puerto 1433 OK en $Server"
    return $true
  }

  Write-Log "Puertos no disponibles en $Server"
  return $false
}
function Sync-RemoteCredencialGrupo {
  param (
    [Parameter(Mandatory = $true)]
    [string[]]$Servidores
  )
  if (-not $Servidores -or $Servidores.Count -eq 0) {
    Write-Host "No se especificaron servidores para sincronizar." -ForegroundColor Yellow
    return
  }
  Write-Host "`n INICIANDO SINCRONIZACION DE GRUPO DE CREDENCIALES." -ForegroundColor Cyan
  Write-Log "INICIO SINCRONIZACION GRUPO"

  foreach ($server in $Servidores) {
    if (-not $Global:CredencialesServidores.ContainsKey($server)) {
      Write-Host "Servidor $server no existe en CredencialesServidores." -ForegroundColor Yellow
      Write-Log "Servidor $server no existe en tabla Credenciales"
      continue      
    }
    $user = $Global:CredencialesServidores[$server].User
    $pass = $Global:CredencialesServidores[$server].Password

    Write-Host "Validando $server..." -ForegroundColor White
    Write-Log "Validando credencial de $server"

    if (-not (Test-CredentialExists -Server $server)) {
      Write-Host "     - Restaurando (credencial inexistente)..." -ForegroundColor Yellow
      Restore-Credential -Server $server -User $user -Password $pass
      continue
    }
    if (-not (Test-RemoteCredential -Server $server)) {
      Write-Host "     - Restaurando (token invalida)..." -ForegroundColor Yellow
      Restore-Credential -Server $server -User $user -Password $pass
      continue
    }
    Write-Host "     OK $server" -ForegroundColor Green
    Write-Log " Credencial OK para $server"
  }
  Write-Log "  FIN SINCRONIZACION GRUPO "
  Write-Host "  SINCRONIZACION DE GRUPO FINALIZADA. `n" -ForegroundColor Cyan
}
# =======================================================
# FUNCION PRINCIPAL: sincronizar todas las credenciales
# =======================================================
function Sync-RemoteCredentials {
  param([hashtable]$Credenciales = $Global:CredencialesServidores)

  Write-Host "`n==> INICIANDO SINCRONIZACION DE CREDENCIALES" -ForegroundColor Cyan
  Write-Log "==== INICIO SINCRONIZACION ===="

  foreach ($server in $Credenciales.Keys) {
    $user = $Credenciales[$server].User
    $pass = $Credenciales[$server].Password

    Write-Host "Validando $server..." -ForegroundColor White
    Write-Log "Validando credencial de $server"

    if (-not (Test-CredentialExists -Server $server)) {
      Write-Host "   - Restaurando (no existe)..." -ForegroundColor Yellow
      Restore-Credential -Server $server -User $user -Password $pass
      continue
    }

    if (-not (Test-RemoteCredential -Server $server)) {
      Write-Host "   - Restaurando (token invalido)..." -ForegroundColor Yellow
      Restore-Credential -Server $server -User $user -Password $pass
      continue
    }

    Write-Host "   OK $server" -ForegroundColor Green
    Write-Log "Credencial OK para $server"
  }

  Write-Log "==== FIN SINCRONIZACION ===="
  Write-Host "Sincronizacion completa.`n" -ForegroundColor Cyan
}

# =======================================================
# FUNCION: monitoreo automatico en loop
# =======================================================
function Start-CredentialAutoMonitor {
  param([int]$IntervalSeconds = 300)

  Write-Log "Monitoreo automatico iniciado (cada $IntervalSeconds segundos)"
  Write-Host "Monitoreo automatico activado" -ForegroundColor Magenta

  while ($true) {
    Sync-RemoteCredentials
    Start-Sleep -Seconds $IntervalSeconds
  }
}