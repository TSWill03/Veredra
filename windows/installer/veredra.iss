; Signature: dev.tswicolly03
; Per-user upgrade-in-place: application data live outside {app}.
#ifndef AppVersion
  #define AppVersion "0.1.4"
#endif
#ifndef BuildNumber
  #define BuildNumber "5"
#endif

[Setup]
AppId={{B7DB0FB0-24F1-4336-A23F-FC9E59CF14D5}
AppName=Veredra
AppVersion={#AppVersion}.{#BuildNumber}
AppVerName=Veredra {#AppVersion}+{#BuildNumber}
AppPublisher=Wicolly
AppPublisherURL=https://wicolly.com.br/veredra/
AppSupportURL=https://github.com/TSWill03/Veredra/issues
DefaultDirName={localappdata}\Programs\Veredra
DefaultGroupName=Veredra
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
DisableProgramGroupPage=yes
DisableDirPage=yes
UsePreviousAppDir=yes
UninstallDisplayIcon={app}\txt_webnovel_reader.exe
OutputDir=..\..\build\installer
OutputBaseFilename=Veredra-Setup-v{#AppVersion}+{#BuildNumber}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
SetupLogging=yes

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Veredra"; Filename: "{app}\txt_webnovel_reader.exe"
Name: "{autodesktop}\Veredra"; Filename: "{app}\txt_webnovel_reader.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na area de trabalho"; Flags: unchecked

[Run]
Filename: "{app}\txt_webnovel_reader.exe"; Description: "Abrir Veredra"; Flags: nowait postinstall skipifsilent
Filename: "{app}\txt_webnovel_reader.exe"; Flags: nowait skipifnotsilent
