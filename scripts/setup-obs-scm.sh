#!/bin/bash
# Setup OBS SCM/CI Monitoring
# This script configures OBS to automatically monitor your GitHub repository

set -e

# Configuration
OBS_PROJECT="home:GuyFerrari"
OBS_PACKAGE="dbc-file-viewer"
GITHUB_REPO="https://github.com/dnasso/DBCFileViewer.git"
BRANCH="obs-docker-ghactions"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

print_info "Setting up OBS SCM monitoring for $GITHUB_REPO"
print_info "Branch: $BRANCH"
print_info "OBS Package: $OBS_PROJECT/$OBS_PACKAGE"

# Check if osc is installed
if ! command -v osc &> /dev/null; then
    print_error "osc is not installed"
    print_info "Run: sudo apt-get install osc  OR  pip install osc"
    exit 1
fi

# Check if _service file exists
if [ ! -f "obs/_service" ]; then
    print_error "obs/_service file not found!"
    exit 1
fi

print_success "Found _service file"

# Create work directory
WORK_DIR="$REPO_ROOT/build-obs/setup-scm"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Checkout OBS package
print_info "Checking out OBS package..."
osc checkout "$OBS_PROJECT/$OBS_PACKAGE" || {
    print_error "Failed to checkout OBS package"
    exit 1
}

cd "$OBS_PROJECT/$OBS_PACKAGE"

# Remove old source tarballs and generated files
print_info "Removing old source tarballs and generated files..."
rm -f *.tar.gz *.tar.xz *.tar.bz2 *.obscpio 2>/dev/null || true
print_success "Old source files removed"

# Copy _service file
print_info "Copying _service file..."
cp "$REPO_ROOT/obs/_service" .

# Copy other OBS files that should be in the repo
print_info "Copying OBS build files..."
cp "$REPO_ROOT/obs/dbc-file-viewer.spec" . 2>/dev/null || print_warning "No .spec file found"
cp "$REPO_ROOT/obs/dbc-file-viewer.dsc" . 2>/dev/null || print_warning "No .dsc file found"

# Copy debian control files
for file in "$REPO_ROOT"/obs/debian.*; do
    if [ -f "$file" ]; then
        cp "$file" .
    fi
done

# Add/remove files (this will mark old tarballs for deletion)
print_info "Adding files to OBS..."
osc addremove

# Show status
print_info "OBS status:"
osc status

echo ""
print_warning "IMPORTANT: SCM/CI Configuration Steps"
echo ""
echo "1. The _service file has been updated to monitor branch: $BRANCH"
echo "2. After committing, you need to enable SCM/CI in the OBS web interface:"
echo ""
echo "   a. Go to: https://build.opensuse.org/package/show/$OBS_PROJECT/$OBS_PACKAGE"
echo "   b. Click 'Source Files' tab"
echo "   c. Click 'Trigger Services' to run the service initially"
echo "   d. Go to 'Repositories' tab"
echo "   e. Enable 'Automatically rebuild on source changes'"
echo ""
echo "3. Optional: Set up GitHub webhook for instant updates:"
echo "   a. In OBS, go to your package settings"
echo "   b. Look for 'Token' or 'Webhook' settings"
echo "   c. Add webhook URL to your GitHub repository settings"
echo ""

read -p "$(echo -e "${YELLOW}Commit _service and build files to OBS? [y/N]${NC} ")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Commit cancelled"
    print_info "You can manually commit from: $(pwd)"
    exit 0
fi

# Commit
COMMIT_MSG="Configure SCM monitoring for $BRANCH branch

- Monitor branch: $BRANCH
- Repository: $GITHUB_REPO
- Enable automatic version updates from git tags
- Generate changelogs automatically

Updated _service file to use obs_scm with git describe versioning.
"

print_info "Committing to OBS..."
osc commit -m "$COMMIT_MSG"

print_success "SCM monitoring configured!"
print_info ""
print_info "Next steps:"
print_info "1. Go to: https://build.opensuse.org/package/show/$OBS_PROJECT/$OBS_PACKAGE"
print_info "2. Click 'Trigger Services' to fetch from GitHub"
print_info "3. Enable automatic rebuilds in repository settings"
print_info ""
print_info "The package will now automatically update when you push to $BRANCH"

# Cleanup
cd "$REPO_ROOT"
rm -rf "$WORK_DIR"
