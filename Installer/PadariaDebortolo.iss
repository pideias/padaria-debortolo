#define MyAppName "Padaria Debortolo"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Padaria Debortolo"
#define MyAppExeName "infinite_coffee_app.exe"

[Setup]
AppId={{B7BD4DDC-6B04-4F3A-9C2D-8C8E6A5E4A10}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Padaria Debortolo
DefaultGroupName={#MyAppName}
OutputDir=..\artifacts\installer
OutputBaseFilename=PadariaDebortolo-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
UninstallDisplayIcon={app}\desktop\{#MyAppExeName}

[Files]
Source: "..\artifacts\server\*"; DestDir: "{app}\server"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\artifacts\desktop\*"; DestDir: "{app}\desktop"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\DatabaseScripts\*"; DestDir: "{app}\database"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "Setup-Database.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Start-PadariaDesktop.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "Start-PadariaDesktop.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\Start-PadariaDesktop.cmd"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\Start-PadariaDesktop.cmd"; WorkingDir: "{app}"

[Run]
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""Padaria Debortolo API"" dir=in action=allow protocol=TCP localport=5049 profile=private"; StatusMsg: "Liberando a API na rede privada..."; Flags: runhidden waituntilterminated
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Setup-Database.ps1"" -InstallDir ""{app}"""; Description: "Configurar banco de dados automaticamente"; Flags: waituntilterminated skipifsilent
Filename: "{app}\Start-PadariaDesktop.cmd"; Description: "Iniciar o sistema agora"; Flags: postinstall nowait skipifsilent

[UninstallRun]
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""Padaria Debortolo API"""; Flags: runhidden
