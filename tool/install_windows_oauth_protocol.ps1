# Veredra: register the per-user custom URI scheme for Supabase OAuth PKCE.
# Requires no administrator privileges; does not alter HKLM.
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string] $AppPath)

$ErrorActionPreference = 'Stop'
$resolved = [System.IO.Path]::GetFullPath($AppPath)
if (-not [System.IO.File]::Exists($resolved) -or
    [System.IO.Path]::GetFileName($resolved) -ine 'veredra.exe') {
    throw 'AppPath deve apontar para um veredra.exe existente.'
}

$schemeKey = 'HKCU:\Software\Classes\veredra'
$commandKey = "$schemeKey\shell\open\command"
$old = if (Test-Path $commandKey) { (Get-Item $commandKey).GetValue('') } else { $null }
if (-not [string]::IsNullOrWhiteSpace($old) -and
    $old -notmatch '(?i)\\veredra\.exe"') {
    throw 'Outro aplicativo ja controla o esquema veredra. Nenhum registro foi alterado.'
}

$command = '"' + $resolved + '" "%1"'
$null = New-Item -Path $schemeKey -Force
Set-Item -Path $schemeKey -Value 'URL:Veredra OAuth Callback'
New-ItemProperty -Path $schemeKey -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
$null = New-Item -Path $commandKey -Force
Set-Item -Path $commandKey -Value $command

$checked = (Get-Item $commandKey).GetValue('')
if ($checked -ne $command) { throw 'O registro do protocolo nao corresponde ao executavel selecionado.' }
Write-Output 'VEREDRA_OAUTH_SCHEME_CONFIGURED=true'
Write-Output ('TARGET=' + $resolved)
Write-Output 'SCOPE=CurrentUser'
