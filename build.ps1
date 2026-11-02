# Genera el instalador en build\installer con la versión de version.py. Necesita el .venv e Inno Setup 6.
# Sin $ErrorActionPreference = 'Stop': en Windows PowerShell 5.1 convierte en error lo que pip y
# PyInstaller escriben por stderr, aunque sean avisos. Los fallos se miran con $LASTEXITCODE.
Set-Location $PSScriptRoot

$python = '.venv\Scripts\python.exe'
$iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'No encuentro Inno Setup 6 (ISCC.exe).' }

$match = Select-String -Path version.py -Pattern '__version__ = "(\d+\.\d+\.\d+)"'
if (-not $match) { throw 'No encuentro __version__ en version.py.' }
$version = $match.Matches[0].Groups[1].Value
Write-Host "Versión $version"

& $python -m pip install -q -r requirements.txt pyinstaller
if ($LASTEXITCODE) { throw 'Falló pip.' }
& $python installer\make_icon.py
if ($LASTEXITCODE) { throw 'Falló make_icon.py.' }
& $python -m PyInstaller --noconfirm --clean --windowed --name Litio `
    --icon "$PSScriptRoot\installer\icon.ico" `
    --add-data "$PSScriptRoot\protocols.json;." `
    --add-data "$PSScriptRoot\settings.qml;." `
    --hidden-import pystray._win32 `
    --hidden-import settings_app `
    --distpath build\dist --workpath build\work --specpath build `
    battery_tray.py
if ($LASTEXITCODE) { throw 'Falló PyInstaller.' }
& $iscc "/DAppVersion=$version" installer\battery-tray.iss
if ($LASTEXITCODE) { throw 'Falló Inno Setup.' }

$setup = Get-Item "build\installer\Litio-$version-setup.exe"
Write-Host "Instalador: $($setup.FullName) ($([math]::Round($setup.Length / 1MB)) MB)"
Write-Host "SHA-256:    $((Get-FileHash $setup -Algorithm SHA256).Hash.ToLower())"
