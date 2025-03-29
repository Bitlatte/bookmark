package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type Bookmark struct {
	Name string `json:"name"`
	Path string `json:"path"`
}

type BookmarkStore struct {
	Bookmarks []Bookmark `json:"bookmarks"`
	filePath  string
}

func NewBookmarkStore() (*BookmarkStore, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("Failed to get home directory: %w", err)
	}

	configDir := filepath.Join(homeDir, ".config", "bookmark")
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return nil, fmt.Errorf("Failed to create config directory: %w", err)
	}

	filePath := filepath.Join(configDir, "bookmarks.json")
	store := &BookmarkStore{
		filePath:  filePath,
		Bookmarks: []Bookmark{},
	}

	// Load existing bookmarks
	if _, err := os.Stat(filePath); err == nil {
		data, err := os.ReadFile(filePath)
		if err != nil {
			return nil, fmt.Errorf("Failed to read bookmarks file: %w", err)
		}

		if err := json.Unmarshal(data, &store); err != nil {
			return nil, fmt.Errorf("Failed to parse bookmarks file: %w", err)
		}
	}

	return store, nil
}

// Persist bookmarks to disk
func (s *BookmarkStore) Save() error {
	data, err := json.MarshalIndent(s, "", " ")
	if err != nil {
		return fmt.Errorf("Failed to serialize bookmarks: %w", err)
	}

	if err := os.WriteFile(s.filePath, data, 0644); err != nil {
		return fmt.Errorf("Failed to write bookmarks file: %w", err)
	}

	return nil
}

// Add new bookmark
func (s *BookmarkStore) Add(name, path string) error {
	// Check if bookmark already exists
	for _, b := range s.Bookmarks {
		if b.Name == name {
			return fmt.Errorf("bookmark with name '%s' already exists (points to: %s)", name, b.Path)
		}
	}

	// Expand path if it contains ~
	if strings.HasPrefix(path, "~") {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("Failed to expand home directory: %w", err)
		}

		path = filepath.Join(homeDir, path[1:])
	}

	// Validate the path
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return fmt.Errorf("Directory does not exist: %s", path)
	}

	// Get absolue path
	absPath, err := filepath.Abs(path)
	if err != nil {
		return fmt.Errorf("Failed to get absolute path: %w", err)
	}

	// Check if path is already bookmarked
	for _, b := range s.Bookmarks {
		if b.Path == absPath {
			return fmt.Errorf("This directory is already bookmarked as '%s'", b.Name)
		}
	}

	s.Bookmarks = append(s.Bookmarks, Bookmark{
		Name: name,
		Path: absPath,
	})

	return s.Save()
}

// Remove bookmark by name
func (s *BookmarkStore) Remove(name string) error {
	for i, b := range s.Bookmarks {
		if b.Name == name {
			s.Bookmarks = append(s.Bookmarks[:i], s.Bookmarks[i+1:]...)
			return s.Save()
		}
	}
	return fmt.Errorf("Bookmark not found: %s", name)
}

// Retrieve a bookmark by name
func (s *BookmarkStore) Get(name string) (string, error) {
	for _, b := range s.Bookmarks {
		if b.Name == name {
			return b.Path, nil
		}
	}
	return "", fmt.Errorf("Bookmark not found: %s", name)
}

// List all bookmarks
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
			fmt.Print(os.UserHomeDir())
		} else {
			name := args[1]
			path, err := store.Get(name)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				os.Exit(1)
			}
			fmt.Print(path)
		}

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
