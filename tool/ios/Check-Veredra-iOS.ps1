# Veredra iOS — diagnostico seguro (somente leitura).
$ErrorActionPreference = 'Stop'
$root = 'D:\Veredra_iOS'
$app = 'C:\Users\Usuario\Documents\Codex\Veredra\app'
if (-not (Test-Path $root)) { throw 'Conecte o HD externo D: antes de continuar.' }
if (-not (Test-Path (Join-Path $app 'pubspec.yaml'))) { throw 'Projeto Veredra nao encontrado no SSD.' }
$env:XCROSS_CONFIG = Join-Path $root 'xcross-config.yaml'
Set-Location $app
Write-Output '=== Veredra iOS / volumes ==='
Get-PSDrive -PSProvider FileSystem | Format-Table Name,Root,Free -AutoSize
Write-Output '=== xcross config ==='
xcross config show
Write-Output '=== xcross flutter doctor ==='
xcross flutter doctor
Write-Output 'A checagem acima pode acusar falta de SDK, autenticacao Apple e iPhone ate que sejam configurados.'
