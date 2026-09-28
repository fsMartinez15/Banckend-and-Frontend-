param(
    [string]$ConfigPath = "$PSScriptRoot/../config/supabase.json",
    [string]$EnvPath = "$PSScriptRoot/../backend/.env"
)
$ErrorActionPreference = 'Stop'
# Un entorno ya definido tiene precedencia sobre el archivo local.
if (Test-Path -LiteralPath $EnvPath) {
    foreach ($line in Get-Content -LiteralPath $EnvPath) {
        if ($line -match '^\s*([A-Z][A-Z0-9_]*)\s*=(.*)$') {
            $settingName = $Matches[1]
            $settingValue = $Matches[2].Trim().Trim('"').Trim("'")
            if (-not [Environment]::GetEnvironmentVariable($settingName, 'Process')) {
                [Environment]::SetEnvironmentVariable($settingName, $settingValue, 'Process')
            }
        }
    }
}
if ((-not $env:SUPABASE_URL -or -not $env:SUPABASE_ANON_KEY) -and (Test-Path -LiteralPath $ConfigPath)) {
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    if (-not $env:SUPABASE_URL) { $env:SUPABASE_URL = $config.SUPABASE_URL }
    if (-not $env:SUPABASE_ANON_KEY) { $env:SUPABASE_ANON_KEY = $config.SUPABASE_ANON_KEY }
}
if (-not $env:SUPABASE_URL -or -not $env:SUPABASE_ANON_KEY) { throw 'Configura SUPABASE_URL y SUPABASE_ANON_KEY en backend/.env o en el entorno.' }
$javaCommand = Get-Command java -ErrorAction SilentlyContinue
$studioJava = 'C:\Program Files\Android\Android Studio\jbr\bin\java.exe'
$javaCandidates = @()
if ($env:JAVA_HOME) { $javaCandidates += "$env:JAVA_HOME/bin/java.exe" }
$javaCandidates += $studioJava
if ($javaCommand) { $javaCandidates += $javaCommand.Source }
$javaBinary = $null
foreach ($candidate in $javaCandidates) {
    if (Test-Path -LiteralPath $candidate) {
        $versionText = (& $candidate -version 2>&1 | Out-String)
        if ($versionText -match 'version "(\d+)' -and [int]$Matches[1] -ge 21) { $javaBinary = $candidate; break }
    }
}
if (-not $javaBinary) { throw 'Instala Java 21 o superior y configura JAVA_HOME para iniciar el backend.' }
& $javaBinary -jar "$PSScriptRoot/../backend/target/ridemove-api-2.0.0.jar"
if ($LASTEXITCODE -ne 0) { throw 'El backend terminó con un error. Revisa el mensaje anterior.' }
