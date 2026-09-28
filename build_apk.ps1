$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Test-Path 'android\gradlew.bat')) { & .\setup_android.ps1 }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get a échoué.' }
flutter build apk --debug
if ($LASTEXITCODE -ne 0) { throw 'La compilation APK a échoué.' }
Write-Host "APK : $PSScriptRoot\build\app\outputs\flutter-apk\app-debug.apk"
