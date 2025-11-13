# OBS Packaging Quick Start

Two ways to upload your code to Open Build Service (OBS):

## 🚀 Quick Method: Manual Upload

Upload the current code immediately:

### Windows:
```powershell
.\scripts\package-and-upload.ps1
```

### Linux/WSL:
```bash
./scripts/package-and-upload.sh
```

This creates tarballs from your current code and uploads them to OBS.

---

## 🤖 Automatic Method: SCM Monitoring

Set up automatic builds when you push to GitHub:

### Windows:
```powershell
.\scripts\setup-obs-scm.ps1
```

### Linux/WSL:
```bash
./scripts/setup-obs-scm.sh
```

**After running this, you need to:**
1. Go to https://build.opensuse.org/package/show/home:GuyFerrari/dbc-file-viewer
2. Click "Source Files" tab
3. Click "Trigger Services" button
4. Go to "Repositories" tab and enable automatic rebuilds

---

## 📦 What's Configured

- **Monitored Branch:** `obs-docker-ghactions` 
- **Repository:** https://github.com/dnasso/DBCFileViewer.git
- **OBS Package:** home:GuyFerrari/dbc-file-viewer

---

## 📖 More Information

See `scripts/README.md` for detailed documentation.

Monitor builds: https://build.opensuse.org/package/show/home:GuyFerrari/dbc-file-viewer
