#!/bin/bash
# Build and install Flatpak for DBC Parser
set -e

MANIFEST="com.qtdevs.DBCParser.yml"
BUILD_DIR="flatpak-build"
REPO_DIR="flatpak-repo"
APP_ID="com.qtdevs.DBCParser"

echo "========================================"
echo "DBC Parser Flatpak Build Script"
echo "========================================"
echo ""

# Check if flatpak-builder is installed
if ! command -v flatpak-builder &> /dev/null; then
    echo "❌ ERROR: flatpak-builder not found"
    echo ""
    echo "Install with:"
    echo "  Ubuntu/Debian: sudo apt install flatpak flatpak-builder"
    echo "  Fedora: sudo dnf install flatpak flatpak-builder"
    echo "  Arch: sudo pacman -S flatpak flatpak-builder"
    exit 1
fi

echo "✓ flatpak-builder found"

# Check if Flathub remote is configured
if ! flatpak remote-list | grep -q flathub; then
    echo "Adding Flathub remote..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

echo "✓ Flathub remote configured"

# Check if KDE runtime is installed
echo ""
echo "Checking for KDE runtime..."
if ! flatpak list --runtime | grep -q "org.kde.Platform.*6.8"; then
    echo "Installing KDE Platform 6.8..."
    flatpak install -y flathub org.kde.Platform//6.8 org.kde.Sdk//6.8
else
    echo "✓ KDE Platform 6.8 already installed"
fi

# Create deploy-assets if needed
mkdir -p deploy-assets

# Create .desktop file if it doesn't exist
if [ ! -f "deploy-assets/dbc-parser.desktop" ]; then
    echo "Creating desktop file..."
    cat > deploy-assets/dbc-parser.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=DBC Parser
GenericName=CAN Database File Viewer
Comment=View and parse DBC files for CAN bus communication
Exec=appDBC_Parser
Icon=com.qtdevs.DBCParser
Categories=Development;Network;Engineering;
Terminal=false
Keywords=CAN;DBC;Automotive;Bus;
EOF
fi

# Create AppData/metainfo file if it doesn't exist
if [ ! -f "deploy-assets/com.qtdevs.DBCParser.appdata.xml" ]; then
    echo "Creating AppData file..."
    cat > deploy-assets/com.qtdevs.DBCParser.appdata.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>com.qtdevs.DBCParser</id>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>MIT</project_license>
  <name>DBC Parser</name>
  <summary>View and parse DBC files for CAN bus communication</summary>
  <description>
    <p>
      DBC Parser is a graphical application for viewing, editing, and transmitting
      CAN bus messages using DBC (CAN Database) files. It features a modern Qt-based
      interface for working with automotive communication protocols.
    </p>
    <p>Features:</p>
    <ul>
      <li>Parse and view DBC files</li>
      <li>Send CAN messages over TCP</li>
      <li>Visual signal editor</li>
      <li>Real-time message monitoring</li>
    </ul>
  </description>
  <url type="homepage">https://github.com/dnasso/DBCFileViewer</url>
  <url type="bugtracker">https://github.com/dnasso/DBCFileViewer/issues</url>
  <screenshots>
    <screenshot type="default">
      <caption>Main window</caption>
    </screenshot>
  </screenshots>
  <releases>
    <release version="1.0.0" date="2025-10-21">
      <description>
        <p>Initial release</p>
      </description>
    </release>
  </releases>
  <content_rating type="oars-1.1" />
</component>
EOF
fi

# Build the Flatpak
echo ""
echo "Building Flatpak..."
flatpak-builder --force-clean "$BUILD_DIR" "$MANIFEST"

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "✓ Flatpak build completed!"
    echo "========================================"
    echo ""
    echo "To install locally:"
    echo "  flatpak-builder --user --install --force-clean $BUILD_DIR $MANIFEST"
    echo ""
    echo "To run:"
    echo "  flatpak run $APP_ID"
    echo ""
    echo "To create a bundle for distribution:"
    echo "  flatpak-builder --repo=$REPO_DIR --force-clean $BUILD_DIR $MANIFEST"
    echo "  flatpak build-bundle $REPO_DIR dbc-parser.flatpak $APP_ID"
    echo ""
    
    # Ask if user wants to install
    read -p "Install locally now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        flatpak-builder --user --install --force-clean "$BUILD_DIR" "$MANIFEST"
        echo ""
        echo "✓ Installed! Run with: flatpak run $APP_ID"
    fi
else
    echo ""
    echo "❌ ERROR: Flatpak build failed"
    exit 1
fi
