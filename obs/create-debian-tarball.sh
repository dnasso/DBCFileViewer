#!/bin/bash
# Script to create Debian source tarball for OBS
# Run this whenever you tag a new version

set -e

# Configuration
VERSION="1.0.1"
TAG="v${VERSION}"
PACKAGE="dbc-file-viewer"
TARBALL="${PACKAGE}_${VERSION}.orig.tar.gz"

echo "Creating Debian source tarball for version ${VERSION}..."

# Check if tag exists
if ! git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Error: Tag $TAG does not exist"
    echo "Available tags:"
    git tag -l
    exit 1
fi

# Create tarball from git tag
echo "Creating tarball from tag ${TAG}..."
git archive -o "${TARBALL}" --prefix="${PACKAGE}-${VERSION}/" "${TAG}"

echo "✓ Created ${TARBALL}"
echo ""
echo "Next steps for OBS upload:"
echo "1. Go to your OBS Debian project"
echo "2. Upload ${TARBALL}"
echo "3. Upload all debian.* files from obs/ directory"
echo "4. Build will start automatically"
echo ""
echo "Files to upload:"
echo "  - ${TARBALL}"
echo "  - debian.control"
echo "  - debian.rules"
echo "  - debian.changelog"
echo "  - debian.compat"
echo "  - debian.source.format"
echo "  - debian.dbc-file-viewer.desktop"
