param(
    [switch]$Registrar  # Si usas -Registrar, se guardará en la tabla destino
)

# Servidores SQL a consultar
$servidores = @(
    "10.0.0.102",
    "10.0.0.103",
    "10.0.0.80",
    "10.0.0.86"
)

# Función para ejecutar SQL en remoto
function Exec-Sql {
    param(
        [string]$Servidor,
        [string]$Base,
        [string]$Query
    )

    $connStr = "Server=$Servidor; Database=$Base; Integrated Security=True;"
    $conn = New-Object System.Data.SqlClient.SqlConnection $connStr
    $cmd = New-Object System.Data.SqlClient.SqlCommand $Query, $conn
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
    $dt = New-Object System.Data.DataTable

    try {
        $conn.Open()
        $adapter.Fill($dt) | Out-Null
    }
    catch {
        Write-Host "Error conectando a $Servidor`:$Base - $_" -ForegroundColor Red
    }
    finally {
        $conn.Close()
    }
    return $dt
}

Write-Host "Iniciando consulta en servidores..." -ForegroundColor Cyan

$resultadoFinal = @()

foreach ($srv in $servidores) {

    Write-Host "`n--- Servidor: $srv ---" -ForegroundColor Yellow

    # 1. Obtener bases de datos de usuario
    $qDB = "
        SELECT name 
        FROM sys.databases 
        WHERE database_id > 4  -- Solo bases de usuario
          AND state = 0;       -- ONLINE
    "

    $bases = Exec-Sql -Servidor $srv -Base "master" -Query $qDB

    foreach ($db in $bases.name) {

        Write-Host "  Base: $db" -ForegroundColor Gray

        # 2. Obtener usuarios y roles
        $qRoles = "
            SELECT 
                DB_NAME() AS BaseDatos,
                m.name AS Usuario,
                r.name AS Rol
            FROM sys.database_role_members rm
            INNER JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
            INNER JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
            WHERE m.type IN ('S','U','G') -- SQL User, Windows User, Windows Group
            ORDER BY m.name, r.name;
        "

        $rows = Exec-Sql -Servidor $srv -Base $db -Query $qRoles

        foreach ($r in $rows) {
            $resultadoFinal += [PSCustomObject]@{
                Servidor  = $srv
                BaseDatos = $r.BaseDatos
                Usuario   = $r.Usuario
                Rol       = $r.Rol
            }
        }

        # 3. Registrar en tabla si se pidió
        if ($Registrar) {
            $rows | ForEach-Object {
                $insert = "
                    INSERT INTO Infra_UserRoles (Servidor, BaseDatos, Usuario, Rol)
                    VALUES ('$srv', '$($_.BaseDatos)', '$($_.Usuario)', '$($_.Rol)');
                "
                Exec-Sql -Servidor $srv -Base "master" -Query $insert | Out-Null
            }
            Write-Host "    → Registrado en Infra_UserRoles" -ForegroundColor Green
        }
    }
}

Write-Host "`nConsulta finalizada." -ForegroundColor Cyan

# Mostrar resultados en pantalla
$resultadoFinal | Format-Table -AutoSize