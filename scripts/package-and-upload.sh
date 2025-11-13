#!/bin/bash
# Package and Upload Script for OBS (Open Build Service)
# This script creates source tarballs and uploads them to OBS

set -e

# Configuration
PACKAGE_NAME="dbc-file-viewer"
VERSION="1.0.2"
OBS_PROJECT="home:GuyFerrari"
OBS_PACKAGE="dbc-file-viewer"
BRANCH="obs-docker-ghactions"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

print_info "Repository root: $REPO_ROOT"
print_info "Package: $PACKAGE_NAME version $VERSION"

# Check if osc is installed
if ! command -v osc &> /dev/null; then
    print_error "osc (Open Build Service command line tool) is not installed"
    print_info "Run: sudo apt-get install osc  OR  pip install osc"
    exit 1
fi

# Create build directory
BUILD_DIR="$REPO_ROOT/build-obs"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

print_info "Creating source tarball..."

# Create the source tarball
TARBALL_NAME="${PACKAGE_NAME}-${VERSION}.tar.gz"
TARBALL_PATH="$BUILD_DIR/$TARBALL_NAME"

# Create tarball excluding build artifacts and development files
tar -czf "$TARBALL_PATH" \
    --exclude='.git' \
    --exclude='build' \
    --exclude='build_docker' \
    --exclude='build-obs' \
    --exclude='build-dir' \
    --exclude='flatpak-build' \
    --exclude='flatpak-repo' \
    --exclude='installer_output' \
    --exclude='logs' \
    --exclude='artifacts' \
    --exclude='Generated' \
    --exclude='*.o' \
    --exclude='*.so' \
    --exclude='*.a' \
    --exclude='CMakeCache.txt' \
    --exclude='CMakeFiles' \
    --exclude='*.user' \
    --exclude='*.user.*' \
    --exclude='*.autosave' \
    --exclude='*.qmlc' \
    --exclude='*.jsc' \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    --exclude='.vscode' \
    --exclude='.idea' \
    --exclude='*.swp' \
    --exclude='*.swo' \
    --exclude='*~' \
    --transform "s,^./,$PACKAGE_NAME-$VERSION/," \
    -C "$REPO_ROOT" \
    .

print_success "Created tarball: $TARBALL_PATH"
print_info "Tarball size: $(du -h "$TARBALL_PATH" | cut -f1)"

# Copy OBS build files to build directory
print_info "Copying OBS build files..."
cp "$REPO_ROOT/obs/dbc-file-viewer.spec" "$BUILD_DIR/"
cp "$REPO_ROOT/obs/dbc-file-viewer.dsc" "$BUILD_DIR/"
cp "$REPO_ROOT/obs/debian."* "$BUILD_DIR/" 2>/dev/null || true

# Create Debian orig tarball (symlink or copy)
DEBIAN_ORIG_TARBALL="${PACKAGE_NAME}_${VERSION}.orig.tar.gz"
ln -sf "$TARBALL_NAME" "$BUILD_DIR/$DEBIAN_ORIG_TARBALL" || \
    cp "$TARBALL_PATH" "$BUILD_DIR/$DEBIAN_ORIG_TARBALL"

# Create Debian debian tarball
print_info "Creating Debian debian.tar.xz..."
DEBIAN_TARBALL="${PACKAGE_NAME}_${VERSION}-1.debian.tar.xz"
(
    cd "$BUILD_DIR"
    mkdir -p debian
    
    # Copy debian control files
    for file in "$REPO_ROOT"/obs/debian.*; do
        if [ -f "$file" ]; then
            basename_file=$(basename "$file")
            # Remove 'debian.' prefix
            target_name="${basename_file#debian.}"
            cp "$file" "debian/$target_name"
        fi
    done
    
    # Create the debian tarball
    tar -cJf "$DEBIAN_TARBALL" debian
    rm -rf debian
)

print_success "Created Debian tarball: $BUILD_DIR/$DEBIAN_TARBALL"

# List files to be uploaded
print_info "Files to upload:"
ls -lh "$BUILD_DIR"/*.{tar.gz,tar.xz,spec,dsc} 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'

# Ask for confirmation
echo ""
read -p "$(echo -e "${YELLOW}Do you want to upload these files to OBS $OBS_PROJECT/$OBS_PACKAGE? [y/N]${NC} ")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Upload cancelled by user"
    print_info "Files are available in: $BUILD_DIR"
    exit 0
fi

# Check out the OBS package
print_info "Checking out OBS package..."
OBS_WORK_DIR="$BUILD_DIR/obs-checkout"
mkdir -p "$OBS_WORK_DIR"
cd "$OBS_WORK_DIR"

osc checkout "$OBS_PROJECT/$OBS_PACKAGE" || {
    print_error "Failed to checkout OBS package"
    print_info "Make sure you have access to $OBS_PROJECT/$OBS_PACKAGE"
    exit 1
}

cd "$OBS_PROJECT/$OBS_PACKAGE"

# Remove old source tarballs and generated files
print_info "Removing old source tarballs and generated files..."
rm -f *.tar.gz *.tar.xz *.tar.bz2 *.obscpio 2>/dev/null || true
print_success "Old source files removed"

# Copy new files
print_info "Copying new files..."
cp "$BUILD_DIR"/*.tar.gz . 2>/dev/null || true
cp "$BUILD_DIR"/*.tar.xz . 2>/dev/null || true
cp "$BUILD_DIR"/*.spec . 2>/dev/null || true
cp "$BUILD_DIR"/*.dsc . 2>/dev/null || true

# Add new files to OBS
print_info "Adding files to OBS..."
osc addremove

# Show status
print_info "OBS status:"
osc status

# Ask for commit confirmation
echo ""
read -p "$(echo -e "${YELLOW}Commit and upload to OBS? [y/N]${NC} ")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Commit cancelled by user"
    print_info "You can manually commit from: $(pwd)"
    exit 0
fi

# Commit and upload
COMMIT_MESSAGE="Update to version $VERSION from $BRANCH branch

Automated upload from package-and-upload.sh script.
Branch: $(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo 'unknown')
Commit: $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo 'unknown')
"

print_info "Committing to OBS..."
osc commit -m "$COMMIT_MESSAGE"

print_success "Successfully uploaded to OBS!"
print_info "Monitor build status at: https://build.opensuse.org/package/show/$OBS_PROJECT/$OBS_PACKAGE"

# Clean up
print_info "Cleaning up temporary files..."
rm -rf "$OBS_WORK_DIR"

print_success "Done! Build artifacts remain in: $BUILD_DIR"
