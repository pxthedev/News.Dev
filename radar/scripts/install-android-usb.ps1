[CmdletBinding()]
param(
    [ValidateSet('demo', 'usb')][string]$Mode = 'usb',
    [string]$Serial
)
$ErrorActionPreference = 'Stop'
$appRoot = Split-Path -Parent $PSScriptRoot
$apk = Join-Path (Split-Path -Parent $appRoot) "artifacts/mobile/nexora-tech-$Mode.apk"
if (-not (Test-Path -LiteralPath $apk)) { throw "APK não encontrado: $apk" }
$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
$adb = if ($adbCommand) { $adbCommand.Source } else { Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe' }
if (-not (Test-Path -LiteralPath $adb)) { throw 'Instale o Android SDK Platform Tools para usar adb.' }

if (-not $Serial) {
    $devices = @(& $adb devices | ForEach-Object {
        if ($_ -match '^(\S+)\s+device$') { $Matches[1] }
    })
    if ($devices.Count -ne 1) {
        throw 'Conecte um Android por USB, ative a Depuração USB e aceite a autorização no aparelho. Para vários dispositivos, informe -Serial.'
    }
    $Serial = $devices[0]
}
if ($Mode -eq 'usb') {
    & $adb -s $Serial reverse tcp:8080 tcp:8080
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível criar o túnel USB para o backend.' }
}
& $adb -s $Serial install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível instalar o APK.' }
Write-Output 'APK instalado.'
if ($Mode -eq 'usb') {
    Write-Output 'Inicie backend/scripts/start-local.ps1 -UseJar na porta 8080 para carregar dados reais.'
}
