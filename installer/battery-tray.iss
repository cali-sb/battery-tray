; Lo compila build.ps1, que antes genera build\dist\Bateria con PyInstaller.
#define AppName "Batería"
#define AppVersion "2.0.0"
#define Exe "Bateria.exe"
#define PluginDir "{userappdata}\Elgato\StreamDeck\Plugins\com.cali.battery.sdPlugin"

[Setup]
AppId={{6F1B7C52-3D0A-4E5B-9A44-2B7E7C1D9A10}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=cali
DefaultDirName={localappdata}\Programs\Bateria
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
AppMutex=BatteryTrayMutex,BatteryTraySettingsMutex
OutputDir=..\build\installer
OutputBaseFilename=Bateria-{#AppVersion}-setup
SetupIconFile=icon.ico
UninstallDisplayIcon={app}\{#Exe}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "autostart"; Description: "Arrancar al iniciar sesión"
Name: "streamdeck"; Description: "Instalar el plugin del Stream Deck"; Check: StreamDeckInstalled

[Files]
Source: "..\build\dist\Bateria\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "..\streamdeck\com.cali.battery.sdPlugin\*"; DestDir: "{#PluginDir}"; Flags: recursesubdirs ignoreversion; Tasks: streamdeck

[Icons]
Name: "{group}\{#AppName}: ajustes"; Filename: "{app}\{#Exe}"; Parameters: "--settings"
Name: "{group}\{#AppName}"; Filename: "{app}\{#Exe}"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "BatteryTray"; ValueData: """{app}\{#Exe}"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#Exe}"; Description: "Abrir {#AppName}"; Flags: nowait postinstall skipifsilent

[Code]
function StreamDeckInstalled: Boolean;
begin
  Result := DirExists(ExpandConstant('{userappdata}\Elgato\StreamDeck'));
end;
