; Lo compila build.ps1, que antes genera build\dist\Bateria con PyInstaller y pasa la
; versión de version.py: ISCC /DAppVersion=X.Y.Z
#ifndef AppVersion
  #error Compila con build.ps1 (o pasa /DAppVersion=X.Y.Z a ISCC)
#endif
#define AppName "Batería"
#define Exe "Bateria.exe"
; Los mismos nombres que config.py.
#define Mutexes "BatteryTrayMutex,BatteryTraySettingsMutex"
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
AppMutex={#Mutexes}
AppPublisherURL=https://github.com/cali-sb/battery-tray
AppUpdatesURL=https://github.com/cali-sb/battery-tray/releases
VersionInfoVersion={#AppVersion}
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

[InstallDelete]
; Las librerías de la versión anterior se sustituyen enteras, sin dejar restos.
Type: filesandordirs; Name: "{app}\_internal"

[Icons]
Name: "{group}\{#AppName}: ajustes"; Filename: "{app}\{#Exe}"; Parameters: "--settings"
Name: "{group}\{#AppName}"; Filename: "{app}\{#Exe}"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "BatteryTray"; ValueData: """{app}\{#Exe}"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#Exe}"; Description: "Abrir {#AppName}"; Flags: nowait postinstall skipifsilent
; Actualización lanzada por el propio programa (/VERYSILENT /update=1): lo vuelve a abrir.
; A través del Explorador para que arranque con un entorno limpio, sin variables del viejo.
Filename: "{win}\explorer.exe"; Parameters: """{app}\{#Exe}"""; Flags: nowait; Check: IsUpdate

[Code]
function StreamDeckInstalled: Boolean;
begin
  Result := DirExists(ExpandConstant('{userappdata}\Elgato\StreamDeck'));
end;

function IsUpdate: Boolean;
begin
  Result := ExpandConstant('{param:update|0}') = '1';
end;

function InitializeSetup: Boolean;
var
  Tries: Integer;
begin
  // Al actualizar, el programa se cierra justo después de lanzar este instalador. Se le
  // espera, porque AppMutex, que se comprueba después, abortaría en modo silencioso.
  if IsUpdate then
    for Tries := 1 to 60 do
    begin
      if not CheckForMutexes('{#Mutexes}') then
        Break;
      Sleep(250);
    end;
  Result := True;
end;
