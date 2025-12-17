# Installer Generation Guide

This guide explains how to build the release binaries and generate installers for Windows, Linux, macOS, and Android.

## 1. Windows Installer (`.exe`)
**Prerequisites**:
- [Inno Setup Compiler](https://jrsoftware.org/isdl.php) installed.

**Steps**:
1. Build the release version of the Windows app:
   ```cmd
   flutter build windows --release
   ```
2. Open `installers\windows\installer.iss` in **Inno Setup Compiler**.
3. Click **Build > Compile**.
4. The output file `SwiftDockSetup.exe` will be generated in `installers\windows\output`.

## 2. Linux Package (`.deb`)
**Prerequisites**:
- Debian-based system (Ubuntu, etc.) for building.
- `flutter_to_debian` package installed (via pubspec).

**Steps**:
1. Build the release version of the Linux app:
   ```bash
   flutter build linux --release
   ```
2. Run the packaging tool:
   ```bash
   flutter pub run flutter_to_debian:main
   ```
3. The `.deb` file will be generated in `debian/dist`.

## 3. macOS Disk Image (`.dmg`)
**Prerequisites**:
- macOS environment.
- [create-dmg](https://github.com/create-dmg/create-dmg) (install via homebrew: `brew install create-dmg`).

**Steps**:
1. Build the release version of the macOS app:
   ```bash
   flutter build macos --release
   ```
2. Run `create-dmg`:
   ```bash
   create-dmg \
     --volname "Swift Dock Installer" \
     --volicon "assets/app_icon.icns" \
     --window-pos 200 120 \
     --window-size 800 400 \
     --icon-size 100 \
     --icon "Swift Dock.app" 200 190 \
     --hide-extension "Swift Dock.app" \
     --app-drop-link 600 185 \
     "Swift Dock.dmg" \
     "build/macos/Build/Products/Release/docker_portal.app"
   ```

## 4. Android APK (`.apk`)
**Steps**:
1. Build the release APK:
   ```bash
   flutter build apk --release --no-tree-shake-icons
   ```
   > **Note**: The `--no-tree-shake-icons` flag is required because the app loads icons dynamically from JSON configuration.

2. The APK will be generated in `build/app/outputs/flutter-apk/app-release.apk`.
