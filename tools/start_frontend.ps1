$ErrorActionPreference = 'Stop'
Push-Location "$PSScriptRoot/../frontend"
try {
    if (-not (Test-Path -LiteralPath '.env')) { Copy-Item -LiteralPath '.env.example' -Destination '.env' }
    if (-not (Test-Path -LiteralPath 'node_modules/@angular/cli/bin/ng.js')) {
        & npm.cmd ci --no-fund
        if ($LASTEXITCODE -ne 0) { throw 'No se pudieron instalar las dependencias de Angular.' }
    }
    & npm.cmd start
} finally { Pop-Location }
