# OBS Packaging Scripts

Scripts for packaging and uploading to Open Build Service (OBS).

## Scripts Overview

### 1. `package-and-upload.sh` / `package-and-upload.ps1`
**Purpose:** Creates source tarballs and uploads them to OBS manually.

**When to use:** 
- Quick manual uploads
- Testing before enabling automatic builds
- When you don't want automatic monitoring

**Usage (Windows):**
```powershell
.\scripts\package-and-upload.ps1
```

**Usage (Linux/WSL):**
```bash
./scripts/package-and-upload.sh
```

**What it does:**
1. Creates a source tarball from your current code
2. Creates Debian-format tarballs
3. Copies OBS build files (.spec, .dsc)
4. Uploads everything to your OBS package
5. Triggers a build on OBS

---

### 2. `setup-obs-scm.sh` / `setup-obs-scm.ps1`
**Purpose:** Configures OBS to automatically monitor your GitHub repository.

**When to use:**
- First-time setup of automatic builds
- When switching branches to monitor
- When you want OBS to rebuild on every git push

**Usage (Windows):**
```powershell
.\scripts\setup-obs-scm.ps1
```

**Usage (Linux/WSL):**
```bash
./scripts/setup-obs-scm.sh
```

**What it does:**
1. Uploads the `_service` file to OBS
2. Configures OBS to monitor the `main-deployment` branch
3. Sets up automatic version numbering from git tags
4. Enables changelog generation

**After running:** You need to manually enable SCM/CI in the OBS web interface (see below).

---

## Current Configuration

- **OBS Project:** `home:GuyFerrari`
- **Package Name:** `dbc-file-viewer`
- **Monitored Branch:** `obs-docker-ghactions`
- **GitHub Repository:** `https://github.com/dnasso/DBCFileViewer.git`
- **Version:** `1.0.2`

---

## Setup Instructions

### Prerequisites

1. **Install OBS command-line tool (osc):**
   ```bash
   # In WSL/Linux:
   sudo apt-get install osc
   # OR
   pip install osc
   ```

2. **Configure osc credentials:**
   ```bash
   osc
   # Follow prompts to enter your OBS username and password
   # Credentials are stored in ~/.config/osc/oscrc
   ```

### Option A: Manual Uploads (Recommended for testing)

1. Make your code changes
2. Commit to git
3. Run the packaging script:
   ```powershell
   .\scripts\package-and-upload.ps1
   ```
4. Confirm the upload when prompted
5. Monitor build at: https://build.opensuse.org/package/show/home:GuyFerrari/dbc-file-viewer

### Option B: Automatic SCM Monitoring (Production)

1. **Initial setup:**
   ```powershell
   .\scripts\setup-obs-scm.ps1
   ```

2. **Enable SCM/CI in OBS web interface:**
   - Go to: https://build.opensuse.org/package/show/home:GuyFerrari/dbc-file-viewer
   - Click **"Source Files"** tab
   - Click **"Trigger Services"** button (this fetches from GitHub)
   - Wait for services to complete
   - Go to **"Repositories"** tab
   - Enable **"Automatically rebuild on source changes"** for each repository

3. **Optional: Set up GitHub webhook for instant builds:**
   - In OBS package page, look for webhook/token settings
   - Copy the webhook URL
   - In GitHub repo settings > Webhooks > Add webhook
   - Paste the OBS webhook URL
   - Set content type to `application/json`
   - Select "Just the push event"

4. **Test it:**
   - Push a commit to `main-deployment` branch
   - OBS should automatically fetch and rebuild within minutes

---

## OBS Build Files (in `obs/` directory)

These files are required for OBS to build your package:

- **`_service`** - SCM/CI configuration (monitors GitHub)
- **`dbc-file-viewer.spec`** - RPM package specification (for openSUSE, Fedora, etc.)
- **`dbc-file-viewer.dsc`** - Debian source control file (for Debian, Ubuntu)
- **`debian.*`** - Debian control files (copyright, changelog, rules, etc.)

### Updating Build Files

When you need to change package metadata, dependencies, or build instructions:

1. Edit files in `obs/` directory
2. Run `package-and-upload.ps1` to upload changes
3. OR if SCM is enabled, the `_service` file will be auto-updated, but you may need to manually upload .spec/.dsc changes

---

## Version Management

### Current Behavior
- **Version format:** `1.0.2+git.<commits_since_tag>.<short_hash>`
- Example: `1.0.2+git.5.a1b2c3d`

### Updating Version

**Option 1: Create a git tag (recommended)**
```bash
git tag -a v1.0.2 -m "Release 1.0.2"
git push origin v1.0.2
```
OBS will automatically use this version.

**Option 2: Edit version manually**
1. Edit `obs/dbc-file-viewer.spec`:
   ```spec
   Version:        1.0.2
   ```
2. Edit `obs/_service` if using SCM:
   ```xml
   <param name="versionformat">1.0.2</param>
   ```
3. Upload changes with `package-and-upload.ps1`

---

## Troubleshooting

### "osc: command not found"
Install osc in WSL:
```bash
sudo apt-get update
sudo apt-get install osc
```

### "Authentication failed"
Configure osc credentials:
```bash
osc
# Enter your OBS username and password when prompted
```

### "Failed to checkout OBS package"
Make sure the package exists:
```bash
osc list home:GuyFerrari
```
If not, create it on the OBS web interface first.

### Build fails on OBS
1. Check build logs on OBS web interface
2. Common issues:
   - Missing build dependencies in .spec file
   - CMake configuration errors
   - Qt6 components not found

### SCM/CI not triggering
1. Verify `_service` file was uploaded
2. Click "Trigger Services" manually in OBS web interface
3. Check that "Source Files" tab shows fetched files from GitHub
4. Ensure webhook is configured correctly (if using webhooks)

---

## Monitoring Builds

**OBS Package Page:**
https://build.opensuse.org/package/show/home:GuyFerrari/dbc-file-viewer

**Build Results:**
https://build.opensuse.org/package/show/home:GuyFerrari/dbc-file-viewer#buildresults

**Download Built Packages:**
https://build.opensuse.org/package/binaries/home:GuyFerrari/dbc-file-viewer

---

## Supported Distributions

The package builds for:
- openSUSE Tumbleweed
- openSUSE Leap
- Fedora
- Debian Testing
- Ubuntu (various versions)
- And more (configured in OBS web interface)

---

## Additional Resources

- **OBS Documentation:** https://openbuildservice.org/help/manuals/obs-user-guide/
- **OBS SCM/CI Guide:** https://openbuildservice.org/help/manuals/obs-user-guide/cha.obs.source_service.html
- **Package on OBS:** https://build.opensuse.org/package/show/home:GuyFerrari/dbc-file-viewer
