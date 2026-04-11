# MenuPermisos.ps1
# powershell.exe -ExecutionPolicy Bypass -File menuPermisos.ps1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -----------------------------
# FUNCION: Crear botones menú
# -----------------------------
function NuevaOpcion {
    param(
        [string]$text,
        [int]$y,
        [int]$col,
        [ScriptBlock]$onClick
    )
    $anchoBtn = 260
    $altoBtn = 40
    if ($col -eq 1) {
        $x = 20
    }
    elseif ($col -eq 2) {
        $x = 20 + $anchoBtn + 20
    }
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Size = New-Object System.Drawing.Size($anchoBtn, $altoBtn)
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Add_Click($onClick)
    return $btn
}

function NuevaOpcionOld {
    param(
        [string]$text,
        [int]$y,
        [scriptblock]$onClick
    )

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Width = 260
    $btn.Height = 40
    $btn.Left = 20
    $btn.Top = $y

    # Colores modernos
    $btn.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::DarkGray

    # Tipografía
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)

    # Efecto Hover
    $btn.Add_MouseEnter({
            $btn.BackColor = [System.Drawing.Color]::FromArgb(225, 225, 225)
        })
    $btn.Add_MouseLeave({
            $btn.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
        })

    # Acción
    if ($onClick) { $btn.Add_Click($onClick) }

    return $btn
}

# -----------------------------
# FORMULARIO: Agregar RDP
# -----------------------------
function Form_Agregar_RDP {
    . "$PSScriptRoot\ServidoresCredenciales.ps1"
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Agregar Permiso RDP"
    $form.Size = New-Object System.Drawing.Size(450, 350)
    $form.StartPosition = "CenterScreen"

    $lblServ = New-Object System.Windows.Forms.Label
    $lblServ.Text = "Servidor (10.0.0.x):"
    $lblServ.Location = "20,20"
    #$txtServ = New-Object System.Windows.Forms.TextBox
    $cmbServ = New-Object System.Windows.Forms.ComboBox
    $cmbServ.items.Clear()
    $cmbServ.Items.AddRange( $Global:ServidoresIpLocal )
    $cmbServ.Location = "170,20"
    $cmbServ.Text = "10.0.0.102"

    $lblDominio = New-Object System.Windows.Forms.Label
    $lblDominio.Text = "Tipo:"
    $lblDominio.Location = "20,60"
    $lblDominio.Width = 40

    # Crear clase simple para los elementos del ComboBox
    $itemsTipoDominio = @(
        @{ Texto = "FIDENSLAT"; Valor = "FIDENSLAT\" }
        @{ Texto = "LOCAL"; Valor = ".\" }
    )
    $cmbDominio = New-Object System.Windows.Forms.ComboBox
    $cmbDominio.DropDownStyle = "DropDownList"
    # Indicar qué propiedad se muestra y cuál es el valor interno
    $cmbDominio.DisplayMember = "Texto"
    $cmbDominio.ValueMember = "Valor"
    $cmbDominio.Location = "60,60"
    $cmbDominio.Width = 100
    # Cargar los elementos
    foreach ($item in $itemsTipoDominio) {
        $obj = New-Object PSObject -Property $item
        $cmbDominio.Items.Add($obj)
    }
    $cmbDominio.SelectedIndex = ($cmbDominio.Items | ForEach-Object { $_.Valor } ).IndexOf("FIDENSLAT\")

    $lblUsr = New-Object System.Windows.Forms.Label
    $lblUsr.Text = "Usuario:"
    $lblUsr.Location = "170,60"
    $lblUsr.Width = 50
    $txtUsr = New-Object System.Windows.Forms.TextBox
    $txtUsr.Location = "220,60"
    $txtUsr.Width = 100
    $txtUsr.Text = "mcobos"

    $lblGrp = New-Object System.Windows.Forms.Label
    $lblGrp.Text = "Grupo:"
    $lblGrp.Location = "20,100"
    $cmbGrp = New-Object System.Windows.Forms.ComboBox
    $cmbGrp.Location = "170,100"
    $cmbGrp.Items.AddRange(@("RDU", "ADM"))
    $cmbGrp.Text = "RDU"

    $lblDur = New-Object System.Windows.Forms.Label
    $lblDur.Text = "Horas (<49):"
    $lblDur.Location = "20,140"
    $txtDur = New-Object System.Windows.Forms.TextBox
    $txtDur.Location = "170,140"
    $txtDur.Width = 60
    $txtDur.Text = "48"

    $lblExp = New-Object System.Windows.Forms.Label
    $lblExp.Text = "Expira (YYYY-MM-DD HH:mm):"
    $lblExp.Location = "20,180"
    $txtExp = New-Object System.Windows.Forms.TextBox
    $txtExp.Location = "170,180"
    $txtExp.Width = 150
    $txtExp.Text = (Get-Date).AddDays(2).ToString("yyyy-MM-dd HH:mm")

    # Campo para definir el NumReg del permiso en ProyFidens
    $lblNumReg = New-Object System.Windows.Forms.Label
    $lblNumReg.Text = "NumReg en ProyFidens (opcional):"
    $lblNumReg.Location = "20,220"
    $lblNumReg.Width = 150    
    
    $txtNumReg = New-Object System.Windows.Forms.TextBox
    $txtNumReg.Location = "170,220"
    $txtNumReg.Width = 50

    # Boton Ejecutar
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Ejecutar"
    $btnOK.Location = "100,270"
    $btnOK.Add_Click({
            # Obtener valor real del tipo de acceso
            if ($null -ne $cmbDominio.SelectedItem) {
                $tipoDominio = $cmbDominio.SelectedItem.Valor
            }
            else {
                # fallback: usar el texto y buscar el valor correcto
                $tipoDominio = ($itemsTipoDominio | Where-Object { $_.Texto -eq $cmbDominio.Text }).Valor
            }            
            $usrdominio = $tipoDominio + $txtUsr.Text
            if ($txtExp.Text -eq "NULL" -or $txtExpira.Text -eq "$null" -or $txtExp.Text -eq "") {
                $expira = $null
            }
            else {
                $expira = $txtExp.Text
            }
            if ($txtNumReg.Text -eq "NULL" -or $txtNumReg.Text -eq "$null" -or $txtNumReg.Text -eq "") {
                $numreg = $null
            }
            else {
                $numreg = $txtNumReg.Text
            }
            $psArgs = @(
                "-Servidores", $cmbServ.Text
                "-Usuario", $usrdominio
                "-GrupoIn", $cmbGrp.Text
                "-DuracionHoras", $txtDur.Text
            )

            if ($null -ne $expira -and $expira -ne "") {
                $psArgs += "-Expira"
                $psArgs += $expira
            }
            if ($null -ne $numreg -and $numreg -ne "") {
                $psArgs += "-idPryFidens"
                $psArgs += $numreg
            }
            $resultado = powershell -ExecutionPolicy Bypass -File ".\rdpAdd.ps1" @psArgs 2>&1
            <#
            $resultado = powershell -ExecutionPolicy Bypass -File ".\rdpAdd.ps1" `
                -Servidores $cmbServ.Text `
                -Usuario $usrdominio `
                -GrupoIn $cmbGrp.Text `
                -DuracionHoras $txtDur.Text `
                -Expira $expira 2>&1
            #>
            [System.Windows.Forms.MessageBox]::Show($resultado -join "`n", "Resultado rdpAdd.ps1")
        })
    # Botón Cancelar
    $btnCancelar = New-Object System.Windows.Forms.Button
    $btnCancelar.Text = "Cancelar"
    $btnCancelar.Location = "200,270"
    $btnCancelar.Add_Click({
            $form.Close()
        })

    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })

    $form.Controls.AddRange(@($lblServ, $cmbServ, $lblDominio, $cmbDominio, $lblUsr, $txtUsr, $lblGrp, $cmbGrp, $lblDur, $txtDur, $lblExp, $txtExp, $lblNumReg, $txtNumReg, $btnOK, $btnCancelar))
    $form.ShowDialog()
}

# -----------------------------
# Cargar Bases del servidor
# -----------------------------
function CargarBasesDatos($servidor, $combo) {
    $combo.DataSource = $null
    #$combo.Items.Clear()

    $Origenes = @(
        [pscustomobject]@{ Servidor = 49; Pass = "L2v2..20&25.#" },
        [pscustomobject]@{ Servidor = 56; Pass = "L2v2..20&25.#" },
        [pscustomobject]@{ Servidor = 61; Pass = "lv..2021" },
        [pscustomobject]@{ Servidor = 80; Pass = "lv..2021" },
        [pscustomobject]@{ Servidor = 86; Pass = "lv..2021" },
        [pscustomobject]@{ Servidor = 102; Pass = "lv..2021" },
        [pscustomobject]@{ Servidor = 10; Pass = "Ohdef_1007" }
    )

    try {

        $origen = $Origenes | Where-Object { $_.Servidor -eq $servidor }

        if (-not $origen) {
            [System.Windows.Forms.MessageBox]::Show("No se encontró configuración para servidor $servidor")
            return
        }

        if ($servidor -eq 10) {
            $servName = "sql-ginger.database.windows.net"
            $UsrSql = "csilva"
        }
        else {
            $servName = "10.0.0.$servidor"
            $UsrSql = "lvilla"
        }
        $BdRepo = "master"
        $Pass = $origen.Pass

        if (-not (Test-Connection -ComputerName $servName -Count 1 -Quiet)) {
            Write-Host "[$servName] No responde al ping" -ForegroundColor Magenta
            return
        }

        $connString = "Server=$servName;Database=$BdRepo;User ID=$UsrSql;Password=$Pass;TrustServerCertificate=True;"

        $conn = New-Object System.Data.SqlClient.SqlConnection $connString
        $cmd = $conn.CreateCommand()

        if ($servidor -eq 10) {
            $cmd.CommandText = "SELECT database_id AS codBd, name AS nomBd
                FROM sys.databases
                WHERE state = 0
                ORDER BY name;
            "        
        }
        else {
            $cmd.CommandText = "
                SELECT idAdminFidens AS codBd, BaseDatos AS nomBd
                FROM dbo.infraBasesGestionadas
                WHERE Estado=1
                ORDER BY BaseDatos
            "
        }

        $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
        $dt = New-Object System.Data.DataTable

        $conn.Open()
        $da.Fill($dt) | Out-Null
        $conn.Dispose()

        $combo.DisplayMember = "nomBd"
        $combo.ValueMember = "codBd"
        $combo.DataSource = $dt

        if ($combo.Items.Count -gt 0) {
            $combo.SelectedIndex = 0
        }

    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error cargando bases: $_")
    }
}

# -----------------------------
# Cargar Multiples Bases del servidor hacia CheckedListBox
# -----------------------------
function CargarBasesDatos_Multi {

    param(
        [int]$servidor,
        [System.Windows.Forms.CheckedListBox]$chk
    )

    $chk.Items.Clear()

    $Origenes = @(
        [pscustomobject]@{ Servidor = 49; Pass = "L2v2..20&25.#" },
        [pscustomobject]@{ Servidor = 56; Pass = "L2v2..20&25.#" },
        [pscustomobject]@{ Servidor = 61; Pass = "lv..2021" },
        [pscustomobject]@{ Servidor = 80; Pass = "lv..2021" },
        [pscustomobject]@{ Servidor = 86; Pass = "lv..2021" },
        [pscustomobject]@{ Servidor = 102; Pass = "lv..2021" },
        [pscustomobject]@{ Servidor = 10; Pass = "Ohdef_1007" }
    )

    try {

        $origen = $Origenes | Where-Object { $_.Servidor -eq $servidor }
        if (-not $origen) { return }

        if ($servidor -eq 10) {
            $servName = "sql-ginger.database.windows.net"
            $UsrSql = "csilva"
        }
        else {
            $servName = "10.0.0.$servidor"
            $UsrSql = "lvilla"
        }

        $BdRepo = "master"
        $Pass = $origen.Pass

        $connString = "Server=$servName;Database=$BdRepo;User ID=$UsrSql;Password=$Pass;TrustServerCertificate=True;"
        $conn = New-Object System.Data.SqlClient.SqlConnection $connString
        $cmd = $conn.CreateCommand()

        if ($servidor -eq 10) {
            $cmd.CommandText = "
                SELECT database_id AS codBd, name AS nomBd
                FROM sys.databases
                WHERE state = 0
                ORDER BY name
            "
        }
        else {
            $cmd.CommandText = "
                SELECT idAdminFidens AS codBd, BaseDatos AS nomBd
                FROM dbo.infraBasesGestionadas
                WHERE Estado=1
                ORDER BY BaseDatos
            "
        }

        $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
        $dt = New-Object System.Data.DataTable

        $conn.Open()
        $da.Fill($dt) | Out-Null
        $conn.Dispose()

        foreach ($row in $dt.Rows) {
            $item = New-Object BaseDatoItem
            $item.Nombre = $row.nomBd
            $item.Codigo = [int]$row.codBd
            $chk.Items.Add($item)
        }

    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error cargando bases: $_")
    }
}
function TiposAccesosSql($combo) {
    $combo.DataSource = $null
    $combo.Items.Clear()

    $dt = New-Object System.Data.DataTable
    $dt.Columns.Add("Texto") | Out-Null
    $dt.Columns.Add("Valor") | Out-Null

    $dt.Rows.Add("Lectura/Escritura datos, ejecucion de SPs", "RWSP") | Out-Null
    $dt.Rows.Add("Lectura datos, db_datareader", "R") | Out-Null
    $dt.Rows.Add("Escritura datos, db_datawriter", "W") | Out-Null
    $dt.Rows.Add("Lectura|Escritura de datos", "RW") | Out-Null
    $dt.Rows.Add("Vista, Ejecucion Store Procedures", "SP") | Out-Null
    $dt.Rows.Add("Modificar Store Procedures", "SM") | Out-Null
    $dt.Rows.Add("Lectura/Escritura datos, modificacion de SPs", "RWSM") | Out-Null
    $dt.Rows.Add("SQLAgentOperatorRole para JOBS", "JOB") | Out-Null
    $dt.Rows.Add("Propietario Base de Datos", "SYS") | Out-Null
    $dt.Rows.Add("Profiler o ALTER TRACE", "PRF") | Out-Null
    $dt.Rows.Add("sysadmin", "ALL") | Out-Null

    $combo.DisplayMember = "Texto"
    $combo.ValueMember = "Valor"
    $combo.DataSource = $dt

    $combo.SelectedValue = "RWSP"
}
# -----------------------------
# FORMULARIO: Agregar SQL
# -----------------------------
function Form_Agregar_SQL {
    . "$PSScriptRoot\ServidoresCredenciales.ps1"
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Agregar Permiso SQL"
    $form.Size = New-Object System.Drawing.Size(530, 380)
    $form.StartPosition = "CenterScreen"

    $form.Add_Shown({
            TiposAccesosSql $cmbTipo
            $srv = [int]$cmbServ.Text
            $srvConsultada = $cmbServ.Text
            $cmbBD.DataSource = $null    
            $cmbBD.Items.Clear()
            $cmbBD.Items.Add("Cargando bases de 10.0.0.$srvConsultada ...")
            $cmbBD.SelectedIndex = 0
            [System.Windows.Forms.Application]::DoEvents()
            CargarBasesDatos $srv $cmbBD
        })

    $lblServ = New-Object System.Windows.Forms.Label
    $lblServ.Text = "Servidor (10.0.0.x):"
    $lblServ.Location = "20,20"
    $cmbServ = New-Object System.Windows.Forms.ComboBox
    $cmbServ.Items.AddRange( $Global:UltimoOctetoSql )
    $cmbServ.Location = "190,20"
    $cmbServ.Text = "102"
    $cmbServ.Add_SelectedIndexChanged({
            $srvConsultada = $cmbServ.Text
            $cmbBD.DataSource = $null
            $cmbBD.Items.Clear()
            $cmbBD.Items.Add("Cargando bases de 10.0.0.$srvConsultada ...")
            $cmbBD.SelectedIndex = 0
            $srv = [int]$cmbServ.Text

            [System.Windows.Forms.Application]::DoEvents()            
            CargarBasesDatos $srv $cmbBD
        })

    $lblUsr = New-Object System.Windows.Forms.Label
    $lblUsr.Text = "Usuario:"
    $lblUsr.Location = "20,60"
    $txtUsr = New-Object System.Windows.Forms.TextBox
    $txtUsr.Location = "190,60"
    $txtUsr.Width = 200
    $txtUsr.Text = "mcobos"

    $lblTipo = New-Object System.Windows.Forms.Label
    $lblTipo.Text = "Acceso:"
    $lblTipo.Location = "20,100"
        
    $cmbTipo = New-Object System.Windows.Forms.ComboBox
    $cmbTipo.DropDownStyle = "DropDownList"
    $cmbTipo.Location = "190,100"
    $cmbTipo.Width = 280
    #TiposAccesosSql $cmbTipo    # Invoca a la funcion    

    $lblBD = New-Object System.Windows.Forms.Label
    $lblBD.Text = "Base de datos:"
    $lblBD.Location = "20,140"

    $cmbBD = New-Object System.Windows.Forms.ComboBox
    $cmbBD.Location = "190,140"
    $cmbBD.Width = 280
    $cmbBD.DropDownStyle = "DropDownList"

    $lblDur = New-Object System.Windows.Forms.Label
    $lblDur.Text = "Horas (<49):"
    $lblDur.Location = "20,180"
    $txtDur = New-Object System.Windows.Forms.TextBox
    $txtDur.Location = "170,180"
    $txtDur.Width = 60
    $txtDur.Text = "48"

    $lblExp = New-Object System.Windows.Forms.Label
    $lblExp.Text = "Expira (YYYY-MM-DD HH:mm) o vacio:"
    $lblExp.Location = "20,220"
    $lblExp.Width = 190
    $txtExp = New-Object System.Windows.Forms.TextBox
    $txtExp.Location = "220,220"
    $txtExp.Width = 150
    $txtExp.Text = (Get-Date).AddDays(2).ToString("yyyy-MM-dd HH:mm")

    #Boton Ejecutar
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Ejecutar"
    $btnOK.Location = "150,280"
    $btnOK.Add_Click({
            $codBd = $cmbBD.SelectedValue
            $nomBd = $cmbBD.Text
            $tipoAcceso = $cmbTipo.SelectedValue
            if ($txtExp.Text -eq "NULL" -or $txtExpira.Text -eq "$null" -or $txtExp.Text -eq "") {
                $expira = $null
            }
            else {
                $expira = $txtExp.Text
            }
            $psArgs = @(
                "-Serv", $cmbServ.Text
                "-Usr", $txtUsr.Text
                "-TipoAcceso", $TipoAcceso
                "-BaseDato", $codBd
                "-DuracionHoras", $txtDur.Text
            )

            if ($null -ne $expira -and $expira -ne "") {
                $psArgs += "-Expira"
                $psArgs += $expira
            }
            $resultado = powershell -ExecutionPolicy Bypass -File ".\sqlAdd.ps1" @psArgs 2>&1
            <#
            $resultado = powershell -ExecutionPolicy Bypass -File ".\sqlAdd.ps1" `
                -Serv $cmbServ.Text `
                -Usr $txtUsr.Text `
                -TipoAcceso $tipoAcceso `
                -BaseDato $codBd `
                -DuracionHoras $txtDur.Text `
                -Expira $expira 2>&1
            #>
            # Mostrar resultado
            [System.Windows.Forms.MessageBox]::Show($resultado -join "`n", "Resultado sqlAdd.ps1")            
        })
    # Botón Cancelar
    $btnCancelar = New-Object System.Windows.Forms.Button
    $btnCancelar.Text = "Cancelar"
    $btnCancelar.Location = "280,280"
    $btnCancelar.Add_Click({
            $form.Close()
        })

    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })

    $form.Controls.AddRange(@(
            $lblServ, $cmbServ, $lblUsr, $txtUsr, $lblTipo, $cmbTipo, $lblBD, $cmbBD,
            $lblDur, $txtDur, $lblExp, $txtExp, $btnOK, $btnCancelar
        ))
    $form.ShowDialog()
}

# ----------------------------------
# FORMULARIO: Revocar SQL por unidad
# ----------------------------------
function Form_Revocar_Unit_SQL {
    . "$PSScriptRoot\ServidoresCredenciales.ps1"
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Revocar Permiso Unitario SQL"
    $form.Size = New-Object System.Drawing.Size(530, 320)
    $form.StartPosition = "CenterScreen"
    $form.Add_Shown({
            TiposAccesosSql $cmbTipo
            $srv = [int]$cmbServ.Text
            $srvConsultada = $cmbServ.Text
            $cmbBD.DataSource = $null    
            $cmbBD.Items.Clear()
            $cmbBD.Items.Add("Cargando bases de 10.0.0.$srvConsultada ...")
            $cmbBD.SelectedIndex = 0
            [System.Windows.Forms.Application]::DoEvents()
            CargarBasesDatos $srv $cmbBD
        })

    $lblServ = New-Object System.Windows.Forms.Label
    $lblServ.Text = "Servidor (10.0.0.x):"
    $lblServ.Location = "20,20"
    # $txtServ = New-Object System.Windows.Forms.TextBox
    $cmbServ = New-Object System.Windows.Forms.ComboBox
    $cmbServ.Items.AddRange($Global:UltimoOctetoSql)
    $cmbServ.Location = "190,20"
    $cmbServ.Text = "102"
    $cmbServ.Add_SelectedIndexChanged({            
            $srv = [int]$cmbServ.Text
            $srvConsultada = $cmbServ.Text
            $cmbBD.DataSource = $null    
            $cmbBD.Items.Clear()
            $cmbBD.Items.Add("Cargando bases de 10.0.0.$srvConsultada ...")
            $cmbBD.SelectedIndex = 0
            [System.Windows.Forms.Application]::DoEvents()
            CargarBasesDatos $srv $cmbBD
        })

    $lblUsr = New-Object System.Windows.Forms.Label
    $lblUsr.Text = "Usuario:"
    $lblUsr.Location = "20,60"
    $txtUsr = New-Object System.Windows.Forms.TextBox
    $txtUsr.Location = "190,60"
    $txtUsr.Width = 200
    $txtUsr.Text = "mcobos"

    $lblTipo = New-Object System.Windows.Forms.Label
    $lblTipo.Text = "Acceso:"
    $lblTipo.Location = "20,100"
    # Crear clase simple para los elementos del ComboBox
    $cmbTipo = New-Object System.Windows.Forms.ComboBox
    $cmbTipo.DropDownStyle = "DropDownList"
    $cmbTipo.Location = "190,100"
    $cmbTipo.Width = 280
    #TiposAccesosSql $cmbTipo    # Invoca a la funcion

    $lblBD = New-Object System.Windows.Forms.Label
    $lblBD.Text = "Base de datos:"
    $lblBD.Location = "20,140"
    $cmbBD = New-Object System.Windows.Forms.ComboBox
    $cmbBD.Location = "190,140"
    $cmbBD.Width = 280
    $cmbBD.DropDownStyle = "DropDownList"

    #Boton Ejecutar
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Ejecutar"
    $btnOK.Location = "150,180"
    $btnOK.Add_Click({
            $tipoAcceso = $cmbTipo.SelectedValue
            $codBd = $cmbBD.SelectedValue
            $nomBd = $cmbBD.Text
            #Write-Host "$codBd   $nomBd    $tipoAcceso"            
            #$resultado = powershell -ExecutionPolicy Bypass -File ".\removeSqlUnit.ps1" `
            $resultado = powershell -ExecutionPolicy Bypass -File ".\sqlRemove.ps1" `
                -Serv $cmbServ.Text `
                -Usr $txtUsr.Text `
                -TipoAcceso $tipoAcceso `
                -BaseDato $codBD 2>&1
            # Mostrar resultado
            [System.Windows.Forms.MessageBox]::Show($resultado -join "`n", "Resultado sqlRemove.ps1")            
        })
    # Botón Cancelar
    $btnCancelar = New-Object System.Windows.Forms.Button
    $btnCancelar.Text = "Cancelar"
    $btnCancelar.Location = "280, 180"
    $btnCancelar.Add_Click({
            $form.Close()
        })

    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })

    $form.Controls.AddRange(@(
            $lblServ, $cmbServ, $lblUsr, $txtUsr, $lblTipo, $cmbTipo, $lblBD, $cmbBD,
            $btnOK, $btnCancelar
        ))
    $form.ShowDialog()
}

# -----------------------------
# FORMULARIO: Revocar RDP
# -----------------------------
function Form_Revocar_RDP {
    . "$PSScriptRoot\ServidoresCredenciales.ps1"
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Revocar Permiso RDP"
    $form.Size = New-Object System.Drawing.Size(400, 250)
    $form.StartPosition = "CenterScreen"

    $lblServ = New-Object System.Windows.Forms.Label
    $lblServ.Text = "Servidor:"
    $lblServ.Location = "20, 20"
    $cmbServ = New-Object System.Windows.Forms.ComboBox
    # $txtServ = New-Object System.Windows.Forms.TextBox
    # $txtServ.Location = "150, 20"
    $cmbServ.Location = "150, 20"
    $cmbServ.Items.AddRange($Global:ServidoresIpLocal)
    $cmbServ.Text = "10.0.0.102"


    $lblDominio = New-Object System.Windows.Forms.Label
    $lblDominio.Text = "Tipo:"
    $lblDominio.Location = "20,60"
    $lblDominio.Width = 40

    # Crear clase simple para los elementos del ComboBox
    $itemsTipoDominio = @(
        @{ Texto = "FIDENSLAT"; Valor = "FIDENSLAT\" }
        @{ Texto = "LOCAL"; Valor = ".\" }
    )
    $cmbDominio = New-Object System.Windows.Forms.ComboBox
    $cmbDominio.DropDownStyle = "DropDownList"
    # Indicar qué propiedad se muestra y cuál es el valor interno
    $cmbDominio.DisplayMember = "Texto"
    $cmbDominio.ValueMember = "Valor"
    $cmbDominio.Location = "60,60"
    $cmbDominio.Width = 100
    # Cargar los elementos
    foreach ($item in $itemsTipoDominio) {
        $obj = New-Object PSObject -Property $item
        $cmbDominio.Items.Add($obj)
    }
    $cmbDominio.SelectedIndex = ($cmbDominio.Items | ForEach-Object { $_.Valor } ).IndexOf("FIDENSLAT\")


    $lblUsr = New-Object System.Windows.Forms.Label
    $lblUsr.Text = "Usuario:"
    $lblUsr.Location = "170, 60"    
    $lblUsr.Width = 70
    $txtUsr = New-Object System.Windows.Forms.TextBox
    $txtUsr.Location = "240, 60"
    $txtUsr.Width = 100
    $txtUsr.Text = "mcobos"

    $lblGrp = New-Object System.Windows.Forms.Label
    $lblGrp.Text = "Grupo:"
    $lblGrp.Location = "20, 100"
    $cmbGrp = New-Object System.Windows.Forms.ComboBox
    $cmbGrp.Location = "150, 100"
    $cmbGrp.Items.AddRange(@("RDU", "ADM"))
    $cmbGrp.Text = "RDU"
    #Boton Ejecutar
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Ejecutar"
    $btnOK.Location = "100, 150"
    $btnOK.Add_Click({
            # Obtener valor real del tipo de acceso
            if ($null -ne $cmbDominio.SelectedItem) {
                $tipoDominio = $cmbDominio.SelectedItem.Valor
                # Write-Host "DEGUG: cuanto vale $tipoDominio , es diferente de null" -ForegroundColor Yellow
            }
            else {
                # fallback: usar el texto y buscar el valor correcto
                $tipoDominio = ($itemsTipoDominio | Where-Object { $_.Texto -eq $cmbDominio.Text }).Valor
                Write-Host "DEGUG: cuanto vale $tipoDominio , es igual a null" -ForegroundColor Yellow
            }            
            $usrdominio = $tipoDominio + $txtUsr.Text
            # Write-Host "DEGUG: cuanto vale usrdominio $usrdominio" -ForegroundColor Yellow
            $resultado = powershell -ExecutionPolicy Bypass -File ".\rdpRemove.ps1" `
                -Servidores $cmbServ.Text `
                -Usuario $usrdominio `
                -GrupoIn $cmbGrp.Text 2>&1
            # Mostrar resultado
            [System.Windows.Forms.MessageBox]::Show($resultado -join "`n", "Resultado rdpRemove.ps1")
        })
    # Botón Cancelar
    $btnCancelar = New-Object System.Windows.Forms.Button
    $btnCancelar.Text = "Cancelar"
    $btnCancelar.Location = "200, 150"
    $btnCancelar.Add_Click({
            $form.Close()
        })

    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })

    $form.Controls.AddRange(@($lblServ, $cmbServ, $lblDominio, $cmbDominio, $lblUsr, $txtUsr, $lblGrp, $cmbGrp, $btnOK, $btnCancelar))
    $form.ShowDialog()
}

# -----------------------------------
# FORMULARIO: Revocar SQL Masivamente
# -----------------------------------
function Form_Revocar_Masivo_SQL {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Marcar FINALIZADO en AdminFidens, permisos Revocados SQL"
    $form.Size = New-Object System.Drawing.Size(450, 180)
    $form.StartPosition = "CenterScreen"

    $lblText = New-Object System.Windows.Forms.Label
    $lblText.Text = "Marca para cada servidor de FIDENS  en AdminFidens como FINALIZADOS los revocados SQL dentro del intervalo de las ultimas 48 horas"
    $lblText.Location = "15, 20" 
    $lblText.Width = 400
    $lblText.Height = 60
    # Boton Ejecutar
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Ejecutar"
    $btnOK.Location = "120, 100"
    $btnOK.Add_Click({
            $script = ".\sqlMasivoRemove.ps1"
            powershell -ExecutionPolicy Bypass -Command $script
            [System.Windows.Forms.MessageBox]::Show("Accesos revocados SQL Finalizados")
        })
    # Botón Cancelar
    $btnCancelar = New-Object System.Windows.Forms.Button
    $btnCancelar.Text = "Cancelar"
    $btnCancelar.Location = "220, 100"
    $btnCancelar.Add_Click({
            $form.Close()
        })

    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })

    $form.Controls.AddRange(@($lblText, $btnOK, $btnCancelar))
    $form.ShowDialog()
}

# -----------------------------------
# FORMULARIO: Revocar Azure SQL Masivamente
# -----------------------------------
function Form_Revocar_Azure_Masivo_SQL {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Marcar FINALIZADO en AdminFidens, permisos Revocados AZURE SQL"
    $form.Size = New-Object System.Drawing.Size(450, 180)
    $form.StartPosition = "CenterScreen"

    $lblText = New-Object System.Windows.Forms.Label
    $lblText.Text = "Marca para cada base de datos en el servidor Azure de FIDENS en AdminFidens como FINALIZADOS los revocados SQL dentro del intervalo de las ultimas 48 horas"
    $lblText.Location = "15, 20" 
    $lblText.Width = 400
    $lblText.Height = 60
    # Boton Ejecutar
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Ejecutar"
    $btnOK.Location = "120, 100"
    $btnOK.Add_Click({
            $script = ".\sqlAzMasivoRemove.ps1"
            powershell -ExecutionPolicy Bypass -Command $script
            [System.Windows.Forms.MessageBox]::Show("Accesos revocados Azure SQL Finalizados")
        })
    # Botón Cancelar
    $btnCancelar = New-Object System.Windows.Forms.Button
    $btnCancelar.Text = "Cancelar"
    $btnCancelar.Location = "220, 100"
    $btnCancelar.Add_Click({
            $form.Close()
        })

    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })

    $form.Controls.AddRange(@($lblText, $btnOK, $btnCancelar))
    $form.ShowDialog()
}

# -----------------------------
# FORMULARIO: Revocar RDP Masivo
# -----------------------------
function Form_Revocar_RDP_MASIVO {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Marcar FINALIZADO en AdminFidens los permisos Revocados RDP"
    $form.Size = New-Object System.Drawing.Size(450, 200)
    $form.StartPosition = "CenterScreen"

    $lblText = New-Object System.Windows.Forms.Label
    $lblText.Text = "Analiza servidores de FIDENS y marca en AdminFidens como FINALIZADOS los revocados RDP dentro del intervalo de las ultimas 48 horas"
    $lblText.Location = "20, 20" 
    $lblText.Width = 400
    $lblText.Height = 60
    # Boton Ejecutar
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Ejecutar"
    $btnOK.Location = "100, 100"
    $btnOK.Add_Click({
            $script = ".\rdpMasivoRemove.ps1"
            powershell -ExecutionPolicy Bypass -Command $script
            [System.Windows.Forms.MessageBox]::Show("Revocatoria de RDP Finalizado")
        })
    # Botón Cancelar
    $btnCancelar = New-Object System.Windows.Forms.Button
    $btnCancelar.Text = "Cancelar"
    $btnCancelar.Location = "200, 100"
    $btnCancelar.Add_Click({
            $form.Close()
        })

    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })

    $form.Controls.AddRange(@($lblText, $btnOK, $btnCancelar))
    $form.ShowDialog()
}

# -----------------------------
# FORMULARIO: Listar accesos de AdminFidens RDP y SQL
# -----------------------------
function Form_Listar_Accesos {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Listas de Control Permisos Asignados, Revocados o Solicitados RDP y SQL"
    $form.Size = New-Object System.Drawing.Size(480, 250)
    $form.StartPosition = "CenterScreen"
    $form.Add_Shown({
            $cmbOrdRdu.DataSource = $null    
            $cmbOrdRdu.Items.Clear()
            OrdenamientoPermisosRdp $cmbOrdRdu
            $cmbOrdSql.DataSource = $null    
            $cmbOrdSql.Items.Clear()
            OrdenamientoPermisosSql $cmbOrdSql
        })

    $lblEstado = New-Object System.Windows.Forms.Label
    $lblEstado.Text = "Estado:"
    $lblEstado.Location = "20, 20"
    $lblEstado.Width = 150
    $cmbEstado = New-Object System.Windows.Forms.ComboBox
    $cmbEstado.Location = "200, 20"
    $cmbEstado.Width = 200
    $cmbEstado.Items.AddRange(@("ASIGNADO", "REVOCADO", "TODO"))
    $cmbEstado.Text = "TODO"

    $lblOrdRdu = New-Object System.Windows.Forms.Label
    $lblOrdRdu.Text = "Ordenar Informe RDP por:"
    $lblOrdRdu.Location = "20, 60"
    $lblOrdRdu.Width = 150

    $cmbOrdRdu = New-Object System.Windows.Forms.ComboBox
    $cmbOrdRdu.DropDownStyle = "DropDownList"
    $cmbOrdRdu.Location = "200, 60"
    $cmbOrdRdu.Width = 280

    $cmbOrdSql = New-Object System.Windows.Forms.ComboBox
    $cmbOrdSql.DropDownStyle = "DropDownList"
    $cmbOrdSql.Location = "200, 100"
    $cmbOrdSql.Width = 200

    $lblDiasAtras = New-Object System.Windows.Forms.Label
    $lblDiasAtras.Text = "Dias Atras:"
    $lblDiasAtras.Location = "20, 140"
    $lblDiasAtras.Width = 150
    $txtDiasAtras = New-Object System.Windows.Forms.TextBox
    $txtDiasAtras.Location = "200, 140"
    $txtDiasAtras.Width = 150
    $txtDiasAtras.Text = "1"

    # Boton Ejecutar
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Ejecutar"
    $btnOK.Location = "100, 175"
    $btnOK.Add_Click({
            $ordenRdu = $cmbOrdRdu.SelectedValue
            $ordenSql = $cmbOrdSql.SelectedValue
            powershell -ExecutionPolicy Bypass -File `".\infoSqlRdp.ps1`" `
                -Estado `"$($cmbEstado.Text)`" `
                -OrdRdu `"$($cmbOrdRdu.SelectedItem.Valor)`"  `
                -OrdSql `"$($cmbOrdSql.SelectedItem.Valor)`"   `
                -DiasAtras `"$($txtDiasAtras.Text)`" 2>&1
            # Mostrar resultado
            #[System.Windows.Forms.MessageBox]::Show($resultado -join "`n", "Html Generado infoSqlRdp.ps1")
            # [System.Windows.Forms.MessageBox]::Show("Html Generado infoSqlRdp.ps1")

            <# Ruta CSV
            $csvPath = "C:\Temp\resultado_asignados.csv"

            # ----- Ejecutar script y capturar salida -----
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo.FileName = "powershell.exe"
            $process.StartInfo.Arguments = "-ExecutionPolicy Bypass -File `".\infoSqlRdp.ps1`" `"$($cmbEstado.Text)`" `"$($cmbOrdRdu.SelectedItem.Valor)`" `"$($cmbOrdSql.SelectedItem.Valor)`" `"$($txtDiasAtras.Text)`""
            $process.StartInfo.RedirectStandardOutput = $true
            $process.StartInfo.RedirectStandardError = $true
            $process.StartInfo.UseShellExecute = $false
            $process.StartInfo.CreateNoWindow = $true

            $process.Start() | Out-Null

            $output = $process.StandardOutput.ReadToEnd()            

            $process.WaitForExit()


            # =====================================================================
            # 1) FILTRAR LÍNEAS INDESEADAS (UE, UB, BU...)
            # =====================================================================
            $lineasIgnorar = @("UE", "UB", "BU", "BE", "EB", "FI", "FF", "RV", "ID")

            $outputFiltrado = $output -split "`r?`n" | Where-Object {
                $_.Trim() -ne "" -and $_.Trim() -notin $lineasIgnorar
            }


            # =====================================================================
            # 2) GUARDAR CSV SIN CABECERA NI COLUMNA
            # =====================================================================
            $outputFiltrado -join "`r`n" | Out-File -FilePath $csvPath -Encoding UTF8


            # =====================================================================
            # 3) MOSTRAR EN VENTANA HIJA
            # =====================================================================
            $resultForm = New-Object System.Windows.Forms.Form
            $resultForm.Text = "Resultados de la Consulta"
            $resultForm.Size = New-Object System.Drawing.Size(900, 600)

            $txtOutput = New-Object System.Windows.Forms.TextBox
            $txtOutput.Multiline = $true
            $txtOutput.ScrollBars = "Both"
            $txtOutput.ReadOnly = $true
            $txtOutput.Font = New-Object System.Drawing.Font("Consolas", 10)
            $txtOutput.Dock = "Fill"
            $txtOutput.WordWrap = $false
            $txtOutput.Text = ($outputFiltrado -join "`r`n")

            $resultForm.Controls.Add($txtOutput)
            $resultForm.ShowDialog()            

            # Mensaje final
            [System.Windows.Forms.MessageBox]::Show("Informe generado. CSV guardado en:`n$csvPath")
            #>

        })


    # Botón Cancelar
    $btnCancelar = New-Object System.Windows.Forms.Button
    $btnCancelar.Text = "Cancelar"
    $btnCancelar.Location = "200, 175"
    $btnCancelar.Add_Click({
            $form.Close()
        })

    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })

    $form.Controls.AddRange(@($lblEstado, $cmbEstado, $lblOrdRdu, $cmbOrdRdu, $lblOrdSql, $cmbOrdSql, $lblDiasAtras, $txtDiasAtras, $btnOK, $btnCancelar))
    $form.ShowDialog()
}

function Form_Rdp_Update_NumReg {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Modificar NumReg para accesosTemp"
    $form.Size = New-Object System.Drawing.Size(270, 200)
    $form.StartPosition = "CenterScreen"

    $lblExplica = New-Object System.Windows.Forms.Label
    $lblExplica.Text = "Vincula manualmente Id de 49.accesoTempRDP con el numero de registro de ProyFidens"
    $lblExplica.Location = "5,10"
    $lblExplica.Width = 250
    $form.Controls.Add($lblExplica)
    # Campo para definir el id del permiso RDP
    $lblId = New-Object System.Windows.Forms.Label
    $lblId.Text = "Id en AccesoTempRDP:"
    $lblId.Location = "20,45"
    $lblId.Width = 150
    $form.Controls.Add($lblId)

    $txtId = New-Object System.Windows.Forms.TextBox
    $txtId.Location = "170,45"
    $txtId.Width = 50
    $form.Controls.Add($txtId)

    # Campo para definir el NumReg del permiso en ProyFidens
    $lblNumReg = New-Object System.Windows.Forms.Label
    $lblNumReg.Text = "NumReg en ProyFidens:"
    $lblNumReg.Location = "20,80"
    $lblNumReg.Width = 150
    $form.Controls.Add($lblNumReg)
    
    $txtNumReg = New-Object System.Windows.Forms.TextBox
    $txtNumReg.Location = "170,80"
    $txtNumReg.Width = 50
    $form.Controls.Add($txtNumReg)

    # Botón OK
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "OK"
    $btnOK.Width = 60
    $btnOK.Location = "40,115"
    $form.Controls.Add($btnOK)

    # Botón Cancel
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancelar"
    $btnCancel.Width = 60
    $btnCancel.Location = "130,115"

    $btnCancel.Add_Click({
            $form.Close()
        })
    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })
    $form.Controls.Add($btnCancel)

    # Acción OK
    $btnOK.Add_Click({
            $id = $txtId.Text
            $valNumReg = $txtNumReg.Text            
            [System.Windows.Forms.MessageBox]::Show( ".\sqlUpdateNumRegToIdPermiso.ps1 -IdPermiso $id -NumReg $valNumReg " )
            Start-Process powershell -ArgumentList "-File .\sqlUpdateNumRegToIdPermiso.ps1 -IdPermiso $id -NumReg $valNumReg "
            $form.Close()
        })

    $btnCancel.Add_Click({ $form.Close() })

    $form.ShowDialog()    
}

Add-Type -TypeDefinition @"
public class BaseDatoItem {
    public string Nombre { get; set; }
    public int Codigo { get; set; }

    public override string ToString() {
        return Nombre;  // Mostrar solo nombre
    }
}
"@
function Form_Sql_Add_Azure {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Agregar Acceso Azure SQL"
    $form.Size = New-Object System.Drawing.Size(650, 650)
    $form.StartPosition = "CenterScreen"

    # Servidor
    $lblSrv = New-Object System.Windows.Forms.Label
    $lblSrv.Text = "Servidor:"
    $lblSrv.Location = "20,20"
    $form.Controls.Add($lblSrv)

    $cmbSrv = New-Object System.Windows.Forms.ComboBox
    $cmbSrv.Location = "150,15"
    $cmbSrv.Width = 200
    $cmbSrv.DropDownStyle = "DropDownList"
    $cmbSrv.Items.AddRange(@(10, 49, 56, 61, 80, 86, 102))
    $cmbSrv.SelectedIndex = 0
    $form.Controls.Add($cmbSrv)

    # Lista MULTIPLE de BD
    $lblBD = New-Object System.Windows.Forms.Label
    $lblBD.Text = "Bases de Datos:"
    $lblBD.Location = "20,60"
    $form.Controls.Add($lblBD)

    $chkBD = New-Object System.Windows.Forms.CheckedListBox
    $chkBD.Location = "150,60"
    $chkBD.Size = "400,200"
    $chkBD.CheckOnClick = $true
    $form.Controls.Add($chkBD)

    # Cargar BD
    $cmbSrv.Add_SelectedIndexChanged({
            CargarBasesDatos_Multi $cmbSrv.SelectedItem $chkBD
        })

    CargarBasesDatos_Multi 10 $chkBD

    # Resto de campos (Usuario, Rol, etc.)
    $lblUsr = New-Object System.Windows.Forms.Label
    $lblUsr.Text = "Usuario:"
    $lblUsr.Location = "20,280"
    $form.Controls.Add($lblUsr)

    $txtUsr = New-Object System.Windows.Forms.TextBox
    $txtUsr.Location = "150,275"
    $txtUsr.Width = 200
    $form.Controls.Add($txtUsr)

    $lblTipo = New-Object System.Windows.Forms.Label
    $lblTipo.Text = "Tipo Acceso:"
    $lblTipo.Location = "20,320"
    $form.Controls.Add($lblTipo)

    $cmbTipo = New-Object System.Windows.Forms.ComboBox
    $cmbTipo.Location = "150,315"
    $cmbTipo.Width = 180
    $cmbTipo.Items.AddRange(@("R", "W", "RW", "SP", "SM", "PRF", "ALL"))
    $cmbTipo.SelectedIndex = 2
    $form.Controls.Add($cmbTipo)

    $lblNum = New-Object System.Windows.Forms.Label
    $lblNum.Text = "NumReg:"
    $lblNum.Location = "20,360"
    $form.Controls.Add($lblNum)

    $txtNum = New-Object System.Windows.Forms.TextBox
    $txtNum.Location = "150,355"
    $txtNum.Width = 80
    $form.Controls.Add($txtNum)

    $lblCod = New-Object System.Windows.Forms.Label
    $lblCod.Text = "CodUser:"
    $lblCod.Location = "20,400"
    $form.Controls.Add($lblCod)

    $txtCod = New-Object System.Windows.Forms.TextBox
    $txtCod.Location = "150,395"
    $txtCod.Width = 120
    $form.Controls.Add($txtCod)

    $lblExp = New-Object System.Windows.Forms.Label
    $lblExp.Text = "Expira (YYYY-mm-dd HH:mm):"
    $lblExp.Location = "20,440"
    $form.Controls.Add($lblExp)

    $txtExp = New-Object System.Windows.Forms.TextBox
    $txtExp.Location = "250,435"
    $txtExp.Width = 160
    $txtExp.Text = (Get-Date).AddDays(3).ToString("yyyy-MM-dd HH:mm")
    $form.Controls.Add($txtExp)

    # Botón OK
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "OK"
    $btnOK.Width = 120
    $btnOK.Location = "150,500"
    $form.Controls.Add($btnOK)

    # Botón Cancel
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancelar"
    $btnCancel.Width = 120
    $btnCancel.Location = "300,500"

    $btnCancel.Add_Click({
            $form.Close()
        })
    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })
    $form.Controls.Add($btnCancel)

    # Acción OK
    $btnOK.Add_Click({

            #$servidor = $cmbSrv.SelectedItem
            $servidor = "sql-ginger.database.windows.net"

            # Obtener multiples BD seleccionadas y construir un arreglo real
            $listaBD = @()
            foreach ($item in $chkBD.CheckedItems) {
                $listaBD += $item.Nombre
            }
            # [System.Windows.Forms.MessageBox]::Show(($listaBD -join ','))

            # Construir argumentos individuales entre comillas
            $usr = $txtUsr.Text
            $tipo = $cmbTipo.SelectedItem
            $numReg = if ($txtNum.Text -eq "") { $null } else { [int]$txtNum.Text }
            $codUser = if ($txtCod.Text -eq "") { $null } else { $txtCod.Text }
            $expira = if ($txtExp.Text -eq "") { $null } else { $txtExp.Text }
            $argBases = $listaBD | ForEach-Object { "`"$($_)`"" }             

            # CONSTRUCCION DEL COMANDO LINEA POR LINEA
            $argList = "-File .\sqlAzAdd.ps1 "
            $argList += "-Servidor `"$Servidor`" "
            # Bases
            $argBases = $listaBD | ForEach-Object { "`"$($_)`"" }            
            $argList += "-BaseDato "
            $argList += $listaBD -join ","            

            # Usuario y demás parámetros
            $argList += " -Usr `"$Usr`" "
            $argList += "-TipoAcceso `"$Tipo`" "
            $argList += "-NumReg $NumReg "
            $argList += "-CodUser `"$CodUser`" "
            $argList += "-Expira `"$Expira`" "

            [System.Windows.Forms.MessageBox]::Show(($argList | Out-String))
            Start-Process powershell -ArgumentList $argList -NoNewWindow
            $form.Close()
        })

    $btnCancel.Add_Click({ $form.Close() })

    $form.ShowDialog()
}

function Form_Sql_Remove_Azure {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Agregar Acceso Azure SQL"
    $form.Size = New-Object System.Drawing.Size(650, 650)
    $form.StartPosition = "CenterScreen"

    # Servidor
    $lblSrv = New-Object System.Windows.Forms.Label
    $lblSrv.Text = "Servidor:"
    $lblSrv.Location = "20,20"
    $form.Controls.Add($lblSrv)

    $cmbSrv = New-Object System.Windows.Forms.ComboBox
    $cmbSrv.Location = "150,15"
    $cmbSrv.Width = 200
    $cmbSrv.DropDownStyle = "DropDownList"
    $cmbSrv.Items.AddRange(@(10, 49, 56, 61, 80, 86, 102))
    $cmbSrv.SelectedIndex = 0
    $form.Controls.Add($cmbSrv)

    # Lista MULTIPLE de BD
    $lblBD = New-Object System.Windows.Forms.Label
    $lblBD.Text = "Bases de Datos:"
    $lblBD.Location = "20,60"
    $form.Controls.Add($lblBD)

    $chkBD = New-Object System.Windows.Forms.CheckedListBox
    $chkBD.Location = "150,60"
    $chkBD.Size = "400,200"
    $chkBD.CheckOnClick = $true
    $form.Controls.Add($chkBD)

    # Cargar BD
    $cmbSrv.Add_SelectedIndexChanged({
            CargarBasesDatos_Multi $cmbSrv.SelectedItem $chkBD
        })

    CargarBasesDatos_Multi 10 $chkBD

    # Resto de campos (Usuario, Rol, etc.)
    $lblUsr = New-Object System.Windows.Forms.Label
    $lblUsr.Text = "Usuario:"
    $lblUsr.Location = "20,280"
    $form.Controls.Add($lblUsr)

    $txtUsr = New-Object System.Windows.Forms.TextBox
    $txtUsr.Location = "150,275"
    $txtUsr.Width = 200
    $form.Controls.Add($txtUsr)

    $lblTipo = New-Object System.Windows.Forms.Label
    $lblTipo.Text = "Tipo Acceso:"
    $lblTipo.Location = "20,320"
    $form.Controls.Add($lblTipo)

    $cmbTipo = New-Object System.Windows.Forms.ComboBox
    $cmbTipo.Location = "150,315"
    $cmbTipo.Width = 180
    $cmbTipo.Items.AddRange(@("R", "W", "RW", "SP", "SM", "PRF", "ALL"))
    $cmbTipo.SelectedIndex = 2
    $form.Controls.Add($cmbTipo)

    $lblNum = New-Object System.Windows.Forms.Label
    $lblNum.Text = "NumReg:"
    $lblNum.Location = "20,360"
    $form.Controls.Add($lblNum)

    $txtNum = New-Object System.Windows.Forms.TextBox
    $txtNum.Location = "150,355"
    $txtNum.Width = 80
    $form.Controls.Add($txtNum)

    $lblCod = New-Object System.Windows.Forms.Label
    $lblCod.Text = "CodUser:"
    $lblCod.Location = "20,400"
    $form.Controls.Add($lblCod)

    $txtCod = New-Object System.Windows.Forms.TextBox
    $txtCod.Location = "150,395"
    $txtCod.Width = 120
    $form.Controls.Add($txtCod)

    # Botón OK
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "OK"
    $btnOK.Width = 120
    $btnOK.Location = "150,500"
    $form.Controls.Add($btnOK)

    # Botón Cancel
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancelar"
    $btnCancel.Width = 120
    $btnCancel.Location = "300,500"

    $btnCancel.Add_Click({
            $form.Close()
        })
    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })
    $form.Controls.Add($btnCancel)

    # Acción OK
    $btnOK.Add_Click({

            #$servidor = $cmbSrv.SelectedItem
            $servidor = "sql-ginger.database.windows.net"

            # Obtener multiples BD seleccionadas
            $listaBD = @()
            foreach ($item in $chkBD.CheckedItems) {
                $listaBD += , $item.Nombre
            }
            # $listaBDString = '"' + ($listaBD -join '","') + '"'
            # 🔍 DEBUG
            #[System.Windows.Forms.MessageBox]::Show("BD seleccionadas:`n" + ($listaBD -join "`n"))
            #[System.Windows.Forms.MessageBox]::Show( $listaBDString )
            $usr = $txtUsr.Text
            $tipo = $cmbTipo.SelectedItem
            $numReg = if ($txtNum.Text -eq "") { $null } else { [int]$txtNum.Text }
            $codUser = if ($txtCod.Text -eq "") { $null } else { $txtCod.Text }
            #$expira = if ($txtExp.Text -eq "") { $null } else { $txtExp.Text }



            # CONSTRUCCION DEL COMANDO LINEA POR LINEA
            $argList = "-File .\sqlAzRemove.ps1 "
            $argList += "-Servidor `"$servidor`" "
            # Bases
            #$argBases = $listaBD | ForEach-Object { "`"$($_)`"" }
            $argList += "-BaseDato "
            $argList += $listaBD -join ","

            # Usuario y demás parámetros
            $argList += " -Usr `"$Usr`" "
            $argList += "-TipoAcceso `"$Tipo`" "
            if ($null -ne $numReg) {
                $argList += "-NumReg $NumReg "
            }
            if ($null -ne $codUser) {
                $argList += "-CodUser `"$CodUser`" "
            }

            [System.Windows.Forms.MessageBox]::Show(($argList | Out-String))
            Start-Process powershell -ArgumentList $argList -NoNewWindow


            #[System.Windows.Forms.MessageBox]::Show( ".\sqlAzRemove.ps1 -Servidor `"$servidor`" -BaseDato `"$($listaBD -join '`",`"')`" -Usr `"$usr`" -TipoAcceso `"$tipo`" -NumReg $numReg -CodUser `"$CodUser`" " )
            #Start-Process powershell -ArgumentList "-File .\sqlAzRemove.ps1 -Servidor `"$servidor`" -BaseDato `"$($listaBD -join '`",`"')`" -Usr `"$usr`" -TipoAcceso `"$tipo`" -NumReg $numReg -CodUser `"$codUser`" "
            $form.Close()
        })

    $btnCancel.Add_Click({ $form.Close() })

    $form.ShowDialog()
}

# -----------------------------
# FORMULARIO: Revocar RDP Masivo
# -----------------------------
function Form_Autorizados_Fidens {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Lista de solicitudes posiblemente autorizadas en AdminFidens para establecer los accesos"
    $form.Size = New-Object System.Drawing.Size(450, 200)
    $form.StartPosition = "CenterScreen"

    $lblText = New-Object System.Windows.Forms.Label
    $lblText.Text = "Analiza datos de AdminFIDENS las que estan en estado SOLICITADO"
    $lblText.Location = "20, 20" 
    $lblText.Width = 400
    $lblText.Height = 60
    # Boton Ejecutar
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Ejecutar"
    $btnOK.Location = "100, 100"
    $btnOK.Add_Click({
            $script = ".\solicitudesAprobadas.ps1"
            powershell -ExecutionPolicy Bypass -Command $script
            #[System.Windows.Forms.MessageBox]::Show("Generadas listas de solicitudes aprobadas en HTML")
        })
    # Botón Cancelar
    $btnCancelar = New-Object System.Windows.Forms.Button
    $btnCancelar.Text = "Cancelar"
    $btnCancelar.Location = "200, 100"
    $btnCancelar.Add_Click({
            $form.Close()
        })

    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })

    $form.Controls.AddRange(@($lblText, $btnOK, $btnCancelar))
    $form.ShowDialog()
}


function OrdenamientoPermisosRdp($combo) {
    $combo.DataSource = $null
    $combo.Items.Clear()

    $dt = New-Object System.Data.DataTable
    $dt.Columns.Add("Texto") | Out-Null
    $dt.Columns.Add("Valor") | Out-Null

    $dt.Rows.Add("Servidor, Usuario", "SU") | Out-Null
    $dt.Rows.Add("Usuario, Servidor", "US") | Out-Null
    $dt.Rows.Add("Servidor, Grupo", "SG") | Out-Null
    $dt.Rows.Add("Grupo, Servidor", "GS") | Out-Null
    $dt.Rows.Add("CodUser, Grupo", "CG") | Out-Null
    $dt.Rows.Add("Grupo, CodUser", "GC") | Out-Null
    $dt.Rows.Add("CodUser, Servidor", "Gs") | Out-Null
    $dt.Rows.Add("Servidor, CodUser", "SC") | Out-Null
    $dt.Rows.Add("Fecha Inicio DESC", "FI") | Out-Null
    $dt.Rows.Add("Fecha Fin DESC", "FF") | Out-Null
    $dt.Rows.Add("Revocado DESC", "RV") | Out-Null

    $combo.DisplayMember = "Texto"
    $combo.ValueMember = "Valor"
    $combo.DataSource = $dt

    $combo.SelectedValue = "FF"
}

function OrdenamientoPermisosSql($combo) {
    $combo.DataSource = $null
    $combo.Items.Clear()

    $dt = New-Object System.Data.DataTable
    $dt.Columns.Add("Texto") | Out-Null
    $dt.Columns.Add("Valor") | Out-Null

    $dt.Rows.Add("Usuario, Expira", "UE") | Out-Null
    $dt.Rows.Add("BaseDato, Usuario", "BU") | Out-Null
    $dt.Rows.Add("Usuario, BaseDato", "SG") | Out-Null
    $dt.Rows.Add("BaseDato, Expira", "BE") | Out-Null
    $dt.Rows.Add("Expira, BaseDato", "EB") | Out-Null
    $dt.Rows.Add("CodUser, BaseDato", "CB") | Out-Null
    $dt.Rows.Add("BaseDato, CodUser", "BC") | Out-Null
    $dt.Rows.Add("Fecha Inicio DESC", "FI") | Out-Null
    $dt.Rows.Add("Fecha Fin DESC", "FF") | Out-Null
    $dt.Rows.Add("Revocado DESC", "RV") | Out-Null
    $dt.Rows.Add("Indice DESC", "ID") | Out-Null


    $combo.DisplayMember = "Texto"
    $combo.ValueMember = "Valor"
    $combo.DataSource = $dt

    $combo.SelectedValue = "FF"
}

function Form_SFTP_Crea_Usuario {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Crear Usuario SFTP"
    $form.Size = New-Object System.Drawing.Size(420, 260)
    $form.StartPosition = "CenterScreen"

    # Label usuario
    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Text = "Usuario SFTP:"
    $lblUser.Location = "20,20"
    $form.Controls.Add($lblUser)

    # TextBox usuario
    $txtUser = New-Object System.Windows.Forms.TextBox
    $txtUser.Location = "140,20"
    $txtUser.Width = 220
    $txtUser.MaxLength = 20     # Limite de caracteres
    $form.Controls.Add($txtUser)
    
    # Label descripcion
    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text = "Descripcion:"
    $lblDesc.Location = "20,60"
    $form.Controls.Add($lblDesc)
    
    # TextBox descripcion
    $txtDesc = New-Object System.Windows.Forms.TextBox
    $txtDesc.Location = "140,60"
    $txtDesc.Width = 220
    $txtDesc.MaxLength = 48     # Limite de caracteres
    $form.Controls.Add($txtDesc)

    # Label contraseña
    $lblPass = New-Object System.Windows.Forms.Label
    $lblPass.Text = "Password Administrator:"
    $lblPass.Location = "20,100"
    $form.Controls.Add($lblPass)

    # TextBox contraseña (oculta)
    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Location = "180,100"
    $txtPass.Width = 180
    $txtPass.UseSystemPasswordChar = $true
    $form.Controls.Add($txtPass)

    # Botón ejecutar
    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = "Ejecutar"
    $btnRun.Location = "140,150"
    $form.Controls.Add($btnRun)

    $btnRun.Add_Click({
            $Usuario = $txtUser.Text
            $Descripcion = $txtDesc.Text
            $Password = $txtPass.Text
            $inicioProc = Get-Date

            if (!$Usuario -or !$Descripcion -or !$Password) {
                [System.Windows.Forms.MessageBox]::Show("Debe llenar todos los campos")
                return
            }

            $server = "10.0.0.53"

            # --- 1. Autenticación SMB ---
            $cmdNet = "net use \\$server\c$ /user:$server\Administrator `"$Password`""
            # Write-Host "DEBUG:: Ejecutando: $cmdNet"
            Write-Host "Ejecutando: para usuario Administrator"
            cmd.exe /c $cmdNet

            # Validar si conectó
            $check = net use | Select-String "\\\\$server\\c\$"
            # $check = (net use) -contains "*\\$server\c$*"
            if (!$check) {
                [System.Windows.Forms.MessageBox]::Show("Error: No se pudo autenticar con el servidor")
                return
            }

            # --- 2. Ejecutar PsExec ---
            $PsExecCmd = "PsExec64.exe \\$server -s powershell.exe -Command `"& 'C:\infraestructura\sftpCrearUserRemoto53.ps1' -Usuario '$Usuario' -Descripcion '$Descripcion'`""
            Write-Host "Ejecutando PsExec..."
            cmd.exe /c $PsExecCmd
            # --- 2.1 Copiar ZIP al equipo local ---
            $LocalFolder = "C:\Temp\llavesgeneradas"
            $RemoteFolder = "\\10.0.0.53\keys_zips"
            if (-not (Test-Path $LocalFolder)) {
                New-Item -ItemType Directory -Path $LocalFolder | Out-Null
            }
            Copy-Item "$RemoteFolder\$Usuario.zip" -Destination $LocalFolder -Force
            $zipFile = "$RemoteFolder\$Usuario.zip"
            if (Test-Path $zipFile) {
                Copy-Item $zipFile -Destination $LocalFolder -Force
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("ERROR: No se encontró el ZIP generado en el servidor.")
                return
            }
            # --- 3. Desconectar ---
            cmd.exe /c "net use \\$server\c$ /delete /y"
            $finProc = Get-Date
            $duracionProc = ($finProc - $inicioProc).ToString("hh\:mm\:ss")
            [System.Windows.Forms.MessageBox]::Show("Proceso completado en $duracionProc. Recibida llave e instrucciones en $LocalFolder\$Usuario.zip ")
        })

    $form.ShowDialog()
}

function Form_Azure_DBA {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Informe para DBA de Ginger"
    $form.Size = New-Object System.Drawing.Size(270, 200)
    $form.StartPosition = "CenterScreen"

    $lblExplica = New-Object System.Windows.Forms.Label
    $lblExplica.Text = "Informe para DBA de los accesos a cada Base de Azure Ginger"
    $lblExplica.Location = "5,10"
    $lblExplica.Width = 250
    $form.Controls.Add($lblExplica)

    # Botón OK
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "OK"
    $btnOK.Width = 60
    $btnOK.Location = "40,115"
    $form.Controls.Add($btnOK)

    # Botón Cancel
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancelar"
    $btnCancel.Width = 60
    $btnCancel.Location = "130,115"

    $btnCancel.Add_Click({
            $form.Close()
        })
    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })
    $form.Controls.Add($btnCancel)

    # Acción OK
    $btnOK.Add_Click({
            # [System.Windows.Forms.MessageBox]::Show( ".\sqlAzConsultarAccesos.ps1 " )
            Start-Process powershell -ArgumentList "-File .\sqlAzConsultarAccesos.ps1 "
            $form.Close()
        })

    $btnCancel.Add_Click({ $form.Close() })

    $form.ShowDialog()
}
function Form_Local_DBA {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Informe para DBA SQL de Locales"
    $form.Size = New-Object System.Drawing.Size(270, 200)
    $form.StartPosition = "CenterScreen"

    $lblExplica = New-Object System.Windows.Forms.Label
    $lblExplica.Text = "Informe para DBA de accesos a cada Base de SQL Locales"
    $lblExplica.Location = "5,10"
    $lblExplica.Width = 250
    $form.Controls.Add($lblExplica)

    # Botón OK
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "OK"
    $btnOK.Width = 60
    $btnOK.Location = "40,115"
    $form.Controls.Add($btnOK)

    # Botón Cancel
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancelar"
    $btnCancel.Width = 60
    $btnCancel.Location = "130,115"

    $btnCancel.Add_Click({
            $form.Close()
        })
    $form.KeyPreview = $true
    $form.Add_KeyDown({
            if ($_.KeyCode -eq "Escape") {
                $form.Close()
            }
        })
    $form.Controls.Add($btnCancel)

    # Acción OK
    $btnOK.Add_Click({
            # [System.Windows.Forms.MessageBox]::Show( ".\sqlAzConsultarAccesos.ps1 " )
            Start-Process powershell -ArgumentList "-File .\getRevisionSQL.ps1 "
            $form.Close()
        })

    $btnCancel.Add_Click({ $form.Close() })

    $form.ShowDialog()
}

# -----------------------------
# CIERRA EL FORMULARIO MENU
# -----------------------------
function Cerrar_Menu {
    $formMenu.Close()
}

# -----------------------------
# FORMULARIO PRINCIPAL (MENU)
# -----------------------------
$formMenu = New-Object System.Windows.Forms.Form
$formMenu.Text = "GESTION DE PERMISOS"
$formMenu.Size = New-Object System.Drawing.Size(600, 470)

$formMenu.StartPosition = "CenterScreen"
#$formMenu.BackColor = [System.Drawing.Color]::White


# Título superior grande
$lblTitulo = New-Object System.Windows.Forms.Label
$lblTitulo.Text = "GESTION DE PERMISOS"
#$lblTitulo.Font = New-Object System.Drawing.Font("Segoe UI", 14, "Bold")
$lblTitulo.AutoSize = $true
$lblTitulo.Left = 20
$lblTitulo.Top = 10
$formMenu.Controls.Add($lblTitulo)


$formMenu.Controls.Add( (NuevaOpcion -text "+ RDP Agregar Acceso" -y 30 -col 1 -onClick { Form_Agregar_RDP }) )
$formMenu.Controls.Add( (NuevaOpcion -text "+ SQL Agregar Acceso" -y 30 -col 2 -onClick { Form_Agregar_SQL }) )
$formMenu.Controls.Add( (NuevaOpcion -text "x RDP Revocar Acceso" -y 80 -col 1 -onClick { Form_Revocar_RDP }) )
$formMenu.Controls.Add( (NuevaOpcion -text "x SQL Revocar Acceso" -y 80 -col 2 -onClick { Form_Revocar_Unit_SQL }) )
$formMenu.Controls.Add( (NuevaOpcion -text "x RDP Finalizar Acceso Masivamente" -y 130 -col 1 -onClick { Form_Revocar_RDP_MASIVO }) )
$formMenu.Controls.Add( (NuevaOpcion -text "x SQL Finalizar Acceso Masivamente" -y 130 -col 2 -onClick { Form_Revocar_Masivo_SQL }) )
$formMenu.Controls.Add( (NuevaOpcion -text "* SQL AZURE Agregar Acceso" -y 180 -col 1 -onClick { Form_Sql_Add_Azure }) )
$formMenu.Controls.Add( (NuevaOpcion -text "* SQL AZURE Remover Acceso" -y 180 -col 2 -onClick { Form_Sql_Remove_Azure }) )
$formMenu.Controls.Add( (NuevaOpcion -text "* Vincula Id RDP con ProyFidens" -y 230 -col 1 -onClick { Form_Rdp_Update_NumReg }) )
$formMenu.Controls.Add( (NuevaOpcion -text "x SQL AZURE Finalizar Acceso Masivamente" -y 230 -col 2 -onClick { Form_Revocar_Azure_Masivo_SQL }) )
$formMenu.Controls.Add( (NuevaOpcion -text "* Informe Accesos SQL-RDP" -y 280 -col 1 -onClick { Form_Listar_Accesos }) )
$formMenu.Controls.Add( (NuevaOpcion -text "* Autorizadas Fidens" -y 280 -col 2 -onClick { Form_Autorizados_Fidens }) )
$formMenu.Controls.Add( (NuevaOpcion -text "  Info SQL Local DBA" -y 330 -col 1 -onClick { Form_Local_DBA }) )
$formMenu.Controls.Add( (NuevaOpcion -text "  Info SQL Azure DBA" -y 330 -col 2 -onClick { Form_Azure_DBA }) )
$formMenu.Controls.Add( (NuevaOpcion -text "  SFTP 10..53 Crea Usuario" -y 380 -col 1 -onClick { Form_SFTP_Crea_Usuario }) )
$formMenu.Controls.Add( (NuevaOpcion -text "  Salir" -y 380 -col 2 -onClick { Cerrar_Menu }) )

$formMenu.KeyPreview = $true
$formMenu.Add_KeyDown({
        if ($_.KeyCode -eq "Escape") {
            $formMenu.Close()
        }
    })

$formMenu.ShowDialog()