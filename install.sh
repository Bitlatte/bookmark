#!/bin/bash

# Ensure Go is installed
if ! command -v go &> /dev/null; then
    echo "Error: Go is not installed. Please install Go first."
    exit 1
fi

# Ensure git is installed
if ! command -v git &> /dev/null; then
    echo "Error: Git is not installed. Please install Git first."
    exit 1
fi

# Create temporary directory for the installation
TEMP_DIR=$(mktemp -d)
echo "Cloning repository to $TEMP_DIR..."

# Clone the repository
REPO_URL="https://github.com/bitlatte/bookmark.git"
if ! git clone "$REPO_URL" "$TEMP_DIR"; then
    echo "Failed to clone repository from $REPO_URL"
    echo "Please check that the repository exists and is accessible."
    echo "Cleaning up..."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Navigate to the cloned directory
cd "$TEMP_DIR" || exit 1

# Build the project
echo "Building project..."
go build -o bm || {
    echo "Failed to build. Make sure Go is installed correctly."
    echo "Cleaning up..."
    rm -rf "$TEMP_DIR"
    exit 1
}

# Install binary to appropriate location
echo "Installing binary..."
if [ -w /usr/local/bin ]; then
    sudo cp bm /usr/local/bin/
    echo "Installed bm to /usr/local/bin/"
else
    mkdir -p ~/bin
    cp bm ~/bin/
    echo "Installed bm to ~/bin/"

    # Add ~/bin to PATH if it's not already there
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo "Adding ~/bin to your PATH"
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
        echo "Please restart your terminal or run 'source ~/.bashrc' to update your PATH"
    fi
fi

# Add shell function to bashrc or zshrc
SHELL_CONFIG=""
if [ -f ~/.zshrc ]; then
    SHELL_CONFIG=~/.zshrc
elif [ -f ~/.bashrc ]; then
    SHELL_CONFIG=~/.bashrc
fi

if [ -n "$SHELL_CONFIG" ]; then
    echo "Checking shell configuration in $SHELL_CONFIG..."

    # Check if functions already exist
    if grep -q "function cdto()" "$SHELL_CONFIG"; then
        echo "Shell functions already exist in $SHELL_CONFIG, skipping..."
    else
        echo "Adding shell functions to $SHELL_CONFIG"
        cat >> "$SHELL_CONFIG" << 'EOF'

# Directory bookmarks
function cdto() {
    if [ $# -eq 0 ]; then
        # If no arguments, just use bm go (which will handle default case)
        local dir=$(bm go 2>/dev/null)
    else
        # Otherwise pass the bookmark name
        local dir=$(bm go "$1" 2>/dev/null)
    fi

    if [ -n "$dir" ]; then
        cd "$dir"
        echo "Changed directory to: $dir"
    else
        echo "Error: Bookmark not found: $1"
        return 1
    fi
}
alias goto="cdto"
EOF
        echo "Shell functions added. Please restart your terminal or run 'source $SHELL_CONFIG'"
    fi
else
    echo "Could not find shell config file. Please manually add the shell functions:"
    echo ""
    echo "function cdto() {"
    echo "    if [ \$# -eq 0 ]; then"
    echo "        # If no arguments, just use bm go (which will handle default case)"
    echo "        local dir=\$(bm go 2>/dev/null)"
    echo "    else"
    echo "        # Otherwise pass the bookmark name"
    echo "        local dir=\$(bm go \"\$1\" 2>/dev/null)"
    echo "    fi"
    echo ""
    echo "    if [ -n \"\$dir\" ]; then"
    echo "        cd \"\$dir\""
    echo "        echo \"Changed directory to: \$dir\""
    echo "    else"
    echo "        echo \"Error: Bookmark not found: \$1\""
    echo "        return 1"
    echo "    fi"
    echo "}"
    echo "alias goto=\"cdto\""
fi

# Clean up temporary directory
echo "Cleaning up..."
rm -rf "$TEMP_DIR"

echo ""
echo "Installation complete!"
echo "Usage:"
echo "  bm add <name>       - Bookmark current directory"
echo "  bm list             - List all bookmarks"
echo "  goto <name>         - Jump to a bookmarked directory"
