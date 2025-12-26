#!/bin/bash
# bump-version.sh - Bump version for a submodule repository
#
# Usage:
#   ./bump-version.sh <repo-name> <major|minor|fix> [description]
#   ./bump-version.sh gramarye-libcore minor "Added new hash functions"
#   ./bump-version.sh gramarye-libcore fix "Fixed memory leak"

set -e

REPO_NAME=$1
BUMP_TYPE=$2
DESCRIPTION=$3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_info() {
    echo -e "${YELLOW}$1${NC}"
}

# Validate inputs
if [ -z "$REPO_NAME" ]; then
    print_error "Repository name is required"
    echo ""
    echo "Usage: $0 <repo-name> <major|minor|fix> [description]"
    echo ""
    echo "Examples:"
    echo "  $0 gramarye-libcore minor \"Added new hash functions\""
    echo "  $0 gramarye-libcore fix \"Fixed memory leak in table.c\""
    echo "  $0 gramarye major \"Breaking: Changed API\""
    echo ""
    exit 1
fi

if [ -z "$BUMP_TYPE" ]; then
    print_error "Bump type is required (major, minor, or fix)"
    exit 1
fi

if [ "$BUMP_TYPE" != "major" ] && [ "$BUMP_TYPE" != "minor" ] && [ "$BUMP_TYPE" != "fix" ]; then
    print_error "Invalid bump type: $BUMP_TYPE"
    echo "Must be one of: major, minor, fix"
    exit 1
fi

# Check if repo exists
if [ ! -d "$REPO_NAME" ]; then
    print_error "Repository directory '$REPO_NAME' not found"
    echo ""
    echo "Available submodules:"
    git submodule status | awk '{print $2}' || echo "  (none found)"
    exit 1
fi

# Check if it's a git repository
if [ ! -d "$REPO_NAME/.git" ]; then
    print_error "'$REPO_NAME' is not a git repository"
    exit 1
fi

# Navigate to repository
cd "$REPO_NAME"

# Ensure we're on a branch (not detached HEAD) or at least have a clean state
if git rev-parse --abbrev-ref HEAD | grep -q HEAD; then
    print_info "Currently in detached HEAD state"
    CURRENT_BRANCH=$(git describe --tags --exact-match 2>/dev/null || echo "unknown")
    print_info "Current tag: $CURRENT_BRANCH"
    
    # Checkout main/master branch if available
    if git show-ref --verify --quiet refs/heads/main; then
        print_info "Switching to main branch..."
        git checkout main
    elif git show-ref --verify --quiet refs/heads/master; then
        print_info "Switching to master branch..."
        git checkout master
    else
        print_error "No main or master branch found. Please checkout a branch first."
        exit 1
    fi
fi

# Fetch latest tags
print_info "Fetching latest tags..."
git fetch --tags --quiet 2>/dev/null || true

# Get current version
CURRENT_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "")

if [ -z "$CURRENT_TAG" ]; then
    # No tag found, check for any version tags
    LATEST_TAG=$(git tag -l "v*" | sort -V | tail -1)
    
    if [ -z "$LATEST_TAG" ]; then
        # No version tags exist, start at v0.0.1
        print_info "No existing version tags found. Starting at v0.0.1"
        NEW_VERSION="v0.0.1"
        MAJOR=0
        MINOR=0
        FIX=1
    else
        print_info "Not currently on a tag. Latest tag is: $LATEST_TAG"
        CURRENT_TAG="$LATEST_TAG"
        # Parse version from tag
        VERSION_STR=$(echo "$CURRENT_TAG" | sed 's/^v//')
        IFS='.' read -r MAJOR MINOR FIX <<< "$VERSION_STR"
    fi
else
    print_info "Current version: $CURRENT_TAG"
    # Parse version from tag
    VERSION_STR=$(echo "$CURRENT_TAG" | sed 's/^v//')
    IFS='.' read -r MAJOR MINOR FIX <<< "$VERSION_STR"
fi

# Validate version numbers
if ! [[ "$MAJOR" =~ ^[0-9]+$ ]] || ! [[ "$MINOR" =~ ^[0-9]+$ ]] || ! [[ "$FIX" =~ ^[0-9]+$ ]]; then
    print_error "Could not parse version from tag: $CURRENT_TAG"
    exit 1
fi

# Bump version based on type
case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        FIX=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        FIX=0
        ;;
    fix)
        FIX=$((FIX + 1))
        ;;
esac

NEW_VERSION="v${MAJOR}.${MINOR}.${FIX}"

# Check if tag already exists
if git rev-parse "$NEW_VERSION" >/dev/null 2>&1; then
    print_error "Tag $NEW_VERSION already exists!"
    exit 1
fi

# Get description
if [ -z "$DESCRIPTION" ]; then
    echo ""
    read -p "Enter version description (or press Enter for default): " DESCRIPTION
fi

if [ -z "$DESCRIPTION" ]; then
    case "$BUMP_TYPE" in
        major)
            DESCRIPTION="Version $NEW_VERSION - Major release"
            ;;
        minor)
            DESCRIPTION="Version $NEW_VERSION - Minor release"
            ;;
        fix)
            DESCRIPTION="Version $NEW_VERSION - Bug fix release"
            ;;
    esac
fi

# Show what will happen
echo ""
print_info "Version bump summary:"
echo "  Repository: $REPO_NAME"
echo "  Current:    $CURRENT_TAG"
echo "  New:        $NEW_VERSION"
echo "  Type:       $BUMP_TYPE"
echo "  Description: $DESCRIPTION"
echo ""

# Confirm
read -p "Create tag $NEW_VERSION? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Cancelled"
    exit 0
fi

# Ensure we're at the latest commit (or user's current commit)
CURRENT_COMMIT=$(git rev-parse HEAD)
print_info "Creating tag $NEW_VERSION at commit $CURRENT_COMMIT"

# Create annotated tag
git tag -a "$NEW_VERSION" -m "$DESCRIPTION"

print_success "Tag $NEW_VERSION created successfully!"

# Ask about pushing
echo ""
read -p "Push tag to remote? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Pushing tag to remote..."
    if git push origin "$NEW_VERSION" 2>/dev/null; then
        print_success "Tag pushed to remote successfully!"
    else
        print_error "Failed to push tag. You may need to authenticate."
        echo "  You can push manually later with:"
        echo "    cd $REPO_NAME && git push origin $NEW_VERSION"
    fi
else
    print_info "Tag not pushed. Push manually with:"
    echo "  cd $REPO_NAME && git push origin $NEW_VERSION"
fi

# Go back to parent directory
cd ..

# Update parent repository to reference the new tag
print_info "Updating parent repository to reference $NEW_VERSION..."
git add "$REPO_NAME"

# Check if there are changes
if git diff --cached --quiet; then
    print_info "No changes to commit (submodule already at this commit)"
else
    COMMIT_MSG="Update $REPO_NAME to $NEW_VERSION"
    if [ -n "$DESCRIPTION" ] && [ "$DESCRIPTION" != "Version $NEW_VERSION - $BUMP_TYPE release" ]; then
        COMMIT_MSG="$COMMIT_MSG

$DESCRIPTION"
    fi
    
    echo ""
    read -p "Commit submodule update in parent repository? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        git commit -m "$COMMIT_MSG"
        print_success "Parent repository updated!"
        echo ""
        print_info "To push parent repository changes:"
        echo "  git push"
    else
        print_info "Submodule update staged but not committed."
        echo "  Commit manually with: git commit -m \"$COMMIT_MSG\""
    fi
fi

echo ""
print_success "Version bump complete!"
echo ""
echo "Summary:"
echo "  Repository: $REPO_NAME"
echo "  Old version: $CURRENT_TAG"
echo "  New version: $NEW_VERSION"


