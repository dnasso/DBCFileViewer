# macOS Deployment Guide

This guide covers deploying and distributing the DBC Parser application on macOS.

## Prerequisites

- **Qt 6.8.2** (or compatible version) installed on macOS
- **Xcode Command Line Tools** (for code signing and packaging)
- **CMake** (for building)

## Quick Start

### Option 1: All-in-One Build (Recommended)

Build, deploy, and create DMG in one command:

```bash
chmod +x build-all-macos.sh
./build-all-macos.sh
```

### Option 2: Step-by-Step

```bash
# Step 1: Deploy (builds app bundle with all dependencies)
chmod +x deploy-macos.sh
./deploy-macos.sh

# Step 2: Create DMG installer
chmod +x build-installer-macos.sh
./build-installer-macos.sh
```

## Scripts Overview

### `deploy-macos.sh`

Creates a standalone `.app` bundle with all Qt dependencies:
- Runs `macdeployqt` to bundle Qt frameworks
- Copies application icon (.icns)
- Includes sample DBC files and documentation
- Output: `deploy/macos/appDBC_Parser.app`

**Usage:**
```bash
./deploy-macos.sh
```

### `build-installer-macos.sh`

Creates a distributable DMG installer:
- Creates a disk image with custom layout
- Adds "Applications" symlink for easy installation
- Sets custom volume icon
- Compresses to reduce file size
- Output: `installer_output/DBC_Parser_Installer_1.0.0.dmg`

**Usage:**
```bash
./build-installer-macos.sh
```

### `build-all-macos.sh`

Complete automated build process:
- Builds the application with CMake
- Deploys with `macdeployqt`
- Creates DMG installer
- Output: Complete installer ready for distribution

**Options:**
```bash
./build-all-macos.sh                # Full build
./build-all-macos.sh --build-only   # Build only, no deploy
./build-all-macos.sh --deploy-only  # Deploy only, no build
./build-all-macos.sh --dmg-only     # Create DMG only
```

## Configuration

### Qt Installation

Scripts auto-detect Qt in these locations:
- `$HOME/Qt/6.8.2/macos`
- `$HOME/Qt/6.8.0/macos`
- `/opt/Qt/6.8.2/macos`
- `/usr/local/Qt-6.8.2`
- `/Applications/Qt/6.8.2/macos`

Or set manually:
```bash
export QTDIR=$HOME/Qt/6.8.2/macos
./deploy-macos.sh
```

### Custom Icon

Place your icon files in `deploy-assets/`:
- `dbctrain.png` - PNG format for conversion
- `dbctrain.icns` - Pre-made icon (optional)

The script will generate `.icns` from PNG if `sips` and `iconutil` are available.

## Testing

### Test App Bundle
```bash
open deploy/macos/appDBC_Parser.app
```

### Test DMG Installer
```bash
open installer_output/DBC_Parser_Installer_1.0.0.dmg
```

## Distribution

### For Development/Testing
- Share the `.app` bundle directly
- Users drag to Applications folder

### For End Users (Recommended)
1. **Create DMG** (done by scripts)
2. **Code Sign** the app and DMG:
   ```bash
   # Sign the app
   codesign --deep --force --verify --verbose \
     --sign "Developer ID Application: Your Name" \
     deploy/macos/appDBC_Parser.app
   
   # Rebuild DMG after signing
   ./build-installer-macos.sh
   
   # Sign the DMG
   codesign --force --sign "Developer ID Application: Your Name" \
     installer_output/DBC_Parser_Installer_1.0.0.dmg
   ```

3. **Notarize** with Apple (required for macOS 10.15+):
   ```bash
   # Submit for notarization
   xcrun notarytool submit \
     installer_output/DBC_Parser_Installer_1.0.0.dmg \
     --keychain-profile "AC_PASSWORD" \
     --wait
   
   # Staple the notarization ticket
   xcrun stapler staple \
     installer_output/DBC_Parser_Installer_1.0.0.dmg
   ```

See `CODE_SIGNING.md` for detailed signing instructions.

## Troubleshooting

### macdeployqt Not Found
```bash
# Set Qt directory
export QTDIR=/path/to/Qt/6.8.2/macos
./deploy-macos.sh
```

### App Won't Open ("Damaged" Error)
- App needs to be code signed
- Or allow in System Preferences → Security & Privacy

### Missing Icon
- Check `deploy-assets/dbctrain.png` exists
- Install Xcode Command Line Tools: `xcode-select --install`
- Or create `.icns` manually with Icon Composer

### DMG Creation Fails
- Ensure enough disk space (at least 200MB free)
- Check app bundle exists in `deploy/macos/`
- Run with verbose output: `bash -x build-installer-macos.sh`

## File Structure

After successful build:
```
DBCFileViewer/
├── deploy/
│   └── macos/
│       └── appDBC_Parser.app/
│           ├── Contents/
│           │   ├── MacOS/
│           │   │   └── appDBC_Parser
│           │   ├── Frameworks/  (Qt libraries)
│           │   ├── PlugIns/     (Qt plugins)
│           │   └── Resources/
│           │       ├── dbctrain.icns
│           │       ├── samples/
│           │       └── docs/
│           └── Info.plist
├── installer_output/
│   └── DBC_Parser_Installer_1.0.0.dmg
└── build/
    └── Desktop_Qt_6_8_2_clang_64-Release/
        └── appDBC_Parser.app (original build)
```

## Platform Comparison

| Feature | Windows | macOS | Linux |
|---------|---------|-------|-------|
| **Installer** | `.exe` (Inno Setup) | `.dmg` | `.AppImage` / `.deb` |
| **Deploy Tool** | `windeployqt` | `macdeployqt` | `linuxdeployqt` |
| **Code Signing** | Authenticode | codesign + notarization | Optional |
| **Icon Format** | `.ico` | `.icns` | `.png` |
| **App Structure** | Flat directory | `.app` bundle | Flat directory |

## See Also

- [Windows Deployment](DEPLOYMENT.md)
- [Linux Deployment](deploy-linux.sh)
- [Code Signing Guide](CODE_SIGNING.md)
- [Docker Deployment](run-docker-mac.sh)
