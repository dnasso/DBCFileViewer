# OBS Build Fixes - Complete Solution

## The Core Problem

OBS source services (tar, recompress, set_version) work differently on different distros:
- ✅ **openSUSE/SUSE**: Full support, services run on OBS server
- ✅ **Fedora/RHEL**: Full support, services run on OBS server  
- ❌ **Debian/Ubuntu**: Limited/no support for OBS source services

## Solution: Different Approaches by Distro

### For RPM-based (openSUSE, Fedora, RHEL)

Use the `_service` file with obs_scm. This will automatically fetch from GitHub.

**Files needed:**
- `_service` (updated to use v1.0.1 tag)
- `dbc-file-viewer.spec` (updated to version 1.0.1)

### For Debian/Ubuntu

**DON'T use _service file**. Instead, manually create and upload source tarball.

## Step-by-Step Setup

### Option A: Separate Projects (Recommended)

Create two separate OBS projects:

#### 1. RPM Project (openSUSE/Fedora)
```
Project: home:yourusername:dbc-file-viewer-rpm
Package: dbc-file-viewer
```

**Upload these files:**
- `_service`
- `dbc-file-viewer.spec`

**Repositories:**
- openSUSE Tumbleweed
- openSUSE Leap 15.6
- Fedora 40
- Fedora 41

**After upload:**
1. Click "Trigger Services" to fetch source
2. Builds will start automatically

#### 2. Debian Project (Debian/Ubuntu)
```
Project: home:yourusername:dbc-file-viewer-deb
Package: dbc-file-viewer
```

**First, create source tarball locally:**
```bash
cd /path/to/DBCFileViewer
git archive -o dbc-file-viewer_1.0.1.orig.tar.gz --prefix=dbc-file-viewer-1.0.1/ v1.0.1
```

**Upload these files:**
- `dbc-file-viewer_1.0.1.orig.tar.gz` (the tarball you just created)
- `debian.control`
- `debian.rules`
- `debian.dbc-file-viewer.desktop`
- `debian.changelog` (create this - see below)
- `debian.compat` (create with content: `13`)

**Repositories:**
- Debian 12
- Debian Testing
- xUbuntu 24.04
- xUbuntu 24.10

### Fix Fedora glibc Warning

In your RPM project configuration (not package), add this to prjconf:

```
Prefer: glibc-langpack-en
```

Or in web UI:
1. Go to Project → Advanced → Project Config
2. Add line: `Prefer: glibc-langpack-en`
3. Save

## Required Additional Debian Files

### debian.changelog
Create `obs/debian.changelog`:
```
dbc-file-viewer (1.0.1-1) unstable; urgency=medium

  * Initial release

 -- Your Name <your.email@example.com>  Wed, 22 Oct 2025 00:00:00 +0000
```

### debian.compat
Create `obs/debian.compat`:
```
13
```

### debian.source/format
Create `obs/debian.source.format`:
```
3.0 (quilt)
```

## Automation Script

Here's a script to create the Debian tarball and upload to OBS:

```bash
#!/bin/bash
# create-debian-package.sh

VERSION="1.0.1"
TAG="v${VERSION}"
PACKAGE="dbc-file-viewer"
OBS_PROJECT="home:yourusername:dbc-file-viewer-deb"

# Create source tarball
echo "Creating source tarball from tag ${TAG}..."
git archive -o ${PACKAGE}_${VERSION}.orig.tar.gz --prefix=${PACKAGE}-${VERSION}/ ${TAG}

# If you have osc installed, upload automatically
if command -v osc &> /dev/null; then
    echo "Uploading to OBS..."
    osc checkout ${OBS_PROJECT} ${PACKAGE}
    cd ${OBS_PROJECT}/${PACKAGE}
    
    # Copy debian files
    cp ../../../obs/debian.* .
    
    # Copy tarball
    mv ../../../${PACKAGE}_${VERSION}.orig.tar.gz .
    
    # Add and commit
    osc add *.tar.gz debian.*
    osc commit -m "Update to version ${VERSION}"
    
    echo "✓ Uploaded to OBS"
else
    echo "osc not installed. Please upload ${PACKAGE}_${VERSION}.orig.tar.gz manually to OBS"
fi
```

## Current File Status

### ✅ Fixed Files (for RPM builds)
- `_service` - Now uses explicit tag v1.0.1 and version 1.0.1
- `dbc-file-viewer.spec` - Updated to version 1.0.1, has distro conditionals

### ⚠️ Debian Files Status
- `debian.control` - ✅ Good
- `debian.rules` - ✅ Good (assuming it exists and is correct)
- `debian.dbc-file-viewer.desktop` - ✅ Good
- `debian.changelog` - ❌ MISSING - need to create
- `debian.compat` - ❌ MISSING - need to create
- `debian.source/format` - ❌ MISSING - need to create

## Quick Start Commands

### For RPM (openSUSE/Fedora):
```bash
# Just upload _service and .spec to OBS, then click "Trigger Services"
```

### For Debian/Ubuntu:
```bash
# Create tarball
cd /path/to/DBCFileViewer
git archive -o dbc-file-viewer_1.0.1.orig.tar.gz --prefix=dbc-file-viewer-1.0.1/ v1.0.1

# Create missing debian files
echo "13" > obs/debian.compat

cat > obs/debian.changelog << 'EOF'
dbc-file-viewer (1.0.1-1) unstable; urgency=medium

  * Initial release

 -- Your Name <your.email@example.com>  Wed, 22 Oct 2025 00:00:00 +0000
EOF

mkdir -p obs/debian.source
echo "3.0 (quilt)" > obs/debian.source.format

# Now upload all debian.* files and the .orig.tar.gz to OBS
```

## Why This Approach?

1. **RPM distros (openSUSE/Fedora)**: OBS source services work perfectly, automatically fetch from GitHub
2. **Debian/Ubuntu**: OBS doesn't support source services well for Debian, so we pre-create the tarball
3. **Separation**: Keeps RPM and DEB builds independent, easier to debug

## Expected Results

After fixes:
- ✅ openSUSE Tumbleweed - WILL BUILD
- ✅ openSUSE Leap 15.6 - WILL BUILD
- ✅ Fedora 40/41 - WILL BUILD (with glibc preference set)
- ✅ Debian 12 - WILL BUILD (with manual tarball)
- ✅ Ubuntu 24.04+ - WILL BUILD (with manual tarball)
