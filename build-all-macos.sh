#!/bin/bash
# All-in-One macOS Build, Deploy, and Package Script for DBC Parser

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================"
echo "DBC Parser - macOS Complete Build"
echo "========================================"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse command line arguments
BUILD_ONLY=false
DEPLOY_ONLY=false
DMG_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --deploy-only)
            DEPLOY_ONLY=true
            shift
            ;;
        --dmg-only)
            DMG_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--build-only] [--deploy-only] [--dmg-only]"
            exit 1
            ;;
    esac
done

# Step 1: Build
if [ "$DEPLOY_ONLY" = false ] && [ "$DMG_ONLY" = false ]; then
    echo ""
    echo -e "${BLUE}Step 1: Building application...${NC}"
    echo "----------------------------------------"
    
    BUILD_DIR="${PROJECT_ROOT}/build/Desktop_Qt_6_8_2_clang_64-Release"
    
    # Find Qt installation
    if [ -z "$QTDIR" ]; then
        QT_PATHS=(
            "$HOME/Qt/6.8.2/macos"
            "$HOME/Qt/6.8.0/macos"
            "/opt/Qt/6.8.2/macos"
            "/usr/local/Qt-6.8.2"
            "/Applications/Qt/6.8.2/macos"
        )
        
        for qt_path in "${QT_PATHS[@]}"; do
            if [ -f "$qt_path/bin/qmake" ]; then
                QTDIR="$qt_path"
                break
            fi
        done
        
        if [ -z "$QTDIR" ]; then
            echo -e "${RED}✗ Qt installation not found!${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓ Using Qt: $QTDIR${NC}"
    
    # Create and enter build directory
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Configure
    echo "Configuring with CMake..."
    cmake "$PROJECT_ROOT" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$QTDIR"
    
    # Build
    echo "Building..."
    cmake --build . --config Release -j$(sysctl -n hw.ncpu)
    
    cd "$PROJECT_ROOT"
    echo -e "${GREEN}✓ Build complete${NC}"
    
    if [ "$BUILD_ONLY" = true ]; then
        exit 0
    fi
fi

# Step 2: Deploy
if [ "$DMG_ONLY" = false ]; then
    echo ""
    echo -e "${BLUE}Step 2: Deploying application...${NC}"
    echo "----------------------------------------"
    
    ./deploy-macos.sh
    
    if [ "$DEPLOY_ONLY" = true ]; then
        exit 0
    fi
fi

# Step 3: Create DMG
echo ""
echo -e "${BLUE}Step 3: Creating DMG installer...${NC}"
echo "----------------------------------------"

./build-installer-macos.sh

echo ""
echo "========================================"
echo -e "${GREEN}✓ Complete build successful!${NC}"
echo "========================================"
echo ""
echo "The DMG installer is ready at:"
echo "  installer_output/DBC_Parser_Installer_1.0.0.dmg"
echo ""
