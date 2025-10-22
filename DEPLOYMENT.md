# Qt Deployment Guide for DBC Parser

This guide covers creating standalone, redistributable packages for Windows and Linux.

## Prerequisites

### Windows
- Qt installation with `windeployqt.exe` (included with Qt)
- Built executable in release mode
- PowerShell 5.0 or later

### Linux
- Built executable
- Internet connection (for downloading linuxdeploy on first run)
- FUSE support for running AppImages (usually pre-installed)
- Optional: ImageMagick for icon conversion

## Quick Start

### Windows

1. **Build your application in Release mode:**
   ```powershell
   cmake -B build -DCMAKE_BUILD_TYPE=Release
   cmake --build build --config Release
   ```

2. **Run the deployment script:**
   ```powershell
   .\deploy-windows.ps1
   ```

3. **Find your deployed app in:**
   ```
   .\deploy\windows\
   ```

4. **Create a distributable ZIP:**
   ```powershell
   Compress-Archive -Path '.\deploy\windows\*' -DestinationPath 'DBC_Parser_Windows.zip'
   ```

### Linux

1. **Build your application in Release mode:**
   ```bash
   cmake -B build -DCMAKE_BUILD_TYPE=Release
   cmake --build build
   ```

2. **Run the deployment script:**
   ```bash
   chmod +x deploy-linux.sh
   ./deploy-linux.sh
   ```

3. **Find your AppImage in:**
   ```
   ./deploy/linux/
   ```

4. **Run the AppImage:**
   ```bash
   chmod +x ./deploy/linux/*.AppImage
   ./deploy/linux/DBC_Parser-x86_64.AppImage
   ```

## Advanced Usage

### Windows - Custom Qt Location

If Qt is not auto-detected:
```powershell
.\deploy-windows.ps1 -QtDir "C:\Qt\6.8.2\msvc2022_64"
```

### Windows - Specify Build Directory

If your build is in a different location:
```powershell
.\deploy-windows.ps1 -BuildDir ".\build-custom" -OutputDir ".\release"
```

### Linux - Custom Qt and Build Paths

```bash
export QT_DIR="/path/to/Qt/6.8.2/gcc_64"
export BUILD_DIR="./build-custom"
./deploy-linux.sh
```

### Linux - Using Docker for Portable Builds

To ensure maximum compatibility (works on older Linux distros):
```bash
# Build inside the Debian container
docker build -f Dockerfile.linux -t dbc-parser:debian-slim .

# Extract the built binary
docker create --name temp dbc-parser:debian-slim
docker cp temp:/app/bin/appDBC_Parser ./appDBC_Parser
docker rm temp

# Deploy
BUILD_DIR=. ./deploy-linux.sh
```

## Deployment Sizes

Typical deployment sizes:

| Platform | Method | Size |
|----------|--------|------|
| Windows | windeployqt | ~100-150 MB |
| Linux | AppImage | ~120-180 MB |
| Linux | Docker image | ~870 MB (includes full Qt runtime) |

## Creating Installers

### Windows - Inno Setup

1. Download and install [Inno Setup](https://jrsoftware.org/isinfo.php)

2. Create `installer.iss`:
   ```innosetup
   [Setup]
   AppName=DBC Parser
   AppVersion=1.0.0
   DefaultDirName={pf}\DBC Parser
   DefaultGroupName=DBC Parser
   OutputDir=.
   OutputBaseFilename=DBC_Parser_Setup

   [Files]
   Source: "deploy\windows\*"; DestDir: "{app}"; Flags: recursesubdirs

   [Icons]
   Name: "{group}\DBC Parser"; Filename: "{app}\appDBC_Parser.exe"
   ```

3. Compile:
   ```powershell
   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
   ```

### Linux - Flatpak

For system-wide installation and sandboxing:

1. Create `com.qtdevs.DBCParser.yml` (Flatpak manifest)
2. Build with `flatpak-builder`
3. Distribute via Flathub or as `.flatpak` file

See: https://docs.flatpak.org/en/latest/building.html

## Automated CMake Deployment

Add to `CMakeLists.txt`:

```cmake
# Windows deployment target
if(WIN32)
    find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${QT_DIR}/bin")
    if(WINDEPLOYQT_EXECUTABLE)
        add_custom_target(deploy_windows
            COMMAND ${CMAKE_COMMAND} -E remove_directory "${CMAKE_BINARY_DIR}/deploy"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/deploy"
            COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:appDBC_Parser> "${CMAKE_BINARY_DIR}/deploy/"
            COMMAND ${WINDEPLOYQT_EXECUTABLE}
                --release
                --qmldir "${CMAKE_SOURCE_DIR}"
                --no-compiler-runtime
                "${CMAKE_BINARY_DIR}/deploy/$<TARGET_FILE_NAME:appDBC_Parser>"
            COMMENT "Deploying Windows application with windeployqt"
        )
    endif()
endif()

# Linux deployment target
if(UNIX AND NOT APPLE)
    add_custom_target(deploy_linux
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:appDBC_Parser> "${CMAKE_BINARY_DIR}/"
        COMMAND bash "${CMAKE_SOURCE_DIR}/deploy-linux.sh"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        COMMENT "Deploying Linux application with linuxdeploy"
    )
endif()
```

Then deploy with:
```bash
cmake --build build --target deploy_windows  # or deploy_linux
```

## Troubleshooting

### Windows - "VCRUNTIME140.dll not found"
- Install Visual C++ Redistributable: https://aka.ms/vs/17/release/vc_redist.x64.exe
- Or include with `--compiler-runtime` flag in windeployqt

### Linux - "AppImage won't run"
- Check FUSE: `sudo apt install fuse libfuse2`
- Or extract and run directly: `./app.AppImage --appimage-extract && ./squashfs-root/AppRun`

### "Qt platform plugin could not be initialized"
- Verify `platforms` folder exists in deployment
- Check Qt plugin path with `QT_DEBUG_PLUGINS=1`

### Linux - "GLIBC version not found"
- Build on older distro (e.g., Ubuntu 20.04 LTS) for maximum compatibility
- Or use the Docker build method

## Distribution Checklist

Before distributing your application:

- [ ] Test on clean Windows/Linux system without Qt installed
- [ ] Verify all required DLLs/libraries are included
- [ ] Test with sample .dbc files
- [ ] Include README and license files
- [ ] Add icon and desktop integration
- [ ] Sign executable (Windows: Authenticode, Linux: GPG)
- [ ] Create installer/package for easy installation
- [ ] Test on multiple OS versions (Windows 10/11, Ubuntu 20.04/22.04/24.04)

## References

- [Qt Deployment Documentation](https://doc.qt.io/qt-6/deployment.html)
- [windeployqt Manual](https://doc.qt.io/qt-6/windows-deployment.html)
- [linuxdeploy GitHub](https://github.com/linuxdeploy/linuxdeploy)
- [AppImage Documentation](https://docs.appimage.org/)
