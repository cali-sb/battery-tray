# Genera el instalador en build\installer. Necesita el .venv e Inno Setup 6.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$python = '.venv\Scripts\python.exe'
$iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'No encuentro Inno Setup 6 (ISCC.exe).' }

& $python -m pip install -q -r requirements.txt pyinstaller
& $python installer\make_icon.py
& $python -m PyInstaller --noconfirm --clean --windowed --name Bateria `
    --icon "$PSScriptRoot\installer\icon.ico" `
    --add-data "$PSScriptRoot\protocols.json;." `
    --add-data "$PSScriptRoot\settings.qml;." `
    --hidden-import pystray._win32 `
    --hidden-import settings_app `
    --distpath build\dist --workpath build\work --specpath build `
    battery_tray.py
if ($LASTEXITCODE) { throw 'Falló PyInstaller.' }
& $iscc installer\battery-tray.iss
if ($LASTEXITCODE) { throw 'Falló Inno Setup.' }
Get-Item build\installer\*.exe | Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB) } }
