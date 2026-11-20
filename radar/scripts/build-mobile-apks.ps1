[CmdletBinding()]
param(
    [ValidateSet('both', 'demo', 'usb', 'hosted')][string]$Mode = 'both',
    [switch]$SkipPubGet,
    [string]$SupabaseConfigPath,
    [string]$ApiUrl
)
$ErrorActionPreference = 'Stop'
if ($Mode -eq 'hosted') {
    $endpoint = $null
    if (-not [Uri]::TryCreate($ApiUrl, [UriKind]::Absolute, [ref]$endpoint) -or
        $endpoint.Scheme -ne 'https' -or $endpoint.IsLoopback -or
        $endpoint.UserInfo -or $endpoint.Query -or $endpoint.Fragment) {
        throw 'Informe -ApiUrl com a URL HTTPS pública do backend.'
    }
}
$appRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path (Split-Path -Parent $appRoot) 'artifacts/mobile'
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$supabaseArgs = @()
if ($SupabaseConfigPath) {
    $configFile = (Resolve-Path -LiteralPath $SupabaseConfigPath).Path
    $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
    foreach ($required in @('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY')) {
        if ([string]::IsNullOrWhiteSpace($config.$required)) { throw "Preencha $required no arquivo público de configuração." }
    }
    foreach ($property in $config.PSObject.Properties) {
        if ($property.Name -match 'PASSWORD|SERVICE_ROLE|DB_URL|DB_USER|SECRET' -and $property.Value) {
            throw 'O arquivo do aplicativo deve conter somente configurações públicas, nunca credenciais do backend.'
        }
    }
    $publicKey = [string]$config.SUPABASE_PUBLISHABLE_KEY
    if ($publicKey.StartsWith('sb_secret_')) { throw 'Use a chave publicável, não a chave secreta do Supabase.' }
    $keyParts = $publicKey.Split('.')
    if ($keyParts.Count -eq 3) {
        $payload = $keyParts[1].Replace('-', '+').Replace('_', '/')
        $payload = $payload.PadRight($payload.Length + ((4 - $payload.Length % 4) % 4), '=')
        $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
        if ($claims.role -eq 'service_role') { throw 'Use a chave anon/publicável, nunca service_role no app.' }
    }
    $supabaseArgs = @("--dart-define-from-file=$configFile")
}
Push-Location $appRoot
try {
    if (-not $SkipPubGet) {
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao obter dependências.' }
    }
    $modes = if ($Mode -eq 'both') { @('demo', 'usb') } else { @($Mode) }
    foreach ($variant in $modes) {
        $buildApiUrl = switch ($variant) {
            'hosted' { $endpoint.AbsoluteUri.TrimEnd('/') }
            'usb' { 'http://127.0.0.1:8080' }
            default { '' }
        }
        & flutter build apk --release --no-pub @supabaseArgs "--dart-define=RADAR_API_URL=$buildApiUrl"
        if ($LASTEXITCODE -ne 0) { throw "Falha ao gerar APK $variant." }
        $fileName = if ($variant -eq 'hosted') {
            "news.dev-$($endpoint.IdnHost).apk"
        } else { "nexora-tech-$variant.apk" }
        $destination = Join-Path $outputRoot $fileName
        Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' -Destination $destination -Force
        $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        [IO.File]::WriteAllText("$destination.sha256", "$hash  $fileName`n")
        if ($variant -eq 'hosted') {
            Write-Output "APK gerado: $destination"
            continue
        }
        # Caminhos anteriores continuam disponíveis para comandos já enviados ao usuário.
        $legacy = Join-Path $outputRoot "radar-$variant.apk"
        Copy-Item -LiteralPath $destination -Destination $legacy -Force
        [IO.File]::WriteAllText("$legacy.sha256", "$hash  radar-$variant.apk`n")
        $previousBrand = Join-Path $outputRoot "fionova-$variant.apk"
        Copy-Item -LiteralPath $destination -Destination $previousBrand -Force
        [IO.File]::WriteAllText("$previousBrand.sha256", "$hash  fionova-$variant.apk`n")
        Write-Output "APK gerado: $destination"
    }
} finally { Pop-Location }
