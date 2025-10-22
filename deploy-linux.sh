#!/bin/bash
set -e

# DBC Parser Linux Deployment Script using linuxdeploy
# Creates an AppImage - a portable, self-contained Linux application

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build}"
QT_DIR="${QT_DIR:-/opt/qt/6.8.2/gcc_64}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/deploy/linux}"
APP_NAME="DBC_Parser"
DESKTOP_FILE="$SCRIPT_DIR/deploy-assets/dbc-parser.desktop"
ICON_FILE="$SCRIPT_DIR/deploy-assets/dbc-parser.png"

echo "========================================"
echo "DBC Parser Linux Deployment Script"
echo "========================================"
echo ""

# Check if linuxdeploy is available
LINUXDEPLOY="$SCRIPT_DIR/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_QT_PLUGIN="$SCRIPT_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"

if [ ! -f "$LINUXDEPLOY" ]; then
    echo "Downloading linuxdeploy..."
    wget -q --show-progress \
        https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
        -O "$LINUXDEPLOY"
    chmod +x "$LINUXDEPLOY"
fi

if [ ! -f "$LINUXDEPLOY_QT_PLUGIN" ]; then
    echo "Downloading linuxdeploy-plugin-qt..."
    wget -q --show-progress \
        https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage \
        -O "$LINUXDEPLOY_QT_PLUGIN"
    chmod +x "$LINUXDEPLOY_QT_PLUGIN"
fi

echo "✓ Deployment tools ready"

# Find executable
EXE_PATH=$(find "$BUILD_DIR" -name "appDBC_Parser" -type f -executable | head -n1)
if [ -z "$EXE_PATH" ]; then
    echo "❌ ERROR: Could not find appDBC_Parser executable in $BUILD_DIR"
    echo "Please build the project first"
    exit 1
fi

echo "✓ Found executable: $EXE_PATH"

# Create deployment assets if they don't exist
mkdir -p "$SCRIPT_DIR/deploy-assets"

# Create .desktop file if it doesn't exist
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Creating .desktop file..."
    cat > "$DESKTOP_FILE" << 'EOF'
[Desktop Entry]
Type=Application
Name=DBC Parser
Comment=DBC File Viewer and CAN Message Sender
Exec=appDBC_Parser
Icon=dbc-parser
Categories=Development;Network;
Terminal=false
EOF
    echo "✓ Created $DESKTOP_FILE"
fi

# Create icon if it doesn't exist (placeholder - use your actual icon)
if [ ! -f "$ICON_FILE" ]; then
    echo "⚠️  Warning: No icon found at $ICON_FILE"
    echo "Creating placeholder icon..."
    # Create a simple 256x256 PNG placeholder
    # In production, replace this with your actual app icon
    convert -size 256x256 xc:blue -fill white -pointsize 72 \
        -gravity center -annotate +0+0 'DBC' "$ICON_FILE" 2>/dev/null || {
        echo "⚠️  ImageMagick not found, skipping icon creation"
        echo "Please provide an icon at: $ICON_FILE"
    }
fi

# Set up environment for Qt plugin
export QMAKE="$QT_DIR/bin/qmake"
export PATH="$QT_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$QT_DIR/lib:$LD_LIBRARY_PATH"
export QML_SOURCES_PATHS="$SCRIPT_DIR"

# Clean output directory
echo ""
echo "Preparing output directory: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Create AppDir structure
echo "Building AppDir..."
"$LINUXDEPLOY" \
    --executable="$EXE_PATH" \
    --appdir="$OUTPUT_DIR/AppDir" \
    --desktop-file="$DESKTOP_FILE" \
    $([ -f "$ICON_FILE" ] && echo "--icon-file=$ICON_FILE") \
    --plugin qt \
    --output appimage

if [ $? -eq 0 ]; then
    # Move generated AppImage to output directory
    mv *.AppImage "$OUTPUT_DIR/" 2>/dev/null || true
    
    APP_IMAGE=$(find "$OUTPUT_DIR" -name "*.AppImage" | head -n1)
    if [ -n "$APP_IMAGE" ]; then
        SIZE=$(du -sh "$APP_IMAGE" | cut -f1)
        echo ""
        echo "========================================"
        echo "✓ Deployment completed successfully!"
        echo "========================================"
        echo ""
        echo "AppImage created: $APP_IMAGE"
        echo "Size: $SIZE"
        echo ""
        echo "To run the AppImage:"
        echo "  chmod +x '$APP_IMAGE'"
        echo "  '$APP_IMAGE'"
        echo ""
        echo "To extract and inspect contents:"
        echo "  '$APP_IMAGE' --appimage-extract"
    else
        echo "⚠️  Warning: AppImage may have been created in current directory"
        ls -lh *.AppImage 2>/dev/null || echo "No AppImage found"
    fi
else
    echo "❌ ERROR: linuxdeploy failed"
    exit 1
fi

echo ""
echo "Alternative deployment methods:"
echo "1. Create a .tar.gz archive:"
echo "   tar -czf DBC_Parser_Linux.tar.gz -C '$OUTPUT_DIR/AppDir' ."
echo ""
echo "2. Create a .deb package (requires dpkg-deb):"
echo "   See: https://www.debian.org/doc/debian-policy/"
echo ""
echo "3. Create a Flatpak (requires flatpak-builder):"
echo "   See: https://docs.flatpak.org/en/latest/building.html"
