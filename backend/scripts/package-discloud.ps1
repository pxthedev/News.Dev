[CmdletBinding()]
param(
    [ValidatePattern('^[a-z0-9]([a-z0-9-]*[a-z0-9])?$')]
    [string]$Subdomain = 'appnewsai',
    [switch]$IncludeLocalEnv
)

$ErrorActionPreference = 'Stop'
$backend = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $backend '.env'
if ($IncludeLocalEnv -and -not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
    throw 'backend/.env não encontrado.'
}

Push-Location $backend
try {
    & mvn -q -DskipTests '-Dbackend.jar.name=radar-api-discloud' package
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o backend.' }
} finally { Pop-Location }

$jarPath = Join-Path $backend 'target/radar-api-discloud.jar'
$outputDir = Join-Path (Split-Path -Parent $backend) 'artifacts/discloud'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$zipName = if ($IncludeLocalEnv) { 'news.dev-discloud-privado.zip' } else { 'news.dev-discloud.zip' }
$outputPath = Join-Path $outputDir $zipName
$config = (Get-Content -Raw -LiteralPath (Join-Path $backend 'discloud.config')) -replace '(?m)^ID=[^\r\n]*', "ID=$Subdomain"

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($outputPath, [IO.Compression.ZipArchiveMode]::Update)
try {
    foreach ($entry in @($archive.Entries)) { $entry.Delete() }
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $jarPath, 'app.jar') | Out-Null
    $writer = [IO.StreamWriter]::new($archive.CreateEntry('discloud.config').Open())
    try { $writer.Write($config) } finally { $writer.Dispose() }
    if ($IncludeLocalEnv) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $envFile, '.env') | Out-Null
    }
} finally { $archive.Dispose() }
Write-Output "Pacote gerado: $outputPath"
