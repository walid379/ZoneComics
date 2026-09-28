$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Test-Path 'android\app\src\main\AndroidManifest.xml')) {
    throw 'Le dossier Android est absent. Lance d’abord setup_android.ps1.'
}

$manifest = Join-Path $PSScriptRoot 'android\app\src\main\AndroidManifest.xml'
[xml]$xml = Get-Content $manifest -Raw
$androidNs = 'http://schemas.android.com/apk/res/android'
$xml.manifest.application.SetAttribute('label', $androidNs, 'Zone Comics')
$xml.Save($manifest)

flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get a échoué.' }

dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { throw 'La génération du logo Android a échoué.' }

Write-Host 'Nom et logo Zone Comics appliqués avec succès.'
