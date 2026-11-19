# Veredra iOS — conecta iPhone e executa build de debug.
$ErrorActionPreference = 'Stop'
$root = 'D:\Veredra_iOS'
$app = 'C:\Users\Usuario\Documents\Codex\Veredra\app'
if (-not (Test-Path (Join-Path $root 'xcross-config.yaml'))) { throw 'Conecte o HD D: com a configuracao xcross.' }
$env:XCROSS_CONFIG = Join-Path $root 'xcross-config.yaml'
Set-Location $app
Write-Output 'Pre-requisitos: iPhone iOS 17+, cabo, Confiar neste computador, modo desenvolvedor e xcross auth na sessao do usuario.'
Write-Output 'Execute em PowerShell COMO ADMINISTRADOR: xcross tunnel (em terminal separado; mantenha aberto).'
xcross flutter doctor
if ($LASTEXITCODE -ne 0) { throw 'Corrija o doctor: SDK, autenticacao Apple ou iPhone ausentes.' }
xcross flutter run
