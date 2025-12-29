package linking

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/fatih/color"

	"github.com/jimmy/dotfiles-cli/internal/config"
)

// Manager handles linking operations for dotfiles
type Manager struct {
	cfg *config.Config
}

// NewManager creates a new linking manager
func NewManager(cfg *config.Config) *Manager {
	return &Manager{cfg: cfg}
}

// LinkType represents the type of linking operation
type LinkType string

const (
	LinkTypeSymlink  LinkType = "symlink"
	LinkTypeHardlink LinkType = "hardlink"
	LinkTypeCopy     LinkType = "copy"
)

// LinkMapping represents a source-to-target mapping for linking
type LinkMapping struct {
	Source string
	Target string
	Type   LinkType
}

// GetDefaultMappings returns the default symlink mappings for dotfiles
func (m *Manager) GetDefaultMappings() []LinkMapping {
	dotfilesDir := filepath.Join(m.cfg.Directories.Home, "Programming", "dotfiles", "src")

	return []LinkMapping{
		{
			Source: filepath.Join(dotfilesDir, ".zshrc"),
			Target: filepath.Join(m.cfg.Directories.Home, ".zshrc"),
			Type:   LinkTypeSymlink,
		},
		{
			Source: filepath.Join(dotfilesDir, ".ideavimrc"),
			Target: filepath.Join(m.cfg.Directories.Home, ".ideavimrc"),
			Type:   LinkTypeSymlink,
		},
		{
			Source: filepath.Join(dotfilesDir, ".gitignore_global"),
			Target: filepath.Join(m.cfg.Directories.Home, ".gitignore_global"),
			Type:   LinkTypeSymlink,
		},
		{
			Source: filepath.Join(dotfilesDir, "starship.toml"),
			Target: filepath.Join(m.cfg.Directories.Home, ".config", "starship.toml"),
			Type:   LinkTypeSymlink,
		},
		{
			Source: filepath.Join(dotfilesDir, "ghostty"),
			Target: filepath.Join(m.cfg.Directories.Home, ".config", "ghostty"),
			Type:   LinkTypeSymlink,
		},
		{
			Source: filepath.Join(dotfilesDir, "yazi"),
			Target: filepath.Join(m.cfg.Directories.Home, ".config", "yazi"),
			Type:   LinkTypeSymlink,
		},
		{
			Source: filepath.Join(dotfilesDir, "zellij"),
			Target: filepath.Join(m.cfg.Directories.Home, ".config", "zellij"),
			Type:   LinkTypeSymlink,
		},
		{
			Source: filepath.Join(dotfilesDir, "lazygit"),
			Target: filepath.Join(m.cfg.Directories.Home, ".config", "lazygit"),
			Type:   LinkTypeSymlink,
		},
		{
			Source: filepath.Join(dotfilesDir, "btop"),
			Target: filepath.Join(m.cfg.Directories.Home, ".config", "btop"),
			Type:   LinkTypeSymlink,
		},
		{
			Source: filepath.Join(dotfilesDir, "skhd"),
			Target: filepath.Join(m.cfg.Directories.Home, ".config", "skhd"),
			Type:   LinkTypeSymlink,
		},
		{
			Source: filepath.Join(dotfilesDir, "yabai"),
			Target: filepath.Join(m.cfg.Directories.Home, ".config", "yabai"),
			Type:   LinkTypeSymlink,
		},
	}
}

// CreateLinks creates links for the specified mappings
func (m *Manager) CreateLinks(mappings []LinkMapping) error {
	successCount := 0
	totalCount := len(mappings)

	color.Blue("🔗 Creating %d links...", totalCount)

	for _, mapping := range mappings {
		if err := m.createLink(mapping); err != nil {
			color.Yellow("⚠ Failed to create link %s -> %s: %v",
				filepath.Base(mapping.Source), filepath.Base(mapping.Target), err)
		} else {
			color.Green("✓ Created link: %s", filepath.Base(mapping.Target))
			successCount++
		}
	}

	fmt.Println()
	color.Cyan("📋 Linking Summary:")
	color.Cyan("  • Successfully linked: %d files", successCount)
	color.Cyan("  • Failed links: %d files", totalCount-successCount)
	color.Cyan("  • Total files processed: %d", totalCount)

	if successCount < totalCount {
		color.Yellow("💡 Some links failed - check the output above for details")
	}

	return nil
}

// CreateDefaultLinks creates symlinks using the default mappings
func (m *Manager) CreateDefaultLinks() error {
	mappings := m.GetDefaultMappings()
	return m.CreateLinks(mappings)
}

// RemoveLinks removes the specified links
func (m *Manager) RemoveLinks(mappings []LinkMapping) error {
	successCount := 0
	totalCount := len(mappings)

	color.Blue("🗑 Removing %d links...", totalCount)

	for _, mapping := range mappings {
		if err := m.removeLink(mapping.Target); err != nil {
			color.Yellow("⚠ Failed to remove link %s: %v", filepath.Base(mapping.Target), err)
		} else {
			color.Green("✓ Removed link: %s", filepath.Base(mapping.Target))
			successCount++
		}
	}

	fmt.Println()
	color.Cyan("📋 Removal Summary:")
	color.Cyan("  • Successfully removed: %d links", successCount)
	color.Cyan("  • Failed removals: %d links", totalCount-successCount)
	color.Cyan("  • Total links processed: %d", totalCount)

	return nil
}

// RemoveDefaultLinks removes symlinks using the default mappings
func (m *Manager) RemoveDefaultLinks() error {
	mappings := m.GetDefaultMappings()
	return m.RemoveLinks(mappings)
}

// ValidateLinks checks if all links in the mappings are valid
func (m *Manager) ValidateLinks(mappings []LinkMapping) ([]string, []string, error) {
	var validLinks []string
	var brokenLinks []string

	for _, mapping := range mappings {
		if m.isValidLink(mapping) {
			validLinks = append(validLinks, mapping.Target)
		} else {
			brokenLinks = append(brokenLinks, mapping.Target)
		}
	}

	return validLinks, brokenLinks, nil
}

// ValidateDefaultLinks validates all default symlinks
func (m *Manager) ValidateDefaultLinks() ([]string, []string, error) {
	mappings := m.GetDefaultMappings()
	return m.ValidateLinks(mappings)
}

// createLink creates a single link based on the mapping type
func (m *Manager) createLink(mapping LinkMapping) error {
	// Check if source exists
	if _, err := os.Stat(mapping.Source); os.IsNotExist(err) {
		return fmt.Errorf("source not found: %s", mapping.Source)
	}

	// Create target directory if needed
	if err := os.MkdirAll(filepath.Dir(mapping.Target), 0755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", filepath.Dir(mapping.Target), err)
	}

	// Remove existing target if it exists
	if _, err := os.Lstat(mapping.Target); err == nil {
		if err := os.Remove(mapping.Target); err != nil {
			return fmt.Errorf("failed to remove existing target: %w", err)
		}
	}

	// Create link based on type
	switch mapping.Type {
	case LinkTypeSymlink:
		return os.Symlink(mapping.Source, mapping.Target)
	case LinkTypeHardlink:
		return os.Link(mapping.Source, mapping.Target)
	case LinkTypeCopy:
		return m.copyFile(mapping.Source, mapping.Target)
	default:
		return fmt.Errorf("unsupported link type: %s", mapping.Type)
	}
}

// removeLink removes a link at the specified target path
func (m *Manager) removeLink(target string) error {
	// Check if target exists
	if _, err := os.Lstat(target); os.IsNotExist(err) {
		return fmt.Errorf("link not found: %s", target)
	}

	return os.Remove(target)
}

// isValidLink checks if a link mapping is valid (source exists and target points to source)
func (m *Manager) isValidLink(mapping LinkMapping) bool {
	// Check if source exists
	if _, err := os.Stat(mapping.Source); os.IsNotExist(err) {
		return false
	}

	// Check if target exists
	targetInfo, err := os.Lstat(mapping.Target)
	if err != nil {
		return false
	}

	// For symlinks, check if they point to the correct source
	if mapping.Type == LinkTypeSymlink && targetInfo.Mode()&os.ModeSymlink != 0 {
		linkTarget, err := os.Readlink(mapping.Target)
		if err != nil {
			return false
		}
		return linkTarget == mapping.Source
	}

	// For hardlinks and copies, just check if target exists and source exists
	return true
}

// copyFile copies a file from source to target
func (m *Manager) copyFile(source, target string) error {
	sourceFile, err := os.Open(source)
	if err != nil {
		return err
	}
	defer sourceFile.Close()

	targetFile, err := os.Create(target)
	if err != nil {
		return err
	}
	defer targetFile.Close()

	_, err = targetFile.ReadFrom(sourceFile)
	return err
}
