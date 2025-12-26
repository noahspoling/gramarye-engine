# Submodule Version Management

This project uses `submodule-versions.json` to track and manage submodule versions, allowing you to pin specific versions (tags, branches, or commits) for different projects.

## JSON Structure

The `submodule-versions.json` file tracks each submodule with:
- `path`: The submodule directory path
- `url`: The git repository URL
- `tag`: Git tag (e.g., "0.0.1") - takes precedence if specified
- `branch`: Git branch name - used if tag is null
- `commit`: Specific commit hash - used if both tag and branch are null
- `description`: Human-readable description

## Usage Examples

### Example 1: Using a Tag (Recommended for Releases)

If `gramarye-libcore` has a tag `0.0.1`, update the JSON:

```json
{
  "submodules": {
    "gramarye-libcore": {
      "path": "gramarye-libcore",
      "url": "https://github.com/noahspoling/xmos-libcore.git",
      "tag": "0.0.1",
      "branch": null,
      "commit": null,
      "description": "Core library for gramarye projects"
    }
  }
}
```

Then checkout the versions:
```bash
./manage-submodules.sh checkout
```

### Example 2: Using a Specific Commit

For a specific commit hash:
```json
{
  "submodules": {
    "gramarye-libcore": {
      "tag": null,
      "branch": null,
      "commit": "376951aa077faa1dca5a12f4c61ac5074a136719"
    }
  }
}
```

### Example 3: Using a Branch

For a development branch:
```json
{
  "submodules": {
    "gramarye-libcore": {
      "tag": null,
      "branch": "develop",
      "commit": null
    }
  }
}
```

## Script Commands

### Checkout submodules to versions in JSON
```bash
./manage-submodules.sh checkout
```
This will:
1. Initialize submodules if needed
2. Fetch latest changes
3. Checkout the version specified in JSON (tag > branch > commit priority)

### Update JSON with current submodule versions
```bash
./manage-submodules.sh update
```
This updates the `commit` field in JSON with the current HEAD commit of each submodule.

### Show version status
```bash
./manage-submodules.sh status
```
Shows what versions are specified in JSON vs what's currently checked out.

## Workflow Examples

### Setting up a new project with specific libcore version

1. Edit `submodule-versions.json` to set `gramarye-libcore.tag` to `"0.0.1"`
2. Run `./manage-submodules.sh checkout`
3. Commit the updated JSON file to your project

### Updating libcore to a new version

1. Edit `submodule-versions.json` to change the tag (e.g., `"0.0.1"` → `"0.0.2"`)
2. Run `./manage-submodules.sh checkout`
3. Test your project
4. Commit the updated JSON file

### Capturing current state

If you've manually updated submodules and want to save the current state:
```bash
./manage-submodules.sh update
```
This will update the commit hashes in the JSON file.

