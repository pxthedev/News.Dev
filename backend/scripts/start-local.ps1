[CmdletBinding()]
param(
    [switch]$UseJar,
    [ValidateRange(1, 65535)][int]$Port = 8080
)

$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $backendRoot '.env'
if (-not (Test-Path -LiteralPath $envPath)) {
    throw 'Crie backend/.env a partir de .env.example antes de iniciar.'
}

# Ler valores como dados: não executar nem imprimir o conteúdo do .env.
foreach ($line in Get-Content -LiteralPath $envPath) {
    $entry = $line.Trim()
    if (-not $entry -or $entry.StartsWith('#')) { continue }
    $parts = $entry.Split('=', 2)
    if ($parts.Count -ne 2 -or $parts[0] -notmatch '^[A-Z][A-Z0-9_]*$') {
        throw 'Há uma entrada inválida no .env.'
    }
    $value = $parts[1].Trim()
    if ($value.Length -ge 2 -and (
        ($value.StartsWith('"') -and $value.EndsWith('"')) -or
        ($value.StartsWith("'") -and $value.EndsWith("'")))) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    [Environment]::SetEnvironmentVariable($parts[0], $value, 'Process')
}

if (-not $env:SUPABASE_DB_URL -or -not $env:SUPABASE_DB_USER -or -not $env:JWT_SECRET) {
    throw 'Configure SUPABASE_DB_URL, SUPABASE_DB_USER, SUPABASE_DB_PASSWORD e JWT_SECRET no backend/.env. Veja docs/SUPABASE.md.'
}
if ($env:SUPABASE_DB_URL -notmatch '^jdbc:postgresql://') {
    throw 'SUPABASE_DB_URL deve ser uma URL JDBC PostgreSQL, conforme .env.example.'
}
# Verificar o pacote antes de chamar java: um JAR intermediário não é executável.
function Test-ExecutableJar([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $archive = $null
    $reader = $null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($Path)
        $manifest = $archive.GetEntry('META-INF/MANIFEST.MF')
        if (-not $manifest) { return $false }
        $reader = [IO.StreamReader]::new($manifest.Open())
        $content = $reader.ReadToEnd()
        return ($content -match '(?m)^Main-Class: org\.springframework\.boot\.loader\.launch\.JarLauncher\s*$' -and
            $content -match '(?m)^Start-Class: br\.com\.radar\.' -and
            @($archive.Entries | Where-Object { $_.FullName.StartsWith('BOOT-INF/lib/') }).Count -gt 0)
    } catch { return $false }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($archive) { $archive.Dispose() }
    }
}
$listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
if ($listener) {
    throw "A porta $Port já está em uso. Encerre o servidor anterior ou execute com -Port outra_porta."
}
$env:PORT = "$Port"
Push-Location $backendRoot
try {
    if ($UseJar) {
        $jarPath = Join-Path $backendRoot 'target/radar-api-1.1.1.jar'
        if (-not (Test-ExecutableJar $jarPath)) {
            Write-Host 'JAR ausente ou não executável. Reconstruindo o pacote Spring Boot…'
            & mvn -DskipTests package
            if ($LASTEXITCODE -ne 0 -or -not (Test-ExecutableJar $jarPath)) {
                throw 'Não foi possível gerar o JAR executável. Confira o erro Maven acima; se houver arquivo em uso, encerre o backend anterior antes de reconstruir.'
            }
        }
        & java -jar $jarPath
    } else {
        & mvn spring-boot:run
    }
    if ($LASTEXITCODE -ne 0) { throw "O backend encerrou com código $LASTEXITCODE. A causa está na saída do Java/Maven acima desta mensagem." }
} finally {
    Pop-Location
}
