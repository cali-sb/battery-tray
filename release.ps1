# Publica la versión de version.py: compila, etiqueta y sube el instalador como release de GitHub.
# Los programas instalados la encuentran solos (updater.py) y se actualizan.
#   .\release.ps1 -Notes "Qué cambia, en una o dos frases."
param([Parameter(Mandatory)][string]$Notes)
# Sin $ErrorActionPreference = 'Stop': git escribe su progreso por stderr. Se mira $LASTEXITCODE.
Set-Location $PSScriptRoot

$version = (Select-String -Path version.py -Pattern '__version__ = "(\d+\.\d+\.\d+)"').Matches[0].Groups[1].Value
if ((git branch --show-current) -ne 'main') { throw 'Publica desde main.' }
if (git status --porcelain) { throw 'Hay cambios sin commit: la release debe salir de un commit.' }
if (git tag -l $version) { throw "La $version ya existe: sube la versión en version.py." }

& .\build.ps1
$setup = "build\installer\Litio-$version-setup.exe"
if (-not (Test-Path $setup)) { throw "No se generó $setup." }

git push origin main
if ($LASTEXITCODE) { throw 'Falló el push de main.' }
git tag -a $version -m "Litio $version"
if ($LASTEXITCODE) { throw 'Falló git tag.' }
git push origin $version
if ($LASTEXITCODE) { throw 'Falló el push de la etiqueta.' }
gh release create $version $setup --verify-tag --title "Litio $version" --notes $Notes
if ($LASTEXITCODE) { throw 'Falló gh release create.' }
