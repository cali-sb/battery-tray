; Lo compila build.ps1, que antes genera build\dist\Litio con PyInstaller y pasa la
; versión de version.py: ISCC /DAppVersion=X.Y.Z
#ifndef AppVersion
  #error Compila con build.ps1 (o pasa /DAppVersion=X.Y.Z a ISCC)
#endif
#define AppName "Litio"
#define Exe "Litio.exe"
; Hasta la 2.1.0 se llamaba «Batería»: se instalaba en Programs\Bateria con Bateria.exe.
#define OldDir "{localappdata}\Programs\Bateria"
; Los mismos nombres que config.py. No cambian con el nombre: la versión vieja los usa.
#define Mutexes "BatteryTrayMutex,BatteryTraySettingsMutex"
#define PluginDir "{userappdata}\Elgato\StreamDeck\Plugins\com.cali.battery.sdPlugin"

[Setup]
; El AppId no cambia nunca: es lo que hace que una versión se instale encima de la anterior.
AppId={{6F1B7C52-3D0A-4E5B-9A44-2B7E7C1D9A10}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=cali
DefaultDirName={localappdata}\Programs\Litio
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Sin esto, al actualizar se quedaría en la carpeta y el grupo del menú de «Batería».
UsePreviousAppDir=no
UsePreviousGroup=no
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
AppMutex={#Mutexes}
AppPublisherURL=https://github.com/cali-sb/litio
AppUpdatesURL=https://github.com/cali-sb/litio/releases
VersionInfoVersion={#AppVersion}
OutputDir=..\build\installer
OutputBaseFilename=Litio-{#AppVersion}-setup
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
Source: "..\build\dist\Litio\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "..\streamdeck\com.cali.battery.sdPlugin\*"; DestDir: "{#PluginDir}"; Flags: recursesubdirs ignoreversion; Tasks: streamdeck

[InstallDelete]
; Las librerías de la versión anterior se sustituyen enteras, sin dejar restos.
Type: filesandordirs; Name: "{app}\_internal"
; Restos de cuando se llamaba «Batería». Su desinstalador sobra: el de Litio lo sustituye.
Type: filesandordirs; Name: "{#OldDir}"; Check: OldDirIsNotApp
Type: filesandordirs; Name: "{userprograms}\Batería"

[Icons]
; Sin «:» en el nombre: Windows lo tomaría por un flujo de datos y el acceso no funcionaría.
Name: "{group}\Ajustes de {#AppName}"; Filename: "{app}\{#Exe}"; Parameters: "--settings"
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

function OldDirIsNotApp: Boolean;
begin
  Result := CompareText(ExpandConstant('{#OldDir}'), ExpandConstant('{app}')) <> 0;
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
