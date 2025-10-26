#!/bin/bash
# macOS Deployment Script for DBC Parser
# This script uses macdeployqt to bundle all Qt dependencies and create a .app bundle

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "DBC Parser - macOS Deployment"
echo "========================================"

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build/Desktop_Qt_6_8_2_clang_64-Release"
DEPLOY_DIR="${PROJECT_ROOT}/deploy/macos"
APP_NAME="DBC Parser"
BUNDLE_NAME="appDBC_Parser.app"
DMG_NAME="DBC_Parser_Installer"
VERSION="1.0.0"

# Find Qt installation
echo "Finding Qt installation..."
if [ -z "$QTDIR" ]; then
    # Try common Qt locations
    QT_PATHS=(
        "$HOME/Qt/6.8.2/macos"
        "$HOME/Qt/6.8.0/macos"
        "/opt/Qt/6.8.2/macos"
        "/usr/local/Qt-6.8.2"
        "/Applications/Qt/6.8.2/macos"
    )
    
    for qt_path in "${QT_PATHS[@]}"; do
        if [ -f "$qt_path/bin/macdeployqt" ]; then
            QTDIR="$qt_path"
            echo -e "${GREEN}✓ Found Qt at: $QTDIR${NC}"
            break
        fi
    done
    
    if [ -z "$QTDIR" ]; then
        echo -e "${RED}✗ Qt installation not found!${NC}"
        echo "Please set QTDIR environment variable or install Qt."
        echo "Example: export QTDIR=$HOME/Qt/6.8.2/macos"
        exit 1
    fi
fi

MACDEPLOYQT="$QTDIR/bin/macdeployqt"

if [ ! -f "$MACDEPLOYQT" ]; then
    echo -e "${RED}✗ macdeployqt not found at: $MACDEPLOYQT${NC}"
    exit 1
fi

# Check if build exists
if [ ! -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}⚠ Build directory not found: $BUILD_DIR${NC}"
    echo "Building project..."
    
    # Create build directory
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Configure with CMake
    cmake "$PROJECT_ROOT" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$QTDIR"
    
    # Build
    cmake --build . --config Release -j$(sysctl -n hw.ncpu)
    
    cd "$PROJECT_ROOT"
fi

# Check if app bundle exists
if [ ! -d "$BUILD_DIR/$BUNDLE_NAME" ]; then
    echo -e "${RED}✗ App bundle not found: $BUILD_DIR/$BUNDLE_NAME${NC}"
    echo "Please build the project first."
    exit 1
fi

echo -e "${GREEN}✓ App bundle found${NC}"

# Clean deployment directory
echo "Cleaning deployment directory..."
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

# Copy app bundle to deployment directory
echo "Copying app bundle..."
cp -R "$BUILD_DIR/$BUNDLE_NAME" "$DEPLOY_DIR/"

# Run macdeployqt
echo "Running macdeployqt..."
echo "This will bundle all Qt dependencies..."

cd "$DEPLOY_DIR"

# Get QML source directory
QML_SOURCE_DIR="$PROJECT_ROOT"

"$MACDEPLOYQT" "$BUNDLE_NAME" \
    -qmldir="$QML_SOURCE_DIR" \
    -verbose=1

# Copy icon to Resources if not already there
if [ -f "$PROJECT_ROOT/deploy-assets/dbctrain.png" ]; then
    echo "Copying application icon..."
    cp "$PROJECT_ROOT/deploy-assets/dbctrain.png" "$BUNDLE_NAME/Contents/Resources/"
fi

# Create .icns file if needed (requires iconutil, part of Xcode)
if command -v iconutil &> /dev/null; then
    if [ -f "$PROJECT_ROOT/deploy-assets/dbctrain.png" ]; then
        echo "Creating .icns file..."
        ICONSET_DIR="$DEPLOY_DIR/dbctrain.iconset"
        mkdir -p "$ICONSET_DIR"
        
        # Generate different icon sizes (requires ImageMagick or sips)
        if command -v sips &> /dev/null; then
            sips -z 16 16     "$PROJECT_ROOT/deploy-assets/dbctrain.png" --out "$ICONSET_DIR/icon_16x16.png"
            sips -z 32 32     "$PROJECT_ROOT/deploy-assets/dbctrain.png" --out "$ICONSET_DIR/icon_16x16@2x.png"
            sips -z 32 32     "$PROJECT_ROOT/deploy-assets/dbctrain.png" --out "$ICONSET_DIR/icon_32x32.png"
            sips -z 64 64     "$PROJECT_ROOT/deploy-assets/dbctrain.png" --out "$ICONSET_DIR/icon_32x32@2x.png"
            sips -z 128 128   "$PROJECT_ROOT/deploy-assets/dbctrain.png" --out "$ICONSET_DIR/icon_128x128.png"
            sips -z 256 256   "$PROJECT_ROOT/deploy-assets/dbctrain.png" --out "$ICONSET_DIR/icon_128x128@2x.png"
            sips -z 256 256   "$PROJECT_ROOT/deploy-assets/dbctrain.png" --out "$ICONSET_DIR/icon_256x256.png"
            sips -z 512 512   "$PROJECT_ROOT/deploy-assets/dbctrain.png" --out "$ICONSET_DIR/icon_256x256@2x.png"
            sips -z 512 512   "$PROJECT_ROOT/deploy-assets/dbctrain.png" --out "$ICONSET_DIR/icon_512x512.png"
            sips -z 1024 1024 "$PROJECT_ROOT/deploy-assets/dbctrain.png" --out "$ICONSET_DIR/icon_512x512@2x.png"
            
            iconutil -c icns "$ICONSET_DIR" -o "$BUNDLE_NAME/Contents/Resources/dbctrain.icns"
            rm -rf "$ICONSET_DIR"
            
            # Update Info.plist to use the icon
            /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile dbctrain.icns" "$BUNDLE_NAME/Contents/Info.plist" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string dbctrain.icns" "$BUNDLE_NAME/Contents/Info.plist"
        fi
    fi
fi

# Copy sample files
echo "Copying sample files..."
mkdir -p "$BUNDLE_NAME/Contents/Resources/samples"
cp "$PROJECT_ROOT/SimpBMS-2.dbc" "$BUNDLE_NAME/Contents/Resources/samples/" 2>/dev/null || true
cp "$PROJECT_ROOT/sample_transmission_config.json" "$BUNDLE_NAME/Contents/Resources/samples/" 2>/dev/null || true
cp "$PROJECT_ROOT/simpbms_transmission_config.json" "$BUNDLE_NAME/Contents/Resources/samples/" 2>/dev/null || true

# Copy documentation
echo "Copying documentation..."
mkdir -p "$BUNDLE_NAME/Contents/Resources/docs"
cp "$PROJECT_ROOT/README.md" "$BUNDLE_NAME/Contents/Resources/" 2>/dev/null || true
cp "$PROJECT_ROOT/DEPLOYMENT.md" "$BUNDLE_NAME/Contents/Resources/docs/" 2>/dev/null || true

# Calculate bundle size
BUNDLE_SIZE=$(du -sh "$BUNDLE_NAME" | cut -f1)

cd "$PROJECT_ROOT"

echo ""
echo "========================================"
echo -e "${GREEN}✓ Deployment complete!${NC}"
echo "========================================"
echo ""
echo "App Bundle: $DEPLOY_DIR/$BUNDLE_NAME"
echo "Size: $BUNDLE_SIZE"
echo ""
echo "To test the app:"
echo "  open \"$DEPLOY_DIR/$BUNDLE_NAME\""
echo ""
echo "To create a DMG installer, run:"
echo "  ./build-installer-macos.sh"
echo ""
