#!/bin/bash

# Ensure Go is installed
if ! command -v go &> /dev/null; then
    echo "Error: Go is not installed. Please install Go first."
    exit 1
fi

# Create directory for the project
mkdir -p ~/go/src/bookmark
cd ~/go/src/bookmark

# Create the main.go file
cat > main.go << 'EOF'
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Bookmark represents a directory bookmark
type Bookmark struct {
	Name string `json:"name"`
	Path string `json:"path"`
}

// BookmarkStore manages the collection of bookmarks
type BookmarkStore struct {
	Bookmarks []Bookmark `json:"bookmarks"`
	filePath  string
}

// NewBookmarkStore creates a new bookmark store
func NewBookmarkStore() (*BookmarkStore, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("failed to get home directory: %w", err)
	}

	configDir := filepath.Join(homeDir, ".config", "bookmark")
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create config directory: %w", err)
	}

	filePath := filepath.Join(configDir, "bookmarks.json")
	store := &BookmarkStore{
		filePath:  filePath,
		Bookmarks: []Bookmark{},
	}

	// Load existing bookmarks if file exists
	if _, err := os.Stat(filePath); err == nil {
		data, err := os.ReadFile(filePath)
		if err != nil {
			return nil, fmt.Errorf("failed to read bookmarks file: %w", err)
		}

		if err := json.Unmarshal(data, &store); err != nil {
			return nil, fmt.Errorf("failed to parse bookmarks file: %w", err)
		}
	}

	return store, nil
}

// Save persists the bookmarks to disk
func (s *BookmarkStore) Save() error {
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to serialize bookmarks: %w", err)
	}

	if err := os.WriteFile(s.filePath, data, 0644); err != nil {
		return fmt.Errorf("failed to write bookmarks file: %w", err)
	}

	return nil
}

// Add adds a new bookmark
func (s *BookmarkStore) Add(name, path string) error {
	// Check if bookmark with this name already exists
	for _, b := range s.Bookmarks {
		if b.Name == name {
			return errors.New("bookmark with this name already exists")
		}
	}

	// Expand path if it contains ~
	if strings.HasPrefix(path, "~") {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("failed to expand home directory: %w", err)
		}
		path = filepath.Join(homeDir, path[1:])
	}

	// Validate that the path exists
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return fmt.Errorf("directory does not exist: %s", path)
	}

	// Get absolute path
	absPath, err := filepath.Abs(path)
	if err != nil {
		return fmt.Errorf("failed to get absolute path: %w", err)
	}

	s.Bookmarks = append(s.Bookmarks, Bookmark{
		Name: name,
		Path: absPath,
	})

	return s.Save()
}

// Remove removes a bookmark by name
func (s *BookmarkStore) Remove(name string) error {
	for i, b := range s.Bookmarks {
		if b.Name == name {
			// Remove the bookmark by creating a new slice without it
			s.Bookmarks = append(s.Bookmarks[:i], s.Bookmarks[i+1:]...)
			return s.Save()
		}
	}
	return fmt.Errorf("bookmark not found: %s", name)
}

// Get retrieves a bookmark by name
func (s *BookmarkStore) Get(name string) (string, error) {
	for _, b := range s.Bookmarks {
		if b.Name == name {
			return b.Path, nil
		}
	}
	return "", fmt.Errorf("bookmark not found: %s", name)
}

// List returns all bookmarks
func (s *BookmarkStore) List() []Bookmark {
	return s.Bookmarks
}

func printUsage() {
	fmt.Println("Usage:")
	fmt.Println("  bm add <name> [path]  - Add a bookmark for the current or specified directory")
	fmt.Println("  bm remove <name>      - Remove a bookmark")
	fmt.Println("  bm list               - List all bookmarks")
	fmt.Println("  bm go <name>          - Print the path of a bookmark (use with cd command, see below)")
	fmt.Println()
	fmt.Println("Setup:")
	fmt.Println("  Add this to your .bashrc or .zshrc:")
	fmt.Println("  function cdto() { cd \"$(bm go \"$1\")\" }")
	fmt.Println("  alias goto=\"cdto\"")
}

func main() {
	store, err := NewBookmarkStore()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	args := os.Args[1:]
	if len(args) == 0 {
		printUsage()
		return
	}

	command := args[0]
	
	switch command {
	case "add":
		if len(args) < 2 {
			fmt.Println("Error: Missing bookmark name")
			printUsage()
			os.Exit(1)
		}
		name := args[1]
		var path string
		if len(args) > 2 {
			path = args[2]
		} else {
			// Use current directory if no path specified
			var err error
			path, err = os.Getwd()
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error: Failed to get current directory: %v\n", err)
				os.Exit(1)
			}
		}
		
		if err := store.Add(name, path); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Added bookmark '%s' -> %s\n", name, path)
		
	case "remove":
		if len(args) < 2 {
			fmt.Println("Error: Missing bookmark name")
			printUsage()
			os.Exit(1)
		}
		name := args[1]
		if err := store.Remove(name); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Removed bookmark '%s'\n", name)
		
	case "go":
		if len(args) < 2 {
			fmt.Println("Error: Missing bookmark name")
			printUsage()
			os.Exit(1)
		}
		name := args[1]
		path, err := store.Get(name)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		// Just print the path so shell functions can use it
		fmt.Print(path)
		
	case "list":
		bookmarks := store.List()
		if len(bookmarks) == 0 {
			fmt.Println("No bookmarks saved.")
			return
		}
		
		fmt.Println("Bookmarks:")
		for _, b := range bookmarks {
			fmt.Printf("  %s -> %s\n", b.Name, b.Path)
		}
		
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", command)
		printUsage()
		os.Exit(1)
	}
}
EOF

# Build and install the binary
go build -o bm
chmod +x bm

# Install to /usr/local/bin if user has permissions, otherwise to ~/bin
if [ -w /usr/local/bin ]; then
    sudo mv bm /usr/local/bin/
    echo "Installed bm to /usr/local/bin/"
else
    mkdir -p ~/bin
    mv bm ~/bin/
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
    echo "Adding shell functions to $SHELL_CONFIG"
    cat >> "$SHELL_CONFIG" << 'EOF'

# Directory bookmarks
function cdto() {
    local dir=$(bm go "$1" 2>/dev/null)
    if [ -n "$dir" ]; then
        cd "$dir"
    else
        echo "Error: Bookmark not found: $1"
        return 1
    fi
}
alias goto="cdto"
EOF
    echo "Shell functions added. Please restart your terminal or run 'source $SHELL_CONFIG'"
else
    echo "Could not find shell config file. Please manually add the shell functions:"
    echo ""
    echo "function cdto() {"
    echo "    local dir=\$(bm go \"\$1\" 2>/dev/null)"
    echo "    if [ -n \"\$dir\" ]; then"
    echo "        cd \"\$dir\""
    echo "    else"
    echo "        echo \"Error: Bookmark not found: \$1\""
    echo "        return 1"
    echo "    fi"
    echo "}"
    echo "alias goto=\"cdto\""
fi

echo ""
echo "Installation complete!"
echo "Usage:"
echo "  bm add <name>       - Bookmark current directory"
echo "  bm list             - List all bookmarks"
echo "  goto <name>         - Jump to a bookmarked directory"
