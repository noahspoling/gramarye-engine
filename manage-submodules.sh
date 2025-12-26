#!/bin/bash

# Script to manage submodule versions from submodule-versions.json

VERSIONS_FILE="submodule-versions.json"

# Function to read current submodule versions and update JSON
update_versions_json() {
    echo "Updating submodule-versions.json with current submodule commits..."
    
    # Get current commit for gramarye
    GRAMARYE_COMMIT=$(git -C gramarye rev-parse HEAD 2>/dev/null || echo "")
    # Get current commit for gramarye-libcore
    LIBCORE_COMMIT=$(git -C gramarye-libcore rev-parse HEAD 2>/dev/null || echo "")
    
    # Update JSON using jq if available, otherwise use sed
    if command -v jq &> /dev/null; then
        jq --arg gramarye_commit "$GRAMARYE_COMMIT" \
           --arg libcore_commit "$LIBCORE_COMMIT" \
           --arg date "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
           '.submodules.gramarye.commit = $gramarye_commit |
            .submodules."gramarye-libcore".commit = $libcore_commit |
            .last_updated = $date' \
           "$VERSIONS_FILE" > "${VERSIONS_FILE}.tmp" && mv "${VERSIONS_FILE}.tmp" "$VERSIONS_FILE"
        echo "Updated submodule-versions.json"
    else
        echo "Warning: jq not found. Please install jq for automatic JSON updates, or update manually."
        echo "Current commits:"
        echo "  gramarye: $GRAMARYE_COMMIT"
        echo "  gramarye-libcore: $LIBCORE_COMMIT"
    fi
}

# Function to checkout a specific submodule version (tag, branch, or commit)
checkout_submodule() {
    local submodule_path=$1
    local tag=$2
    local branch=$3
    local commit=$4
    
    if [ "$tag" != "null" ] && [ -n "$tag" ]; then
        echo "  Checking out tag: $tag"
        git -C "$submodule_path" fetch --tags 2>/dev/null
        git -C "$submodule_path" checkout "tags/$tag" 2>/dev/null || git -C "$submodule_path" checkout "$tag" 2>/dev/null || {
            echo "  Warning: Could not checkout tag $tag"
            return 1
        }
    elif [ "$branch" != "null" ] && [ -n "$branch" ]; then
        echo "  Checking out branch: $branch"
        git -C "$submodule_path" fetch origin "$branch" 2>/dev/null
        git -C "$submodule_path" checkout "$branch" 2>/dev/null || {
            echo "  Warning: Could not checkout branch $branch"
            return 1
        }
    elif [ -n "$commit" ] && [ "$commit" != "null" ]; then
        echo "  Checking out commit: $commit"
        git -C "$submodule_path" fetch 2>/dev/null
        git -C "$submodule_path" checkout "$commit" 2>/dev/null || {
            echo "  Warning: Could not checkout commit $commit"
            return 1
        }
    else
        echo "  Warning: No tag, branch, or commit specified"
        return 1
    fi
}

# Function to initialize and checkout submodules to versions in JSON
checkout_versions() {
    echo "Checking out submodules to versions specified in $VERSIONS_FILE..."
    
    if [ ! -f "$VERSIONS_FILE" ]; then
        echo "Error: $VERSIONS_FILE not found!"
        exit 1
    fi
    
    # Initialize submodules if not already initialized
    git submodule update --init --recursive
    
    # Read versions from JSON (using jq if available, otherwise manual parsing)
    if command -v jq &> /dev/null; then
        # Process each submodule
        jq -r '.submodules | to_entries[] | "\(.key)|\(.value.path)|\(.value.tag // "null")|\(.value.branch // "null")|\(.value.commit // "null")"' "$VERSIONS_FILE" | while IFS='|' read -r name path tag branch commit; do
            echo "Processing $name:"
            checkout_submodule "$path" "$tag" "$branch" "$commit"
        done
    else
        echo "Error: jq is required to read from JSON. Please install jq or update submodules manually."
        exit 1
    fi
    
    echo ""
    echo "Submodules checked out to specified versions."
}

# Function to show current vs JSON versions
show_status() {
    echo "Submodule Version Status:"
    echo "========================="
    
    if command -v jq &> /dev/null; then
        echo ""
        echo "From submodule-versions.json:"
        jq -r '.submodules | to_entries[] | 
            "\(.key):\n" +
            "  Tag: \(.value.tag // "none")\n" +
            "  Branch: \(.value.branch // "none")\n" +
            "  Commit: \(.value.commit // "none")"' "$VERSIONS_FILE"
        
        echo ""
        echo "Current checked out versions:"
        jq -r '.submodules | to_entries[] | .value.path' "$VERSIONS_FILE" | while read -r path; do
            if [ -d "$path/.git" ]; then
                CURRENT_COMMIT=$(git -C "$path" rev-parse HEAD 2>/dev/null)
                CURRENT_TAG=$(git -C "$path" describe --tags --exact-match 2>/dev/null || echo "none")
                CURRENT_BRANCH=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
                echo "$path:"
                echo "  Commit: $CURRENT_COMMIT"
                echo "  Tag: $CURRENT_TAG"
                echo "  Branch: $CURRENT_BRANCH"
            else
                echo "$path: (not initialized)"
            fi
        done
    else
        echo "Error: jq is required. Please install jq."
        exit 1
    fi
}

# Main script logic
case "$1" in
    update)
        update_versions_json
        ;;
    checkout)
        checkout_versions
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {update|checkout|status}"
        echo ""
        echo "Commands:"
        echo "  update   - Update submodule-versions.json with current submodule commits"
        echo "  checkout - Initialize and checkout submodules to versions in JSON"
        echo "  status   - Show current submodule versions vs JSON versions"
        exit 1
        ;;
esac

