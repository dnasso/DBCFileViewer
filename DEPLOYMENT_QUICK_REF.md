# Qt Deployment Quick Reference

## Building for Deployment

### Windows
```powershell
# Configure and build (Release mode)
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release

# Option 1: Use CMake target (recommended)
cmake --build build --target deploy

# Option 2: Use standalone script
.\deploy-windows.ps1

# Create installer-ready ZIP
cmake --build build --target package
```

### Linux
```bash
# Configure and build (Release mode)
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build

# Option 1: Use CMake target (recommended)
cmake --build build --target deploy

# Option 2: Use standalone script
./deploy-linux.sh

# Result: Creates AppImage in deploy/linux/
```

### macOS
```bash
# Configure and build (Release mode)
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build

# Deploy and create .app bundle
cmake --build build --target deploy

# Create DMG installer
cmake --build build --target package
```

## Manual Deployment (Without Scripts)

### Windows - windeployqt
```powershell
cd build\Release
C:\Qt\6.8.2\msvc2022_64\bin\windeployqt.exe --release --qmldir ..\..\. appDBC_Parser.exe
```

### Linux - linuxdeploy
```bash
# Download tools (one-time)
wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
wget https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
chmod +x linuxdeploy*.AppImage

# Deploy
export QMAKE=/path/to/Qt/6.8.2/gcc_64/bin/qmake
./linuxdeploy-x86_64.AppImage \
    --executable=build/appDBC_Parser \
    --plugin qt \
    --output appimage
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Windows: "VCRUNTIME140.dll not found" | Install [VC++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe) |
| Linux: "AppImage won't run" | Install FUSE: `sudo apt install libfuse2` |
| "Qt platform plugin could not be initialized" | Verify `platforms/` folder exists |
| Linux: "GLIBC version not found" | Build on older distro (Ubuntu 20.04) |

## Distribution Checklist

- [ ] Build in Release mode (`CMAKE_BUILD_TYPE=Release`)
- [ ] Test on clean system without Qt installed
- [ ] Include README.md and LICENSE
- [ ] Add application icon
- [ ] Test with sample .dbc files
- [ ] Sign executable (Windows/macOS)
- [ ] Create installer package
- [ ] Test on multiple OS versions

## File Sizes (Approximate)

| Platform | Size |
|----------|------|
| Windows (deployed) | 100-150 MB |
| Linux AppImage | 120-180 MB |
| macOS .app bundle | 130-200 MB |
| Docker image | ~870 MB |

## See Also

- [DEPLOYMENT.md](./DEPLOYMENT.md) - Complete deployment guide
- [Qt Deployment Docs](https://doc.qt.io/qt-6/deployment.html)
- [AppImage Documentation](https://docs.appimage.org/)
