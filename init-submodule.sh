#!/bin/bash
# init-submodule.sh - Initialize a new git submodule with versioning support
#
# Usage:
#   ./init-submodule.sh <repo-url> [path] [version]
#   ./init-submodule.sh https://github.com/user/repo.git my-repo
#   ./init-submodule.sh https://github.com/user/repo.git my-repo v1.2.3

set -e

REPO_URL=$1
SUBMODULE_PATH=$2
VERSION=$3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Validate inputs
if [ -z "$REPO_URL" ]; then
    print_error "Repository URL is required"
    echo ""
    echo "Usage: $0 <repo-url> [path] [version]"
    echo ""
    echo "Examples:"
    echo "  $0 https://github.com/user/repo.git"
    echo "  $0 https://github.com/user/repo.git my-repo"
    echo "  $0 https://github.com/user/repo.git my-repo v1.2.3"
    echo ""
    echo "If path is not provided, it will be derived from the URL."
    exit 1
fi

# Extract path from URL if not provided
if [ -z "$SUBMODULE_PATH" ]; then
    # Extract repo name from URL (last part before .git)
    SUBMODULE_PATH=$(basename "$REPO_URL" .git)
    print_info "No path specified, using: $SUBMODULE_PATH"
fi

# Check if path already exists
if [ -d "$SUBMODULE_PATH" ]; then
    if [ -d "$SUBMODULE_PATH/.git" ]; then
        print_info "Directory '$SUBMODULE_PATH' already exists and is a git repository"
        read -p "Add as submodule anyway? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            exit 0
        fi
    else
        print_error "Directory '$SUBMODULE_PATH' already exists and is not a git repository"
        exit 1
    fi
fi

# Check if already in .gitmodules
if [ -f .gitmodules ]; then
    if grep -q "\[submodule \"$SUBMODULE_PATH\"\]" .gitmodules 2>/dev/null; then
        print_error "Submodule '$SUBMODULE_PATH' already exists in .gitmodules"
        echo ""
        echo "To update an existing submodule, use:"
        echo "  ./update-submodule.sh $SUBMODULE_PATH [version]"
        exit 1
    fi
fi

print_header "Initializing submodule: $SUBMODULE_PATH"
echo "  URL: $REPO_URL"
echo "  Path: $SUBMODULE_PATH"
if [ -n "$VERSION" ]; then
    echo "  Version: $VERSION"
fi
echo ""

# Add the submodule
print_info "Adding submodule..."
if git submodule add "$REPO_URL" "$SUBMODULE_PATH" 2>/dev/null; then
    print_success "Submodule added successfully!"
else
    # If it failed, it might be because the directory exists
    if [ -d "$SUBMODULE_PATH/.git" ]; then
        print_info "Submodule directory exists. Checking if it's properly configured..."
        
        # Check if it's already in .gitmodules but not initialized
        if ! grep -q "\[submodule \"$SUBMODULE_PATH\"\]" .gitmodules 2>/dev/null; then
            print_error "Directory exists but not in .gitmodules. Manual intervention needed."
            exit 1
        else
            print_info "Submodule already in .gitmodules, initializing..."
            git submodule update --init "$SUBMODULE_PATH"
        fi
    else
        print_error "Failed to add submodule"
        exit 1
    fi
fi

# Navigate to submodule
cd "$SUBMODULE_PATH"

# Fetch tags
print_info "Fetching tags..."
git fetch --tags --quiet 2>/dev/null || true

# Check available versions
AVAILABLE_TAGS=$(git tag -l "v*" | sort -V)
LATEST_TAG=$(echo "$AVAILABLE_TAGS" | tail -1)

if [ -z "$AVAILABLE_TAGS" ]; then
    print_info "No version tags found in repository"
    
    # Ask if user wants to create initial version
    echo ""
    read -p "Create initial version tag (v0.0.1)? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        INITIAL_DESC="Initial release"
        read -p "Enter description for v0.0.1 [Initial release]: " INITIAL_DESC
        INITIAL_DESC=${INITIAL_DESC:-"Initial release"}
        
        git tag -a v0.0.1 -m "$INITIAL_DESC"
        print_success "Created tag v0.0.1"
        
        # Ask about pushing
        echo ""
        read -p "Push tag to remote? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if git push origin v0.0.1 2>/dev/null; then
                print_success "Tag pushed to remote!"
            else
                print_error "Failed to push tag. You may need to authenticate."
                echo "  Push manually with: git push origin v0.0.1"
            fi
        fi
        
        VERSION="v0.0.1"
    else
        print_info "No version tag created. Submodule will use current branch/commit."
    fi
else
    print_info "Available versions:"
    echo "$AVAILABLE_TAGS" | tail -5 | sed 's/^/  /'
    
    if [ -n "$LATEST_TAG" ]; then
        print_info "Latest version: $LATEST_TAG"
    fi
fi

# Checkout specific version if provided
if [ -n "$VERSION" ]; then
    # Verify tag exists
    if git rev-parse "$VERSION" >/dev/null 2>&1; then
        print_info "Checking out version: $VERSION"
        git checkout "$VERSION" --quiet
        print_success "Checked out $VERSION"
    else
        print_error "Tag '$VERSION' not found"
        echo "Available tags:"
        echo "$AVAILABLE_TAGS" | head -10 | sed 's/^/  /'
        echo ""
        read -p "Continue without checking out a version? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            cd ..
            exit 1
        fi
    fi
elif [ -n "$LATEST_TAG" ]; then
    # Ask if user wants to checkout latest version
    echo ""
    read -p "Checkout latest version ($LATEST_TAG)? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        print_info "Checking out latest version: $LATEST_TAG"
        git checkout "$LATEST_TAG" --quiet
        print_success "Checked out $LATEST_TAG"
        VERSION="$LATEST_TAG"
    fi
fi

# Go back to parent directory
cd ..

# Show current status
CURRENT_COMMIT=$(cd "$SUBMODULE_PATH" && git rev-parse --short HEAD)
CURRENT_REF=$(cd "$SUBMODULE_PATH" && git describe --tags --exact-match 2>/dev/null || echo "branch/commit $CURRENT_COMMIT")

print_success "Submodule initialized!"
echo ""
echo "Summary:"
echo "  Path: $SUBMODULE_PATH"
echo "  URL: $REPO_URL"
echo "  Current: $CURRENT_REF"

# Show what needs to be committed
echo ""
print_info "Submodule added. To commit:"
echo "  git add .gitmodules $SUBMODULE_PATH"
if [ -n "$VERSION" ]; then
    echo "  git commit -m \"Add submodule $SUBMODULE_PATH at $VERSION\""
else
    echo "  git commit -m \"Add submodule $SUBMODULE_PATH\""
fi

# Check if there are uncommitted changes
if ! git diff --cached --quiet || ! git diff --quiet; then
    echo ""
    read -p "Commit submodule addition now? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if [ -n "$VERSION" ]; then
            COMMIT_MSG="Add submodule $SUBMODULE_PATH at $VERSION"
        else
            COMMIT_MSG="Add submodule $SUBMODULE_PATH"
        fi
        
        git add .gitmodules "$SUBMODULE_PATH"
        git commit -m "$COMMIT_MSG"
        print_success "Committed submodule addition!"
    fi
fi

echo ""
print_info "Next steps:"
echo "  - Review the submodule at: $SUBMODULE_PATH"
if [ -z "$VERSION" ] && [ -n "$LATEST_TAG" ]; then
    echo "  - To checkout a specific version:"
    echo "    cd $SUBMODULE_PATH && git checkout <version> && cd .."
    echo "    git add $SUBMODULE_PATH && git commit -m \"Update $SUBMODULE_PATH to <version>\""
fi
echo "  - To update version later: ./update-submodule.sh $SUBMODULE_PATH [version]"
echo "  - To bump version: ./bump-version.sh $SUBMODULE_PATH <major|minor|fix> [description]"


