#define MyAppName "Infinite Coffee"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Infinite Coffee"
#define MyAppExeName "infinite_coffee_app.exe"

[Setup]
AppId={{B7BD4DDC-6B04-4F3A-9C2D-8C8E6A5E4A10}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Infinite Coffee
DefaultGroupName={#MyAppName}
OutputDir=..\artifacts\installer
OutputBaseFilename=InfiniteCoffee-Setup
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
Source: "Start-InfiniteCoffeeDesktop.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "Start-InfiniteCoffeeDesktop.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\Start-InfiniteCoffeeDesktop.cmd"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\Start-InfiniteCoffeeDesktop.cmd"; WorkingDir: "{app}"

[Run]
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""Infinite Coffee API"" dir=in action=allow protocol=TCP localport=5049 profile=private"; StatusMsg: "Liberando a API na rede privada..."; Flags: runhidden waituntilterminated
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Setup-Database.ps1"" -InstallDir ""{app}"""; Description: "Configurar banco de dados automaticamente"; Flags: waituntilterminated skipifsilent
Filename: "{app}\Start-InfiniteCoffeeDesktop.cmd"; Description: "Iniciar o sistema agora"; Flags: postinstall nowait skipifsilent

[UninstallRun]
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""Infinite Coffee API"""; Flags: runhidden
