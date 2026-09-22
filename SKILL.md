---
name: flutter-apk-setup
description: "Set up a shared Flutter application on a new Windows machine, install or verify Flutter/Android prerequisites, configure the API endpoint, restore packages, apply the optional local database migration, run analyzer and tests, and build a debug or release APK. Use when receiving Flutter source code and asked to automatically set up, run, package, or generate an APK."
---

# Flutter APK Setup

Use this skill when the user shares a Flutter application and wants a repeatable setup that ends with an APK.

## Scope

This workflow assumes:

- The Flutter project is the directory containing `pubspec.yaml`.
- The Android target is enabled.
- Windows PowerShell is available.
- The application may require a separate HTTP API. A Flutter APK can build without the API, but login, catalog, cart, payment, and other live features will not work until `API_BASE_URL` points to a reachable server.

Never invent API credentials, signing passwords, keystores, SMTP credentials, payment keys, or production secrets.

## Inputs

Ask only for values that are not discoverable from the source:

- Flutter project directory, if more than one `pubspec.yaml` exists.
- Build mode: `debug` or `release`.
- API URL, unless the source default is intentionally used.
- Android application ID and signing configuration, only for release builds.
- Whether a local backend/database is also available.

For this project, the normal Flutter directory is `app/` and the optional ASP.NET backend is `R/`.

## Workflow

### 1. Discover the project

From the shared source root, find `pubspec.yaml` and select the Flutter app directory. Do not assume the current directory is the Flutter directory.

```powershell
$flutterDir = Get-ChildItem -Path . -Filter pubspec.yaml -Recurse -File |
  Select-Object -First 1 -ExpandProperty DirectoryName
if (-not $flutterDir) { throw 'No Flutter project found: pubspec.yaml is missing.' }
Set-Location $flutterDir
```

Confirm that `android/` exists before attempting an APK build. If it does not exist, stop and run `flutter create --platforms=android .` only after confirming that generating platform files is acceptable.

### 2. Verify prerequisites

Check the tools before changing files:

```powershell
flutter --version
flutter doctor -v
java -version
adb version
```

Required conditions:

- Flutter is installed and on `PATH`.
- Android SDK and Android toolchain are available in `flutter doctor`.
- A JDK compatible with the Flutter/Gradle version is available.
- Android SDK licenses are accepted.

If Flutter is missing, tell the user to install the official stable Flutter SDK and Android Studio, add Flutter and Android SDK tools to `PATH`, then rerun this workflow. Do not download installers or change system-wide environment variables without approval.

Accept licenses when the Android SDK is already installed:

```powershell
flutter doctor --android-licenses
```

### 3. Restore dependencies

```powershell
flutter clean
flutter pub get
```

Do not upgrade dependency versions automatically. Preserve the versions in `pubspec.yaml` unless the user explicitly requests dependency upgrades.

### 4. Configure the API endpoint

Prefer a build-time define; do not hard-code a machine-specific IP or secret into source files.

```powershell
$apiUrl = 'https://your-api-host/digitalcard/api'
flutter config --no-analytics
flutter run --dart-define=API_BASE_URL=$apiUrl
```

For an Android emulator calling a development API on the host machine, use the address and protocol supported by the backend, commonly:

```text
https://10.0.2.2:7076/digitalcard/api
```

For a physical device, use a reachable HTTPS host or the development machine's LAN IP and ensure the firewall and certificate are configured. Do not use `localhost` for a physical Android device.

For this repository, `app/lib/config.dart` contains the default endpoint and documents the override pattern. Keep the default unless the user asks to change it.

### 5. Apply an optional backend migration

Only do this when the backend source and its database are also present. The migration script is not part of Flutter APK generation.

```powershell
Set-Location <source-root>
if (Test-Path .\apply_migrations.py) {
  python .\apply_migrations.py
}
Set-Location <flutter-project-directory>
```

If the database file is not in the expected location, stop and ask for the database path. Never run migrations against production without explicit confirmation and a backup.

### 6. Validate the Flutter code

Run the narrow checks before building:

```powershell
flutter analyze
flutter test
```

Treat analyzer errors and test failures as blockers. Existing informational lints may be reported but do not justify changing unrelated files.

### 7. Build the APK

Debug APK:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=$apiUrl
```

Release APK without signing setup:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=$apiUrl
```

A signed release build requires a user-provided keystore and signing configuration. Never generate or print passwords in the workflow.

Typical outputs:

```text
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
```

Find the actual output instead of assuming its name:

```powershell
Get-ChildItem .\build\app\outputs\flutter-apk\*.apk -File
```

### 8. Smoke test

When an emulator or device is available:

```powershell
adb devices
flutter install --debug --dart-define=API_BASE_URL=$apiUrl
```

Verify at minimum:

1. App launches.
2. Login or customer store opens.
3. Store products load from the configured API.
4. Add-to-cart and checkout screens open.
5. Dashboard navigation is not shown in customer store mode.
6. API failures show a useful message instead of a crash.

Do not perform a real payment during automated smoke testing unless the user explicitly supplies a test environment and test credentials.

## Failure handling

- `No pubspec.yaml`: locate the Flutter project; do not run commands from the source parent.
- `flutter doctor` Android errors: fix SDK/JDK/licenses before retrying Gradle.
- `flutter pub get` failure: report the package and version conflict; do not silently upgrade packages.
- `flutter analyze` errors: fix only errors introduced by the shared source or report existing failures.
- Gradle timeout: check whether Gradle is still running, then rerun with a longer timeout. Do not start multiple APK builds concurrently.
- APK builds but API calls fail: verify `API_BASE_URL`, HTTPS certificate, firewall, CORS/server availability, and device network reachability.
- Release signing failure: request the keystore and signing values from the owner; never guess them.

## Completion report

Report:

- Flutter version and project directory.
- API URL used, excluding secrets.
- Whether backend migration was run.
- `flutter analyze` result.
- `flutter test` result.
- APK build mode and exact APK path.
- Any remaining warnings, lints, or environment blockers.
