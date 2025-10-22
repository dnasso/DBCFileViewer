# OBS (Open Build Service) Repository Setup

This directory contains the configuration files needed to build and distribute DBC File Viewer through the Open Build Service.

## Files Overview

- **dbc-file-viewer.spec** - RPM spec file for openSUSE, Fedora, RHEL, etc.
- **_service** - OBS service file to automatically fetch sources from GitHub
- **debian.control** - Debian package control file
- **debian.rules** - Debian package build rules
- **debian.dbc-file-viewer.desktop** - Desktop entry file for Debian packages

## Setting Up OBS Repository

### 1. Create an Account
Visit [https://build.opensuse.org/](https://build.opensuse.org/) and create an account.

### 2. Create a New Project
1. Go to "Home Project" → "Create Home Project" if you don't have one
2. Create a subproject for your application:
   - Click "Create Subproject"
   - Name it something like `home:yourusername:dbc-file-viewer`
   - Add a description

### 3. Create a Package
1. In your project, click "Create Package"
2. Name it `dbc-file-viewer`
3. Add a description

### 4. Upload Files
Upload these files to your OBS package:
- `dbc-file-viewer.spec`
- `_service`
- `debian.control`
- `debian.rules`
- `debian.dbc-file-viewer.desktop`

### 5. Configure Build Targets
Add repositories for the distributions you want to support:
1. Go to your project's "Repositories" tab
2. Click "Add from a Distribution"
3. Select distributions (recommended):
   - openSUSE Tumbleweed
   - openSUSE Leap 15.5
   - Fedora 39
   - Fedora 40
   - Debian 12
   - Ubuntu 23.10
   - Ubuntu 24.04

### 6. Trigger Build
1. Go to your package
2. Click "Trigger Services" to fetch the source code
3. Wait for builds to complete

### 7. Enable Publishing
1. Go to project settings
2. Enable "Publish" flag
3. The built packages will be available at:
   ```
   https://download.opensuse.org/repositories/home:/yourusername:/dbc-file-viewer/
   ```

## Using OBS Command Line

You can also use the `osc` command-line tool:

```bash
# Install osc
pip install osc

# Configure osc
osc -A https://api.opensuse.org

# Checkout your project
osc co home:yourusername:dbc-file-viewer

# Add files
cd home:yourusername:dbc-file-viewer/dbc-file-viewer
cp /path/to/obs/*.{spec,control,rules,desktop} .
cp /path/to/obs/_service .

# Add and commit
osc add *
osc commit -m "Initial package"
```

## Installation Instructions for Users

Once published, users can install the package:

### openSUSE/SLES
```bash
sudo zypper ar https://download.opensuse.org/repositories/home:/yourusername:/dbc-file-viewer/openSUSE_Tumbleweed/ dbc-file-viewer
sudo zypper ref
sudo zypper in dbc-file-viewer
```

### Fedora
```bash
sudo dnf config-manager --add-repo https://download.opensuse.org/repositories/home:/yourusername:/dbc-file-viewer/Fedora_40/
sudo dnf install dbc-file-viewer
```

### Debian/Ubuntu
```bash
echo 'deb http://download.opensuse.org/repositories/home:/yourusername:/dbc-file-viewer/xUbuntu_24.04/ /' | sudo tee /etc/apt/sources.list.d/dbc-file-viewer.list
curl -fsSL https://download.opensuse.org/repositories/home:/yourusername:/dbc-file-viewer/xUbuntu_24.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/dbc-file-viewer.gpg > /dev/null
sudo apt update
sudo apt install dbc-file-viewer
```

## Maintenance

### Updating the Package
The `_service` file is configured to automatically fetch the latest code from the `main-deployment` branch. To trigger an update:
1. Push changes to GitHub
2. Go to OBS package page
3. Click "Trigger Services"
4. Packages will rebuild automatically

### Changing Version
Update the version in `dbc-file-viewer.spec` and commit the change.

## Troubleshooting

### Build Failures
- Check the build logs in OBS web interface
- Verify all Qt6 dependencies are available for your target distribution
- Some older distributions may not have Qt6 - consider Qt5 for those

### Missing Dependencies
If Qt6 packages aren't available, you can:
1. Adjust build requirements in the spec file
2. Exclude problematic distributions from build targets
3. Build Qt6 yourself (advanced)

## Additional Resources

- [OBS User Guide](https://openbuildservice.org/help/manuals/obs-user-guide/)
- [RPM Packaging Guide](https://rpm-packaging-guide.github.io/)
- [Debian Packaging Tutorial](https://www.debian.org/doc/manuals/maint-guide/)
