[CmdletBinding()]
param(
    [string]$SqlPath,
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $backendRoot
if (-not $SqlPath) { $SqlPath = Join-Path $projectRoot 'artifacts/migration/firestore-to-supabase.sql' }
$SqlPath = (Resolve-Path -LiteralPath $SqlPath).Path
$config = @{}
foreach ($line in Get-Content -LiteralPath (Join-Path $backendRoot '.env')) {
    if ($line.Trim() -notmatch '^[A-Z][A-Z0-9_]*=') { continue }
    $parts = $line.Trim().Split('=', 2)
    $entryValue = $parts[1].Trim()
    if ($entryValue.Length -ge 2 -and (
        ($entryValue.StartsWith('"') -and $entryValue.EndsWith('"')) -or
        ($entryValue.StartsWith("'") -and $entryValue.EndsWith("'")))) {
        $entryValue = $entryValue.Substring(1, $entryValue.Length - 2)
    }
    $config[$parts[0]] = $entryValue
}
if (-not $config.SUPABASE_DB_URL -or -not $config.SUPABASE_DB_USER -or -not $config.SUPABASE_DB_PASSWORD) {
    throw 'Preencha SUPABASE_DB_URL, SUPABASE_DB_USER e SUPABASE_DB_PASSWORD no backend/.env.'
}
if ($config.SUPABASE_DB_URL -notmatch '^jdbc:postgresql://') { throw 'Informe uma URL JDBC PostgreSQL.' }
$databaseUri = [Uri]$config.SUPABASE_DB_URL.Substring(5)
$databaseName = $databaseUri.AbsolutePath.TrimStart('/')
if (-not $databaseName -or -not $databaseUri.Host) { throw 'URL de banco inválida.' }
Write-Output "Destino: $($databaseUri.Host) / $databaseName"
Write-Output "Arquivo privado: $SqlPath"
if (-not $Apply) {
    Write-Output 'Prévia concluída. Use -Apply para importar após criar o schema. IDs existentes causam rollback; nada é sobrescrito.'
    return
}
$psqlCommand = Get-Command psql -ErrorAction SilentlyContinue
$psql = if ($psqlCommand) { $psqlCommand.Source } else {
    Get-ChildItem -Path 'C:/Program Files/PostgreSQL/*/bin/psql.exe' -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $psql) { throw 'Instale o cliente PostgreSQL (psql) para executar a importação.' }
$oldPassword = $env:PGPASSWORD
$oldSslMode = $env:PGSSLMODE
try {
    $env:PGPASSWORD = $config.SUPABASE_DB_PASSWORD
    $env:PGSSLMODE = if ($databaseUri.Host -in @('localhost', '127.0.0.1')) { 'disable' } else { 'require' }
    $databasePort = if ($databaseUri.Port -gt 0) { $databaseUri.Port } else { 5432 }
    & $psql --host $databaseUri.Host --port $databasePort --username $config.SUPABASE_DB_USER --dbname $databaseName --no-password --set ON_ERROR_STOP=1 --file $SqlPath
    if ($LASTEXITCODE -ne 0) { throw 'Importação falhou. A transação foi revertida; confira o erro PostgreSQL acima.' }
    Write-Output 'Dados importados. Faça login novamente no app; sessões e acessos sociais antigos não são importados.'
} finally {
    $env:PGPASSWORD = $oldPassword
    $env:PGSSLMODE = $oldSslMode
}
