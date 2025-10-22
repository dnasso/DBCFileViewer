# Quick Build Guide

This guide shows how to build all release artifacts for DBC Parser.

## Prerequisites

### Windows
- Visual Studio 2022 (or MSVC compiler)
- CMake 3.20+
- Ninja (optional, recommended)
- Qt 6.8.x
- Inno Setup (for installer)

### Linux (WSL or native)
- flatpak
- flatpak-builder
- KDE Platform 6.8

### Docker
- Docker Desktop (Windows/Mac) or Docker Engine (Linux)

---

## Quick Start - Build Everything

### Windows (PowerShell)
```powershell
# Build all releases (Windows + Flatpak + Docker)
.\build-all-releases.ps1

# Or build individually:
.\build-all-releases.ps1 -SkipFlatpak  # Skip Flatpak
.\build-all-releases.ps1 -SkipDocker   # Skip Docker
.\build-all-releases.ps1 -SkipWindows  # Skip Windows
```

---

## Individual Builds

### 1. Windows Installer

**Full process:**
```powershell
# 1. Build the application
.\build-windows.ps1

# 2. Deploy Qt dependencies
.\deploy-windows.ps1

# 3. Create installer
.\build-installer.ps1
```

**Output:** `installer_output/DBC_Parser_Setup_1.0.0.exe`

---

### 2. Flatpak Bundle (Linux)

**On Linux or WSL:**
```bash
# Build and export bundle
./build-flatpak.sh

# Or manually:
flatpak-builder --repo=repo --disable-rofiles-fuse --force-clean build-dir com.qtdevs.DBCParser.yml
flatpak build-bundle repo dbc-parser.flatpak com.qtdevs.DBCParser
```

**Output:** `dbc-parser.flatpak`

**Install locally:**
```bash
flatpak install --user --bundle dbc-parser.flatpak
flatpak run com.qtdevs.DBCParser
```

---

### 3. Docker Image

**Build:**
```powershell
# Standard build
docker build -t dbc-parser:latest -f Dockerfile.linux .

# Optimized slim build
docker build -t dbc-parser:slim -f Dockerfile.linux .
```

**Run:**
```powershell
# Windows
.\run-docker-windows.ps1

# WSL with GUI support
.\run-docker-wslg.ps1

# Linux
./run-docker-linux.sh
```

**Export:**
```powershell
# Save as tarball for distribution
docker save dbc-parser:latest | gzip > dbc-parser-docker.tar.gz
```

---

## Build Outputs

After running `build-all-releases.ps1`:

```
📦 Build Artifacts:
├── installer_output/
│   └── DBC_Parser_Setup_1.0.0.exe    (~27 MB)
├── dbc-parser.flatpak                (~4 MB)
└── Docker image: dbc-parser:latest   (~150 MB)
```

---

## Distribution

### Windows
- Upload `DBC_Parser_Setup_1.0.0.exe` to GitHub Releases
- Users download and run the installer

### Linux
- **Flatpak:** Upload `dbc-parser.flatpak` or submit to Flathub
- **APT/DNF:** Create `.deb`/`.rpm` packages (see DISTRIBUTION.md)

### Docker
- Push to Docker Hub: `docker push yourusername/dbc-parser:latest`
- Or distribute the `.tar.gz` file

---

## Troubleshooting

### Windows Build Issues
- **CMake not found:** Install from https://cmake.org or `winget install Kitware.CMake`
- **Qt not found:** Set `$env:Qt6_DIR = "C:\Qt\6.8.2\msvc2022_64"`
- **Inno Setup missing:** Install from https://jrsoftware.org/isinfo.php

### Flatpak Build Issues
- **Platform not found:** `flatpak install flathub org.kde.Platform//6.8 org.kde.Sdk//6.8`
- **Permission errors:** Use `--disable-rofiles-fuse` flag on WSL
- **Cache issues:** `rm -rf .flatpak-builder build-dir repo`

### Docker Build Issues
- **Out of space:** `docker system prune -a`
- **Build slow:** Enable BuildKit: `$env:DOCKER_BUILDKIT=1`

---

## Clean Build

```powershell
# Remove all build artifacts
Remove-Item -Recurse -Force build, deploy, installer_output, build-dir, repo, .flatpak-builder -ErrorAction SilentlyContinue

# Remove generated files
Remove-Item *.flatpak, *.tar.gz -ErrorAction SilentlyContinue
```

---

## See Also
- [DEPLOYMENT.md](DEPLOYMENT.md) - Full deployment guide
- [DISTRIBUTION.md](DISTRIBUTION.md) - Distribution strategies
- [CODE_SIGNING.md](CODE_SIGNING.md) - Code signing guide
