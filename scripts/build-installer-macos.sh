#!/bin/bash
# macOS DMG Installer Creator for DBC Parser
# This script creates a .dmg installer with a custom background and layout

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "DBC Parser - macOS DMG Installer Creator"
echo "========================================"

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${PROJECT_ROOT}/deploy/macos"
OUTPUT_DIR="${PROJECT_ROOT}/installer_output"
APP_NAME="DBC Parser"
BUNDLE_NAME="appDBC_Parser.app"
DMG_NAME="DBC_Parser_Installer"
VERSION="1.0.0"
DMG_FINAL="${OUTPUT_DIR}/${DMG_NAME}_${VERSION}.dmg"
DMG_TEMP="tmp_${DMG_NAME}.dmg"
VOLUME_NAME="DBC Parser ${VERSION}"

# Check if app bundle exists
if [ ! -d "$DEPLOY_DIR/$BUNDLE_NAME" ]; then
    echo -e "${RED}✗ App bundle not found: $DEPLOY_DIR/$BUNDLE_NAME${NC}"
    echo "Please run ./deploy-macos.sh first."
    exit 1
fi

echo -e "${GREEN}✓ App bundle found${NC}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Clean up any existing temp files
echo "Cleaning up old files..."
rm -f "$DMG_TEMP"
rm -f "$DMG_FINAL"

# Calculate size needed for DMG (add 50MB buffer)
echo "Calculating DMG size..."
BUNDLE_SIZE_KB=$(du -sk "$DEPLOY_DIR/$BUNDLE_NAME" | cut -f1)
DMG_SIZE_KB=$((BUNDLE_SIZE_KB + 51200))  # Add 50MB buffer
DMG_SIZE_MB=$((DMG_SIZE_KB / 1024))

echo "Bundle size: $((BUNDLE_SIZE_KB / 1024)) MB"
echo "DMG size: ${DMG_SIZE_MB} MB"

# Create temporary DMG
echo "Creating temporary DMG..."
hdiutil create -srcfolder "$DEPLOY_DIR/$BUNDLE_NAME" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${DMG_SIZE_MB}m \
    "$DMG_TEMP"

echo -e "${GREEN}✓ Temporary DMG created${NC}"

# Mount the temporary DMG
echo "Mounting temporary DMG..."
MOUNT_DIR="/Volumes/$VOLUME_NAME"
hdiutil attach "$DMG_TEMP" -readwrite -noverify -noautoopen

# Wait for mount
sleep 2

# Create Applications symlink
echo "Creating Applications symlink..."
ln -s /Applications "$MOUNT_DIR/Applications"

# Create a background folder if we have a background image
if [ -f "$PROJECT_ROOT/deploy-assets/dmg-background.png" ]; then
    echo "Adding background image..."
    mkdir -p "$MOUNT_DIR/.background"
    cp "$PROJECT_ROOT/deploy-assets/dmg-background.png" "$MOUNT_DIR/.background/background.png"
fi

# Set custom icon if available
if [ -f "$DEPLOY_DIR/$BUNDLE_NAME/Contents/Resources/dbctrain.icns" ]; then
    echo "Setting custom volume icon..."
    cp "$DEPLOY_DIR/$BUNDLE_NAME/Contents/Resources/dbctrain.icns" "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns"
fi

# Create a nice layout using AppleScript
echo "Setting up DMG layout..."
osascript <<EOD
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 440}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        try
            set background picture of viewOptions to file ".background:background.png"
        end try
        set position of item "$BUNDLE_NAME" of container window to {120, 120}
        set position of item "Applications" of container window to {400, 120}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOD

# Fix permissions
chmod -Rf go-w "$MOUNT_DIR" 2>/dev/null || true

# Sync to ensure everything is written
sync
sync

# Unmount
echo "Unmounting DMG..."
hdiutil detach "$MOUNT_DIR"

# Convert to compressed read-only DMG
echo "Converting to compressed DMG..."
hdiutil convert "$DMG_TEMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_FINAL"

# Clean up temp DMG
rm -f "$DMG_TEMP"

# Calculate final size
FINAL_SIZE=$(du -h "$DMG_FINAL" | cut -f1)

echo ""
echo "========================================"
echo -e "${GREEN}✓ DMG installer created successfully!${NC}"
echo "========================================"
echo ""
echo "Installer: $DMG_FINAL"
echo "Size: $FINAL_SIZE"
echo ""
echo "To test the installer:"
echo "  open \"$DMG_FINAL\""
echo ""
echo "To distribute:"
echo "  1. Test the installer on a clean macOS system"
echo "  2. Code sign the app and DMG (see CODE_SIGNING.md)"
echo "  3. Notarize with Apple (required for macOS 10.15+)"
echo ""
