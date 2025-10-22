# Distribution Package Overview

Complete guide to all distribution methods for DBC Parser.

## 🎯 Quick Links

- [Deployment Guide](./DEPLOYMENT.md) - Full deployment instructions
- [Quick Reference](./DEPLOYMENT_QUICK_REF.md) - Command cheatsheet
- [Code Signing](./CODE_SIGNING.md) - Security and signing guide

## 📦 Distribution Methods

### 1. Windows Installer (Recommended for Windows)

**Format:** `.exe` installer (Inno Setup)  
**Size:** ~100-150 MB  
**Pros:** Professional installer, file associations, Start Menu integration  
**Cons:** Requires Inno Setup to build

**Build Steps:**
```powershell
# 1. Deploy application
.\deploy-windows.ps1

# 2. Build installer
.\build-installer.ps1

# 3. Sign (optional but recommended)
.\sign-windows.ps1 -CertPath cert.pfx -Password "password"

# Output: installer_output\DBC_Parser_Setup_1.0.0.exe
```

**Files:**
- `installer.iss` - Inno Setup script
- `build-installer.ps1` - Build automation
- `sign-windows.ps1` - Code signing

---

### 2. Windows Portable (ZIP)

**Format:** `.zip` archive  
**Size:** ~100-150 MB  
**Pros:** No installation needed, works offline  
**Cons:** No file associations, manual updates

**Build Steps:**
```powershell
# 1. Deploy
.\deploy-windows.ps1

# 2. Create ZIP
Compress-Archive -Path '.\deploy\windows\*' -DestinationPath 'DBC_Parser_Windows_Portable.zip'

# Output: DBC_Parser_Windows_Portable.zip
```

---

### 3. Linux AppImage (Recommended for Linux)

**Format:** `.AppImage` single file  
**Size:** ~120-180 MB  
**Pros:** Works on all distros, no installation, portable  
**Cons:** Larger file size

**Build Steps:**
```bash
# 1. Build application
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build

# 2. Create AppImage
./deploy-linux.sh

# Output: deploy/linux/DBC_Parser-x86_64.AppImage
```

**Usage:**
```bash
chmod +x DBC_Parser-x86_64.AppImage
./DBC_Parser-x86_64.AppImage
```

**Files:**
- `deploy-linux.sh` - Deployment script
- Downloads `linuxdeploy` automatically

---

### 4. Linux Flatpak

**Format:** `.flatpak` bundle or Flathub distribution  
**Size:** ~130-200 MB  
**Pros:** Sandboxed, automatic updates (via Flathub), system integration  
**Cons:** Requires Flatpak runtime

**Build Steps:**
```bash
# 1. Build Flatpak
./build-flatpak.sh

# 2. Create bundle for distribution
flatpak build-bundle flatpak-repo dbc-parser.flatpak com.qtdevs.DBCParser

# Output: dbc-parser.flatpak
```

**Installation:**
```bash
# Install bundle
flatpak install dbc-parser.flatpak

# Or install from Flathub (after publishing)
flatpak install flathub com.qtdevs.DBCParser
```

**Files:**
- `com.qtdevs.DBCParser.yml` - Flatpak manifest
- `build-flatpak.sh` - Build automation

---

### 5. Docker Container (Development/Server)

**Format:** Docker image  
**Size:** ~870 MB (includes full Qt runtime)  
**Pros:** Consistent environment, includes all dependencies  
**Cons:** Large size, requires Docker and X11 server

**Build & Run:**
```powershell
# Windows (with VcXsrv)
docker build -f Dockerfile.linux -t dbc-parser:debian-slim .
.\run-docker-windows.ps1

# Linux (with X11)
docker build -f Dockerfile.linux -t dbc-parser:debian-slim .
docker run --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix dbc-parser:debian-slim
```

**Files:**
- `Dockerfile.linux` - Debian-based image
- `run-docker-windows.ps1` - Windows runner
- `run-docker-mac.sh` - macOS runner

---

## 🔐 Code Signing

### Windows

```powershell
# Sign executable and installer
.\sign-windows.ps1 -CertPath cert.pfx -Password "password"
```

**Benefits:**
- No "Unknown Publisher" warnings
- SmartScreen trust (with EV certificates)
- User confidence

### Linux

```bash
# Sign AppImage
gpg --detach-sign --armor -o DBC_Parser.AppImage.sig DBC_Parser.AppImage

# Sign Flatpak
flatpak build-bundle flatpak-repo dbc-parser.flatpak com.qtdevs.DBCParser --gpg-sign=your@email.com
```

See [CODE_SIGNING.md](./CODE_SIGNING.md) for detailed instructions.

---

## 📊 Size Comparison

| Method | Size | Build Time | Best For |
|--------|------|------------|----------|
| Windows Installer | 100-150 MB | ~5 min | End users (Windows) |
| Windows ZIP | 100-150 MB | ~2 min | Portable use |
| Linux AppImage | 120-180 MB | ~10 min | Most Linux users |
| Flatpak | 130-200 MB | ~15 min | Linux app stores |
| Docker | 870 MB | ~20 min | Development/testing |

---

## 🚀 Distribution Workflow

### For Windows Users

1. **Development Build:**
   ```powershell
   cmake -B build -DCMAKE_BUILD_TYPE=Release
   cmake --build build --config Release
   .\deploy-windows.ps1
   ```

2. **Create Installer:**
   ```powershell
   .\build-installer.ps1
   ```

3. **Sign (Optional):**
   ```powershell
   .\sign-windows.ps1 -CertPath cert.pfx -Password "password"
   ```

4. **Test:**
   - Run installer on clean VM
   - Verify no warnings
   - Test file associations (.dbc files)

5. **Distribute:**
   - Upload to GitHub Releases
   - Host on your website
   - Share download link

### For Linux Users

1. **Development Build:**
   ```bash
   cmake -B build -DCMAKE_BUILD_TYPE=Release
   cmake --build build
   ```

2. **Create AppImage:**
   ```bash
   ./deploy-linux.sh
   ```

3. **Or Create Flatpak:**
   ```bash
   ./build-flatpak.sh
   ```

4. **Sign (Optional):**
   ```bash
   gpg --detach-sign --armor -o DBC_Parser.AppImage.sig DBC_Parser.AppImage
   ```

5. **Distribute:**
   - Upload to GitHub Releases
   - Publish to Flathub
   - Share on Linux forums

---

## 📝 File Structure

```
DBCFileViewer/
├── deploy-windows.ps1          # Windows deployment
├── build-installer.ps1         # Inno Setup build
├── sign-windows.ps1            # Windows signing
├── installer.iss               # Inno Setup script
├── deploy-linux.sh             # Linux AppImage
├── build-flatpak.sh            # Flatpak build
├── com.qtdevs.DBCParser.yml    # Flatpak manifest
├── Dockerfile.linux            # Docker image
├── run-docker-windows.ps1      # Docker runner (Windows)
├── run-docker-mac.sh           # Docker runner (macOS)
├── DEPLOYMENT.md               # Full guide
├── DEPLOYMENT_QUICK_REF.md     # Quick reference
├── CODE_SIGNING.md             # Signing guide
└── DISTRIBUTION.md             # This file
```

---

## 🎓 Tutorial: First Release

### Step 1: Build All Platforms

**Windows:**
```powershell
.\deploy-windows.ps1
.\build-installer.ps1
# Creates: installer_output\DBC_Parser_Setup_1.0.0.exe
```

**Linux:**
```bash
./deploy-linux.sh
# Creates: deploy/linux/DBC_Parser-x86_64.AppImage
```

### Step 2: Sign (Optional)

**Windows:**
```powershell
.\sign-windows.ps1 -CertPath cert.pfx -Password "password"
```

**Linux:**
```bash
gpg --detach-sign --armor -o DBC_Parser.AppImage.sig deploy/linux/DBC_Parser-x86_64.AppImage
```

### Step 3: Test

- Test installer on clean Windows VM
- Test AppImage on Ubuntu, Fedora, Arch
- Verify functionality
- Check for warnings

### Step 4: Create GitHub Release

```bash
# Tag version
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# Upload to GitHub Releases:
# - DBC_Parser_Setup_1.0.0.exe (Windows installer)
# - DBC_Parser_Windows_Portable.zip (Windows portable)
# - DBC_Parser-x86_64.AppImage (Linux)
# - DBC_Parser-x86_64.AppImage.sig (Linux signature)
# - dbc-parser.flatpak (Linux Flatpak)
```

### Step 5: Announce

- Update README.md with download links
- Post on relevant forums/communities
- Share on social media
- Submit to software directories

---

## ✅ Pre-Release Checklist

- [ ] All platforms build successfully
- [ ] Applications signed (if applicable)
- [ ] Tested on clean systems
- [ ] No antivirus false positives
- [ ] Version numbers updated
- [ ] CHANGELOG.md updated
- [ ] README.md has download instructions
- [ ] Screenshots/demos prepared
- [ ] License files included
- [ ] Sample .dbc files included

---

## 🆘 Common Issues

### Windows

**"windeployqt not found"**
- Ensure Qt is installed
- Specify -QtDir parameter

**"Installer won't build"**
- Install Inno Setup
- Check paths in installer.iss

**"Signature invalid"**
- Verify certificate is valid
- Check certificate password
- Use correct timestamp server

### Linux

**"AppImage won't run"**
- Install FUSE: `sudo apt install libfuse2`
- Check file permissions: `chmod +x *.AppImage`

**"Flatpak build fails"**
- Install Flatpak runtime
- Check manifest syntax
- Verify Git repository URL

---

## 📚 Additional Resources

- [Qt Deployment Docs](https://doc.qt.io/qt-6/deployment.html)
- [Inno Setup Documentation](https://jrsoftware.org/ishelp/)
- [AppImage Guide](https://docs.appimage.org/)
- [Flatpak Documentation](https://docs.flatpak.org/)
- [Authenticode Signing](https://docs.microsoft.com/en-us/windows-hardware/drivers/install/authenticode)

---

## 💡 Tips

1. **Version Numbering:** Use semantic versioning (MAJOR.MINOR.PATCH)
2. **File Naming:** Include version and platform in filename
3. **Checksums:** Provide SHA256 checksums for downloads
4. **Changelog:** Maintain detailed changelog
5. **Support:** Provide clear support channels
6. **Updates:** Plan for auto-update mechanism
7. **Analytics:** Consider usage analytics (opt-in)
8. **Backups:** Keep old releases available

---

## 🔄 Continuous Integration

See `.github/workflows/` for automated building and releasing via GitHub Actions.

Example workflow:
1. Push tag to GitHub
2. CI builds all platforms
3. CI signs executables
4. CI creates GitHub Release
5. CI uploads all artifacts
6. Users download from Releases page
