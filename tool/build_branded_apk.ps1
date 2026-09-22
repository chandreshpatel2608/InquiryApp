param(
    [Parameter(Mandatory = $true)]
    [string]$CompanyName,

    [Parameter(Mandatory = $true)]
    [string]$LogoPath,

    [ValidateSet("debug", "release", "profile")]
    [string]$BuildMode = "release"
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Require-Command -Name "flutter"
Require-Command -Name "dart"

$resolvedLogo = Resolve-Path $LogoPath -ErrorAction Stop
if (-not (Test-Path $resolvedLogo.Path -PathType Leaf)) {
    throw "Logo file not found: $LogoPath"
}

$ext = [System.IO.Path]::GetExtension($resolvedLogo.Path).ToLowerInvariant()
$allowed = @(".png", ".jpg", ".jpeg", ".webp")
if ($allowed -notcontains $ext) {
    throw "Logo must be one of: .png, .jpg, .jpeg, .webp"
}

$launcherConfigPath = Join-Path $projectRoot "flutter_launcher_icons-company.yaml"
$logoForYaml = $resolvedLogo.Path -replace "\\", "/"

$yaml = @"
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "$logoForYaml"
  min_sdk_android: 21
"@

Set-Content -Path $launcherConfigPath -Value $yaml -Encoding utf8

Write-Host "[1/4] Fetching Flutter packages..."
flutter pub get

Write-Host "[2/4] Generating launcher icons from company logo..."
dart run flutter_launcher_icons -f $launcherConfigPath

Write-Host "[3/4] Building APK with company app name..."
$env:APP_NAME = $CompanyName
flutter build apk --$BuildMode

$apkPath = Join-Path $projectRoot "build/app/outputs/flutter-apk/app-$BuildMode.apk"
if (-not (Test-Path $apkPath -PathType Leaf)) {
    throw "APK was not generated at expected path: $apkPath"
}

$sanitizedName = ($CompanyName -replace "[^a-zA-Z0-9\-_]", "_").Trim("_")
if ([string]::IsNullOrWhiteSpace($sanitizedName)) {
    $sanitizedName = "company"
}

$finalName = "$sanitizedName-$BuildMode.apk"
$finalPath = Join-Path (Split-Path $apkPath -Parent) $finalName
Copy-Item -Path $apkPath -Destination $finalPath -Force

Write-Host "[4/4] Done"
Write-Host "Branded APK: $finalPath"
Write-Host "Installed app name: $CompanyName"
Write-Host "Installed app icon source: $($resolvedLogo.Path)"
