# Dukan Smart Flutter App

## Build Company Branded Android APK

This project supports generating a branded Android APK where:

- Installed app name = company name
- Installed app icon = company logo

### Prerequisites

- Flutter SDK available in PATH
- Dart SDK available in PATH
- A company logo image file (`.png`, `.jpg`, `.jpeg`, or `.webp`)

### Command

Run from the `app` folder:

```powershell
pwsh -File .\tool\build_branded_apk.ps1 -CompanyName "Acme Traders" -LogoPath "C:\logos\acme.png" -BuildMode release
```

### Output

- Standard APK: `build/app/outputs/flutter-apk/app-release.apk`
- Branded copy: `build/app/outputs/flutter-apk/Acme_Traders-release.apk`

### Important Notes

- Android launcher icon is generated from the provided logo file before each build.
- Use a square, high-resolution logo image for best results (recommended: 1024x1024).
- If you build APKs for different companies, run the script again with that company's name and logo.
