# Bookmark (bm)

A simple CLI tool that allows you to bookmark directories and quickly navigate between them in your terminal.

## Features

- Bookmark any directory with a custom name
- List all your saved bookmarks
- Quickly navigate to bookmarked directories using the `goto` command
- Prevent duplicate bookmark names and paths
- Persistent storage between sessions

## Installation

### Option 1: One-line installation (recommended)

```bash
curl -sSL https://raw.githubusercontent.com/Bitlatte/bookmark/main/install.sh | bash
```

### Option 2: Manual download and install

```bash
# Download the install script
curl -O https://raw.githubusercontent.com/Bitlatte/bookmark/main/install.sh

# Make it executable
chmod +x install.sh

# Run the installer
./install.sh
```

### Option 3: Build from source

```bash
# Clone the repository
git clone https://github.com/Bitlatte/bookmark.git

# Navigate to the project directory
cd bookmark

# Build the project
go build -o bm

# Install the binary
sudo mv bm /usr/local/bin/

# Add shell functions to your .bashrc or .zshrc
echo '
# Directory bookmarks
function cdto() {
    local dir=$(bm go "$1" 2>/dev/null)
    if [ -n "$dir" ]; then
        cd "$dir"
        echo "Changed directory to: $dir"
    else
        echo "Error: Bookmark not found: $1"
        return 1
    fi
}
alias goto="cdto"
' >> ~/.bashrc

# Source your updated shell configuration
source ~/.bashrc
```

## Usage

### Bookmark the current directory

```bash
bm add work
```

### Bookmark a specific directory

```bash
bm add projects ~/projects
```

### Navigate to a bookmarked directory

```bash
goto work
```

### List all bookmarks

```bash
bm list
```

### Remove a bookmark

```bash
bm remove work
```

## How it works

The tool stores your bookmarks in a JSON file at `~/.config/bookmarks/bookmarks.json`. The `bm` command itself can't directly change your shell's current directory (due to process isolation in Unix-like systems), so it uses a shell function called `cdto` (aliased as `goto`) that's added to your shell configuration during installation.

When you run `goto work`, the shell function calls `bm go work` to get the bookmarked path, then uses the shell's built-in `cd` command to change to that directory.

## Troubleshooting

### The `goto` command doesn't work

Make sure you've restarted your terminal or run `source ~/.bashrc` (or `source ~/.zshrc`) after installation to load the shell functions.

### Bookmarks persist after uninstallation

If you uninstall the tool but still want to remove your bookmarks, delete the file at `~/.config/bookmarks/bookmarks.json`.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

MIT
