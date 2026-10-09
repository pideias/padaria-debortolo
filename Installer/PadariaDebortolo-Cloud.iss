#define MyAppName "Padaria Debortolo"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Padaria Debortolo"
#define MyAppExeName "infinite_coffee_app.exe"

; Variante cloud: o app desktop usa a API do servidor remoto e banco local
; embutido para operar offline. Nao instala SQL Server nem backend local.

[Setup]
AppId={{5B6E9E15-2E24-4F1F-8F61-3F75B07D6C21}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Padaria Debortolo
DefaultGroupName={#MyAppName}
OutputDir=..\artifacts\installer
OutputBaseFilename=PadariaDebortolo-Desktop-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "..\artifacts\desktop-cloud\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "LEIA-ME-DESKTOP.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Iniciar o sistema agora"; Flags: postinstall nowait skipifsilent
