# Instala SDK iOS oficial no HD externo sem exigir Mac.
param([string]$XcodeXip = '')
$ErrorActionPreference = 'Stop'
$root = 'D:\Veredra_iOS'
$app = 'C:\Users\Usuario\Documents\Codex\Veredra\app'
if (-not (Test-Path $root)) { throw 'HD externo nao encontrado em D:. Conecte-o primeiro.' }
if (-not (Test-Path (Join-Path $app 'pubspec.yaml'))) { throw 'Projeto Veredra nao encontrado no SSD.' }
if ([string]::IsNullOrWhiteSpace($XcodeXip)) {
  $locations = @((Join-Path $root 'Xcode'), (Join-Path $env:USERPROFILE 'Downloads'))
  $files = foreach ($loc in $locations) {
    if (Test-Path $loc) {
      Get-ChildItem $loc -File -Filter '*.xip' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^Xcode' -and $_.Name -notmatch 'beta|rc|preview' }
    }
  }
  $archive = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($null -eq $archive) {
    throw 'Xcode.xip NAO encontrado. Baixe o Xcode ESTAVEL no site developer.apple.com/download/all/ e SALVE DIRETAMENTE em D:\Veredra_iOS\Xcode\.'
  }
  $XcodeXip = $archive.FullName
}
$archive = Get-Item -LiteralPath $XcodeXip -ErrorAction Stop
if ($archive.Length -lt 1GB) { throw 'Xcode.xip muito pequeno: download incompleto ou pagina HTML.' }
$stream = [IO.File]::OpenRead($archive.FullName)
try {
  $magic = New-Object byte[] 4
  if ($stream.Read($magic, 0, 4) -ne 4 -or [Text.Encoding]::ASCII.GetString($magic) -ne 'xar!') {
    throw 'Arquivo nao tem assinatura de formato XIP/XAR esperada; nao executar.'
  }
} finally { $stream.Dispose() }
$temp = Join-Path $root 'Cache\Temp'
New-Item -ItemType Directory -Path $temp -Force | Out-Null
$env:TEMP = $temp
$env:TMP = $temp
$env:XCROSS_CONFIG = Join-Path $root 'xcross-config.yaml'
Write-Host ('Instalando SDK a partir de: ' + $archive.FullName)
Write-Host ('Cache temporario no HD: ' + $temp)
xcross sdk install $archive.FullName
if ($LASTEXITCODE -ne 0) { throw ('Falha na extracao do SDK; codigo ' + $LASTEXITCODE) }
Write-Host 'SDK instalado no HD. Checando toolchain...'
Set-Location $app
xcross flutter doctor
Write-Host 'Se faltarem somente Apple Auth e iPhone, continue com a autenticacao presencial e conecte seu aparelho.'