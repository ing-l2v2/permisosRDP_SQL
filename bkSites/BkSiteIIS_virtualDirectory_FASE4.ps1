#requires -version 3.0

<#
========================================================================
 FASE 4 - CREACION DE ESTRUCTURA DE DIRECTORIOS VIRTUALES IIS
========================================================================

 OBJETIVO
 --------
 Leer el archivo aplicaciones.txt generado en la FASE 1 y crear en el
 servidor destino la estructura física correspondiente a todos los
 VIRTUAL_DIRECTORY.

 IMPORTANTE
 ----------
 ESTE SCRIPT NO COPIA ARCHIVOS.
 Solamente crea directorios.

 El inventario IIS utilizado como origen es:
 C:\Infraestructura\Site\aplicaciones_DERCO_CORREDOR_12082026.txt

 El servidor destino es:
 10.0.0.201

 Usuario:
 FIDENSLAT\leonel.villa

========================================================================
 PREPARACION ANTES DE EJECUTAR
========================================================================
 1. Verificar que el archivo aplicaciones.txt exista.
 2. Verificar que el servidor destino 10.0.0.201 sea accesible.
 3. Verificar que WinRM esté disponible en el servidor destino.
 4. El usuario FIDENSLAT\leonel.villa debe tener permisos suficientes
    para crear los directorios correspondientes.
 5. ESTE SCRIPT NO COPIA ARCHIVOS.
 6. ESTE SCRIPT NO ELIMINA DIRECTORIOS.
 7. ESTE SCRIPT NO SOBRESCRIBE NI MODIFICA ARCHIVOS EXISTENTES.
 8. Se excluyen los Virtual Directory cuyo PhysicalPath pertenezca a:
       \\10.0.0.92\
       \\10.0.0.179\
    Estos recursos compartidos se consideran externos al servidor
    destino y NO serán creados.

========================================================================
 EJEMPLO
========================================================================
 Si el inventario contiene:
 [VIRTUAL_DIRECTORY_001]
 Path = /BENCHMARK
 PhysicalPath = D:\WEBSERVER\DERCO_CORREDOR\upload\BENCHMARK
 En el servidor destino se creará:
 D:\WEBSERVER\DERCO_CORREDOR\upload\BENCHMARK

 Si contiene:
 [VIRTUAL_DIRECTORY_002]
 Path = /ReporteCYR
 PhysicalPath = \\10.0.0.92\Shared\...

 Se omitirá.

========================================================================
#>

Clear-Host

# ======================================================================
# VARIABLES PRINCIPALES
# ======================================================================
$ServidorDestino = "10.0.0.201"
$Usuario = "FIDENSLAT\leonel.villa"
$SiteName = "DERCO_CORREDOR"
#$FechaInventario = Get-Date -Format "ddMMyyyy"
$FechaInventario = "12082026"
$ArchivoInventario = "C:\Infraestructura\Site\aplicaciones_${SiteName}_${FechaInventario}.txt"

# ======================================================================
# FUNCIONES
# ======================================================================

function Mostrar-Titulo {
  param(
    [string]$Texto
  )
  Write-Host ""
  Write-Host ("=" * 70)
  Write-Host $Texto
  Write-Host ("=" * 70)
  Write-Host ""
}


function Obtener-ValorCampo {
  param(
    [string[]]$Bloque,
    [string]$NombreCampo
  )

  foreach ($Linea in $Bloque) {
    if ($Linea -match "^\s*$([regex]::Escape($NombreCampo))\s*=\s*(.*)$") {
      return $Matches[1].Trim()
    }
  }

  return $null
}

# ======================================================================
# INICIO
# ======================================================================
Mostrar-Titulo "FASE 4 - CREACION DE VIRTUAL DIRECTORIES IIS"

Write-Host "Servidor destino : $ServidorDestino"
Write-Host "Usuario          : $Usuario"
Write-Host "Site             : $SiteName"
Write-Host "Fecha Inventario : $FechaInventario"
Write-Host "Inventario       : $ArchivoInventario"

# ======================================================================
# VALIDAR ARCHIVO
# ======================================================================
Mostrar-Titulo "VALIDANDO ARCHIVO DE INVENTARIO"
if (-not (Test-Path -LiteralPath $ArchivoInventario)) {
  Write-Host "[ERROR] No existe el archivo de inventario $ArchivoInventario." -ForegroundColor Red
  Write-Host ""
  Write-Host $ArchivoInventario
  Read-Host "Presione ENTER para finalizar"
  exit 1
}
Write-Host "[OK] Archivo encontrado."

# ======================================================================
# LEER ARCHIVO
# ======================================================================
Mostrar-Titulo "LEYENDO VIRTUAL DIRECTORIES"
try {
  $Lineas = Get-Content -LiteralPath $ArchivoInventario -ErrorAction Stop
}
catch {
  Write-Host "[ERROR] No fue posible leer el archivo $ArchivoInventario." -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  Read-Host "Presione ENTER para finalizar"
  exit 1
}


# ======================================================================
# BUSCAR SECCION VIRTUAL_DIRECTORY
# ======================================================================

$VirtualDirectories = @()

$EnSeccionVD = $false
$BloqueActual = @()

foreach ($Linea in $Lineas) {

  $LineaTrim = $Linea.Trim()

  # --------------------------------------------------------------
  # Detectar inicio de seccion
  # --------------------------------------------------------------

  if ($LineaTrim -eq "VIRTUAL DIRECTORIES") {

    $EnSeccionVD = $true
    continue
  }

  # --------------------------------------------------------------
  # Si aparece otra seccion principal terminamos
  # --------------------------------------------------------------

  if ($EnSeccionVD -and
    $LineaTrim -match "^[A-Z0-9 _-]+$" -and
    $LineaTrim -ne "VIRTUAL DIRECTORIES" -and
    $LineaTrim.Length -gt 3) {

    if ($BloqueActual.Count -gt 0) {

      $Path = Obtener-ValorCampo `
        -Bloque $BloqueActual `
        -NombreCampo "Path"

      $PhysicalPath = Obtener-ValorCampo `
        -Bloque $BloqueActual `
        -NombreCampo "physicalPath"

      if ($Path -and $PhysicalPath) {

        $VirtualDirectories += [PSCustomObject]@{
          Path         = $Path
          PhysicalPath = $PhysicalPath
        }
      }

      $BloqueActual = @()
    }

    $EnSeccionVD = $false
    continue
  }

  # --------------------------------------------------------------
  # Detectar bloque VIRTUAL_DIRECTORY
  # --------------------------------------------------------------

  if ($EnSeccionVD -and
    $LineaTrim -match "^\[VIRTUAL_DIRECTORY_\d+\]$") {

    if ($BloqueActual.Count -gt 0) {

      $Path = Obtener-ValorCampo `
        -Bloque $BloqueActual `
        -NombreCampo "Path"

      $PhysicalPath = Obtener-ValorCampo `
        -Bloque $BloqueActual `
        -NombreCampo "physicalPath"

      if ($Path -and $PhysicalPath) {

        $VirtualDirectories += [PSCustomObject]@{
          Path         = $Path
          PhysicalPath = $PhysicalPath
        }
      }
    }

    $BloqueActual = @()
    continue
  }

  if ($EnSeccionVD) {

    $BloqueActual += $Linea
  }
}


# ======================================================================
# PROCESAR ULTIMO BLOQUE
# ======================================================================

if ($BloqueActual.Count -gt 0) {

  $Path = Obtener-ValorCampo `
    -Bloque $BloqueActual `
    -NombreCampo "Path"

  $PhysicalPath = Obtener-ValorCampo `
    -Bloque $BloqueActual `
    -NombreCampo "physicalPath"

  if ($Path -and $PhysicalPath) {

    $VirtualDirectories += [PSCustomObject]@{
      Path         = $Path
      PhysicalPath = $PhysicalPath
    }
  }
}


# ======================================================================
# VALIDAR RESULTADO
# ======================================================================

Mostrar-Titulo "RESULTADO DEL INVENTARIO"

Write-Host "Virtual Directories encontrados : $($VirtualDirectories.Count)"

if ($VirtualDirectories.Count -eq 0) {

  Write-Host ""
  Write-Host "[ERROR] No se encontraron VIRTUAL_DIRECTORY." -ForegroundColor Red

  Read-Host "Presione ENTER para finalizar"

  exit 1
}


$Contador = 0

foreach ($VD in $VirtualDirectories) {

  $Contador++

  Write-Host ""
  Write-Host ("[{0:D2}] {1}" -f $Contador, $VD.Path)
  Write-Host "     PhysicalPath : $($VD.PhysicalPath)"
}


# ======================================================================
# CREDENCIALES
# ======================================================================

Mostrar-Titulo "CREDENCIALES"

Write-Host "Servidor destino : $ServidorDestino"
Write-Host "Usuario          : $Usuario"
Write-Host ""

$Password = Read-Host `
  "Ingrese el password de $Usuario" `
  -AsSecureString


$Credencial = New-Object `
  System.Management.Automation.PSCredential(
  $Usuario,
  $Password
)


# ======================================================================
# VALIDAR WINRM
# ======================================================================

Mostrar-Titulo "VALIDANDO WINRM"

try {

  Test-WSMan `
    -ComputerName $ServidorDestino `
    -ErrorAction Stop | Out-Null

  Write-Host "[OK] WinRM disponible."

}
catch {

  Write-Host ""
  Write-Host "[ERROR] No fue posible conectarse mediante WinRM." `
    -ForegroundColor Red

  Write-Host $_.Exception.Message `
    -ForegroundColor Red

  Read-Host "Presione ENTER para finalizar"

  exit 1
}


# ======================================================================
# CREAR SESION
# ======================================================================

Mostrar-Titulo "ESTABLECIENDO SESION REMOTA"

try {

  $Sesion = New-PSSession `
    -ComputerName $ServidorDestino `
    -Credential $Credencial `
    -ErrorAction Stop

  Write-Host "[OK] Sesion remota establecida."

}
catch {

  Write-Host ""
  Write-Host "[ERROR] No fue posible establecer la sesion." `
    -ForegroundColor Red

  Write-Host $_.Exception.Message `
    -ForegroundColor Red

  Read-Host "Presione ENTER para finalizar"

  exit 1
}


# ======================================================================
# CONTADORES
# ======================================================================

$TotalProcesados = 0
$TotalCreados = 0
$TotalExistentes = 0
$TotalExcluidos = 0
$TotalErrores = 0


# ======================================================================
# PROCESAMIENTO
# ======================================================================

Mostrar-Titulo "CREANDO ESTRUCTURA DE VIRTUAL DIRECTORIES"

foreach ($VD in $VirtualDirectories) {

  $TotalProcesados++

  $IISPath = $VD.Path
  $PhysicalPath = $VD.PhysicalPath

  Write-Host ""
  Write-Host ("-" * 70)

  Write-Host "VIRTUAL DIRECTORY $TotalProcesados DE $($VirtualDirectories.Count)"
  Write-Host ("-" * 70)

  Write-Host "IIS Path        : $IISPath"
  Write-Host "Physical Path   : $PhysicalPath"


  # ==================================================================
  # VALIDAR RUTA VACIA
  # ==================================================================

  if ([string]::IsNullOrWhiteSpace($PhysicalPath)) {

    Write-Host "[OMITIDO] PhysicalPath vacio." `
      -ForegroundColor Yellow

    $TotalErrores++

    continue
  }


  # ==================================================================
  # EXCLUSION 10.0.0.92
  # ==================================================================

  if ($PhysicalPath -match '^\\\\10\.0\.0\.92\\') {

    Write-Host ""
    Write-Host "[EXCLUIDO]" -ForegroundColor Yellow
    Write-Host "El recurso pertenece a \\10.0.0.92"
    Write-Host "No se creara ningun directorio."

    $TotalExcluidos++

    continue
  }


  # ==================================================================
  # EXCLUSION 10.0.0.179
  # ==================================================================

  if ($PhysicalPath -match '^\\\\10\.0\.0\.179\\') {

    Write-Host ""
    Write-Host "[EXCLUIDO]" -ForegroundColor Yellow
    Write-Host "El recurso pertenece a \\10.0.0.179"
    Write-Host "No se creara ningun directorio."

    $TotalExcluidos++

    continue
  }


  # ==================================================================
  # VALIDAR SI ES UNC NO PERMITIDO
  # ==================================================================

  if ($PhysicalPath -match '^\\\\') {

    Write-Host ""
    Write-Host "[EXCLUIDO]" -ForegroundColor Yellow
    Write-Host "La ruta es un recurso UNC externo:"
    Write-Host $PhysicalPath
    Write-Host "Solo se permiten rutas fisicas locales del servidor destino."

    $TotalExcluidos++

    continue
  }


  # ==================================================================
  # CREAR DIRECTORIO REMOTAMENTE
  # ==================================================================

  try {

    $Resultado = Invoke-Command `
      -Session $Sesion `
      -ScriptBlock {

      param(
        [string]$Ruta
      )

      if (Test-Path -LiteralPath $Ruta) {

        $Item = Get-Item `
          -LiteralPath $Ruta `
          -Force `
          -ErrorAction Stop

        if ($Item.PSIsContainer) {

          return [PSCustomObject]@{
            Estado = "EXISTENTE"
            Ruta   = $Ruta
          }

        }
        else {

          return [PSCustomObject]@{
            Estado = "ERROR_ARCHIVO"
            Ruta   = $Ruta
          }
        }
      }

      New-Item `
        -ItemType Directory `
        -Path $Ruta `
        -Force `
        -ErrorAction Stop | Out-Null

      return [PSCustomObject]@{
        Estado = "CREADO"
        Ruta   = $Ruta
      }

    } `
      -ArgumentList $PhysicalPath `
      -ErrorAction Stop


    # ==============================================================
    # RESULTADO
    # ==============================================================

    switch ($Resultado.Estado) {

      "CREADO" {

        Write-Host ""
        Write-Host "[CREADO]" -ForegroundColor Green
        Write-Host $PhysicalPath

        $TotalCreados++
      }

      "EXISTENTE" {

        Write-Host ""
        Write-Host "[YA EXISTIA]" -ForegroundColor Cyan
        Write-Host $PhysicalPath

        $TotalExistentes++
      }

      "ERROR_ARCHIVO" {

        Write-Host ""
        Write-Host "[ERROR]" -ForegroundColor Red
        Write-Host "Existe un archivo con el mismo nombre:"
        Write-Host $PhysicalPath

        $TotalErrores++
      }

      default {

        Write-Host ""
        Write-Host "[ERROR] Resultado desconocido." `
          -ForegroundColor Red

        $TotalErrores++
      }
    }

  }
  catch {

    Write-Host ""
    Write-Host "[ERROR CREANDO DIRECTORIO]" `
      -ForegroundColor Red

    Write-Host "Ruta : $PhysicalPath"
    Write-Host $_.Exception.Message `
      -ForegroundColor Red

    $TotalErrores++
  }
}


# ======================================================================
# CERRAR SESION
# ======================================================================

Mostrar-Titulo "CERRANDO SESION REMOTA"

try {

  Remove-PSSession `
    -Session $Sesion `
    -ErrorAction SilentlyContinue

  Write-Host "[OK] Sesion cerrada."

}
catch {

  Write-Host "[AVISO] No fue posible cerrar correctamente la sesion."
}


# ======================================================================
# RESUMEN
# ======================================================================

Mostrar-Titulo "RESUMEN FASE 4"

Write-Host "Servidor destino       : $ServidorDestino"
Write-Host "Usuario                : $Usuario"
Write-Host ""
Write-Host "Virtual Directories    : $($VirtualDirectories.Count)"
Write-Host "Procesados             : $TotalProcesados"
Write-Host "Directorios creados    : $TotalCreados"
Write-Host "Ya existentes          : $TotalExistentes"
Write-Host "Excluidos              : $TotalExcluidos"
Write-Host "Errores                : $TotalErrores"
Write-Host ""


# ======================================================================
# RESULTADO FINAL
# ======================================================================

if ($TotalErrores -eq 0) {

  Write-Host "FASE 4 FINALIZADA CORRECTAMENTE." `
    -ForegroundColor Green

}
else {

  Write-Host "FASE 4 FINALIZADA CON ERRORES." `
    -ForegroundColor Yellow

}


Write-Host ""
Read-Host "Presione ENTER para finalizar"