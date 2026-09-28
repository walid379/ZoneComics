$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter est introuvable. Installe Flutter et ajoute son dossier bin au PATH.' }
flutter create --platforms android --project-name zone_comics --org com.spidey .
if ($LASTEXITCODE -ne 0) { throw 'La création de la plateforme Android a échoué.' }
$defaultWidgetTest = Join-Path $PSScriptRoot 'test\widget_test.dart'
if (Test-Path $defaultWidgetTest) { Remove-Item $defaultWidgetTest -Force }
$manifest = Join-Path $PSScriptRoot 'android\app\src\main\AndroidManifest.xml'
[xml]$xml = Get-Content $manifest -Raw
$androidNs = 'http://schemas.android.com/apk/res/android'
$xml.manifest.application.SetAttribute('label', $androidNs, 'Zone Comics')
$activity = $xml.manifest.application.activity | Select-Object -First 1
if ($activity -and $activity.GetAttribute('name', $androidNs) -eq '.MainActivity') {
    $activity.SetAttribute('name', $androidNs, 'com.spidey.zone_comics.MainActivity')
}
$existing = $xml.DocumentElement.SelectNodes('uses-permission') | Where-Object { $_.GetAttribute('name', $androidNs) -eq 'android.permission.INTERNET' }
if (-not $existing) {
    $permission = $xml.CreateElement('uses-permission')
    $attribute = $xml.CreateAttribute('android', 'name', $androidNs)
    $attribute.Value = 'android.permission.INTERNET'
    [void]$permission.Attributes.Append($attribute)
    [void]$xml.DocumentElement.InsertBefore($permission, $xml.DocumentElement.FirstChild)
}
$xml.Save($manifest)
$gradle = Join-Path $PSScriptRoot 'android\app\build.gradle.kts'
if (Test-Path $gradle) {
    (Get-Content $gradle -Raw).Replace('com.spidey.zone_comics', 'com.spidey.mycomics').Replace('minSdk = flutter.minSdkVersion', 'minSdk = 23') | Set-Content $gradle
}
$gradleGroovy = Join-Path $PSScriptRoot 'android\app\build.gradle'
if (Test-Path $gradleGroovy) {
    (Get-Content $gradleGroovy -Raw).Replace('com.spidey.zone_comics', 'com.spidey.mycomics').Replace('minSdkVersion flutter.minSdkVersion', 'minSdkVersion 23') | Set-Content $gradleGroovy
}
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'La récupération des dépendances a échoué.' }
dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { throw 'La génération du logo Android a échoué.' }
Write-Host 'Projet prêt. Ouvre ce dossier dans Android Studio puis lance lib/main.dart.'
