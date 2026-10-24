# Veredra iOS — SDK no HD. Executar apos baixar Xcode.xip pela Apple.
param([string]$XcodeXip = 'D:\Veredra_iOS\Xcode\Xcode_27.1.xip')
$ErrorActionPreference = 'Stop'
$root = 'D:\Veredra_iOS'
if (-not (Test-Path $root)) { throw 'Conecte o HD externo (D:) primeiro.' }
if (-not (Test-Path $XcodeXip)) { throw "Arquivo Xcode.xip ausente: $XcodeXip. Baixe da Apple com sua propria conta developer." }
$archive = Get-Item $XcodeXip
if ($archive.Length -lt 1GB) { throw 'Arquivo .xip muito pequeno; possivelmente incompleto ou pagina HTML de login.' }
$env:XCROSS_CONFIG = Join-Path $root 'xcross-config.yaml'
Write-Output "Extraindo SDK oficial de $XcodeXip no HD externo..."
xcross sdk install $XcodeXip
if ($LASTEXITCODE -ne 0) { throw 'xcross sdk install falhou; nenhum build deve ser declarado pronto.' }
Set-Location 'C:\Users\Usuario\Documents\Codex\Veredra\app'
xcross flutter doctor
