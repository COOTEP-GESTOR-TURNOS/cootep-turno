[CmdletBinding()]
param(
    [ValidateSet('generar', 'pendientes', 'activar-usuario')]
    [string]$Accion = 'generar',
    [int]$Semilla = 7,
    [ValidateRange(1, 3650)]
    [int]$Dias = 540,
    [ValidatePattern('^[a-zA-Z0-9_-]{1,24}$')]
    [string]$Lote = 'inicial',
    [string]$Id,
    [string]$Correo
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$infra = Join-Path $raiz 'infra'
$envCompose = Join-Path $infra '.env'
$apps = Join-Path $infra 'compose.apps.yml'
$datos = Join-Path $infra 'compose.datos.yml'
$node = @('exec', '-T', 'backend-principal', 'node', 'dist/cli/demo.js')
$python = @('exec', '-T', 'analitica', 'python', '-m', 'app.scripts.generar_demo')

function Invoke-ComposeDemo {
    param([string]$Archivo, [string[]]$Argumentos, [string]$Entrada)

    if ($Entrada) {
        Get-Content -LiteralPath $Entrada -Encoding UTF8 | & docker compose --env-file $envCompose -f $Archivo @Argumentos
    } else {
        & docker compose --env-file $envCompose -f $Archivo @Argumentos
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose devolvió el código $LASTEXITCODE. Repite la misma operación para reanudarla."
    }
}

function Invoke-PendientesDemo {
    param([string]$Catalogo, [string]$Seleccion, [string]$FechaCarga)

    Invoke-ComposeDemo $apps ($python + @('pendientes')) $Catalogo |
        Set-Content -LiteralPath $Seleccion -Encoding UTF8
    $turnos = Get-Content -LiteralPath $Seleccion -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($FechaCarga -and $turnos.fecha -ne $FechaCarga) {
        Write-Host 'Cambió la fecha de Bogotá durante la carga. Ejecuta pendientes en la nueva jornada.'
        return
    }
    if (@($turnos.agencias).Count -eq 0) {
        Write-Host 'Fuera de la jornada hábil de las agencias. Ejecuta pendientes durante la próxima jornada abierta.'
        return
    }
    Invoke-ComposeDemo $apps ($node + @('pendientes', '--lote', $Lote)) $Seleccion
}

if (-not (Test-Path -LiteralPath $envCompose -PathType Leaf)) {
    throw 'Configura infra/.env antes de ejecutar la demostración.'
}
if ($Accion -eq 'activar-usuario' -and (-not $Id -or -not $Correo)) {
    throw 'Usa activar-usuario -Id <id o correo ficticio> -Correo <correo de acceso>.'
}

$codificacion = [System.Text.UTF8Encoding]::new($false)
$anteriorSalida = [Console]::OutputEncoding
$anteriorEntrada = $OutputEncoding
$temporales = @()
$cerrojo = [System.Threading.Mutex]::new($false, 'Local\COOTEPTurnoDemo')
$adquirido = $false
try {
    try { $adquirido = $cerrojo.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $adquirido = $true }
    if (-not $adquirido) { throw 'Ya hay una operación de demostración en curso en este equipo.' }
    [Console]::OutputEncoding = $codificacion
    $OutputEncoding = $codificacion

    Invoke-ComposeDemo $datos @('exec', '-T', 'postgres', 'psql', '-v', 'ON_ERROR_STOP=1', '-U', 'cootep', '-d', 'cootep', '-f', '/docker-entrypoint-initdb.d/05-demo.sql')
    if ($Accion -eq 'activar-usuario') {
        Invoke-ComposeDemo $apps ($node + @('activar-usuario', '--id', $Id, '--correo', $Correo))
        return
    }

    $catalogo = (New-TemporaryFile).FullName
    $temporales += $catalogo
    $seleccion = (New-TemporaryFile).FullName
    $temporales += $seleccion
    Invoke-ComposeDemo $apps ($node + @('cuentas', '--semilla', "$Semilla")) |
        Set-Content -LiteralPath $catalogo -Encoding UTF8
    $resumen = Get-Content -LiteralPath $catalogo -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($agencia in $resumen.agencias) {
        Write-Host ("{0} · {1} administradores, {2} funcionarios y {3} asociados" -f $agencia.nombre, @($agencia.administradores).Count, @($agencia.funcionarios).Count, @($agencia.asociados).Count)
    }

    if ($Accion -eq 'pendientes') {
        Invoke-PendientesDemo $catalogo $seleccion
        return
    }

    Invoke-ComposeDemo $datos @('exec', '-T', 'mongo', 'mongosh', '--quiet', 'cootep', '--eval', "db.auth('cootep_app', process.env.MONGO_APP_PASSWORD)", '--file', '/docker-entrypoint-initdb.d/02-demanda.js')
    $hoy = Invoke-ComposeDemo $apps ($python + @('fecha'))
    Invoke-ComposeDemo $apps ($python + @('preparar'))
    $turnos = (New-TemporaryFile).FullName
    $temporales += $turnos
    Invoke-ComposeDemo $apps ($python + @('historial', '--hoy', $hoy, '--dias', "$Dias")) $catalogo |
        Set-Content -LiteralPath $turnos -Encoding UTF8
    Invoke-ComposeDemo $apps ($node + @('importar')) $turnos
    Invoke-ComposeDemo $apps ($python + @('marcar-historial', '--hoy', $hoy, '--dias', "$Dias")) $catalogo
    Invoke-PendientesDemo $catalogo $seleccion $hoy
    Invoke-ComposeDemo $apps ($python + @('publicar', '--hoy', $hoy, '--dias', "$Dias"))
} finally {
    [Console]::OutputEncoding = $anteriorSalida
    $OutputEncoding = $anteriorEntrada
    foreach ($archivo in $temporales) {
        Remove-Item -LiteralPath $archivo -ErrorAction SilentlyContinue
    }
    if ($adquirido) { $cerrojo.ReleaseMutex() }
    $cerrojo.Dispose()
}
