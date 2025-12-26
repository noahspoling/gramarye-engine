#!/bin/bash
# update-submodule.sh - Update a submodule to a specific version or latest compatible version
#
# Usage:
#   ./update-submodule.sh <submodule-path> [version]
#   ./update-submodule.sh gramarye-libcore v1.2.3
#   ./update-submodule.sh gramarye-libcore latest  # Latest in current major version

set -e

SUBMODULE=$1
VERSION=$2

if [ -z "$SUBMODULE" ]; then
    echo "Usage: $0 <submodule-path> [version|latest]"
    echo "  version: Specific version tag (e.g., v1.2.3)"
    echo "  latest:  Latest version in current major version"
    exit 1
fi

if [ ! -d "$SUBMODULE" ]; then
    echo "Error: Submodule directory '$SUBMODULE' not found"
    exit 1
fi

cd "$SUBMODULE"

# Fetch latest tags
echo "Fetching tags..."
git fetch --tags --quiet

# Get current version
CURRENT=$(git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)
echo "Current: $CURRENT"

if [ -z "$VERSION" ] || [ "$VERSION" = "latest" ]; then
    # Find latest version
    if [ "$VERSION" = "latest" ]; then
        # Get current major version if we're on a tag
        if git describe --tags --exact-match HEAD &>/dev/null; then
            CURRENT_TAG=$(git describe --tags --exact-match HEAD)
            MAJOR_VERSION=$(echo "$CURRENT_TAG" | sed 's/v\([0-9]*\)\..*/\1/')
        else
            # Default to latest major version 1
            MAJOR_VERSION=1
        fi
        
        # Get latest tag in this major version
        TARGET=$(git tag -l "v${MAJOR_VERSION}.*" | sort -V | tail -1)
        
        if [ -z "$TARGET" ]; then
            echo "No tags found for major version $MAJOR_VERSION"
            exit 1
        fi
    else
        # Just get the absolute latest tag
        TARGET=$(git tag -l "v*" | sort -V | tail -1)
    fi
    
    if [ -z "$TARGET" ]; then
        echo "No version tags found"
        exit 1
    fi
else
    TARGET="$VERSION"
fi

# Verify tag exists
if ! git rev-parse "$TARGET" >/dev/null 2>&1; then
    echo "Error: Tag '$TARGET' not found"
    echo "Available tags:"
    git tag -l | head -10
    exit 1
fi

# Checkout the target version
echo "Updating to: $TARGET"
git checkout "$TARGET" --quiet

cd ..

# Show what changed
echo ""
echo "Submodule updated. To commit:"
echo "  git add $SUBMODULE"
echo "  git commit -m \"Update $SUBMODULE to $TARGET\""


