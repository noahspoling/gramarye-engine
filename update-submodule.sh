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

# Initialize submodule if not already initialized
if ! git -C "$SUBMODULE" rev-parse HEAD >/dev/null 2>&1; then
    echo "Initializing submodule $SUBMODULE..."
    git submodule update --init "$SUBMODULE"
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

# Get the commit hash for the target
TARGET_COMMIT=$(git rev-parse HEAD)

cd ..

# Update submodule-versions.json if it exists
VERSIONS_FILE="submodule-versions.json"
if [ -f "$VERSIONS_FILE" ]; then
    if command -v jq &> /dev/null; then
        echo ""
        echo "Updating submodule-versions.json..."
        
        # Find the submodule name by matching the path
        SUBMODULE_NAME=$(jq -r --arg path "$SUBMODULE" '.submodules | to_entries[] | select(.value.path == $path) | .key' "$VERSIONS_FILE")
        
        if [ -n "$SUBMODULE_NAME" ] && [ "$SUBMODULE_NAME" != "null" ]; then
            # Extract tag without 'v' prefix if present (for consistency with JSON format)
            TAG_VALUE=$(echo "$TARGET" | sed 's/^v//')
            
            # Update JSON: set tag, commit, clear branch, update timestamp
            jq --arg name "$SUBMODULE_NAME" \
               --arg tag "$TAG_VALUE" \
               --arg commit "$TARGET_COMMIT" \
               --arg date "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
               '.submodules[$name].tag = $tag |
                .submodules[$name].commit = $commit |
                .submodules[$name].branch = null |
                .last_updated = $date' \
               "$VERSIONS_FILE" > "${VERSIONS_FILE}.tmp" && mv "${VERSIONS_FILE}.tmp" "$VERSIONS_FILE"
            
            echo "  Updated $SUBMODULE_NAME in submodule-versions.json"
            echo "    Tag: $TAG_VALUE"
            echo "    Commit: $TARGET_COMMIT"
        else
            echo "  Warning: Submodule '$SUBMODULE' not found in submodule-versions.json"
            echo "  Skipping JSON update"
        fi
    else
        echo ""
        echo "Warning: jq not found. Cannot update submodule-versions.json"
        echo "  Install jq or update manually"
    fi
fi

# Show what changed
echo ""
echo "Submodule updated. To commit:"
echo "  git add $SUBMODULE"
if [ -f "$VERSIONS_FILE" ]; then
    echo "  git add $VERSIONS_FILE"
fi
echo "  git commit -m \"Update $SUBMODULE to $TARGET\""


