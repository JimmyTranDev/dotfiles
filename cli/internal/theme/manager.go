package theme

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/jimmy/dotfiles-cli/internal/config"
)

// Manager handles theme operations
type Manager interface {
	SetTheme(themeName string) error
	GetCurrentTheme() string
	ListAvailableThemes() []string
	ValidateTheme(themeName string) error
}

// manager implements the Manager interface
type manager struct {
	config *config.Config
}

// NewManager creates a new theme manager
func NewManager(cfg *config.Config) Manager {
	return &manager{config: cfg}
}

// SetTheme applies a theme across all configured applications
func (m *manager) SetTheme(themeName string) error {
	if err := m.ValidateTheme(themeName); err != nil {
		return err
	}

	// Apply theme to each application
	if err := m.applyGhosttyTheme(themeName); err != nil {
		return fmt.Errorf("failed to apply Ghostty theme: %w", err)
	}

	if err := m.applyZellijTheme(themeName); err != nil {
		return fmt.Errorf("failed to apply Zellij theme: %w", err)
	}

	if err := m.applyBtopTheme(themeName); err != nil {
		return fmt.Errorf("failed to apply btop theme: %w", err)
	}

	if err := m.applyZshTheme(themeName); err != nil {
		return fmt.Errorf("failed to apply Zsh theme: %w", err)
	}

	// Update theme config
	m.config.Themes.Current = themeName
	if err := config.Save(m.config); err != nil {
		return fmt.Errorf("failed to save theme configuration: %w", err)
	}

	return nil
}

// GetCurrentTheme returns the currently active theme
func (m *manager) GetCurrentTheme() string {
	return m.config.Themes.Current
}

// ListAvailableThemes returns all available themes
func (m *manager) ListAvailableThemes() []string {
	return m.config.Themes.Available
}

// ValidateTheme checks if a theme name is valid
func (m *manager) ValidateTheme(themeName string) error {
	for _, theme := range m.config.Themes.Available {
		if theme == themeName {
			return nil
		}
	}
	return fmt.Errorf("invalid theme '%s'. Available themes: %v", themeName, m.config.Themes.Available)
}

// applyGhosttyTheme applies theme to Ghostty terminal
func (m *manager) applyGhosttyTheme(themeName string) error {
	configPath := m.config.Themes.Paths["ghostty"]
	if configPath == "" {
		return fmt.Errorf("Ghostty config path not configured")
	}

	// Expand home directory
	if strings.HasPrefix(configPath, "~/") {
		home := os.Getenv("HOME")
		configPath = filepath.Join(home, configPath[2:])
	}

	// Read current config
	lines, err := m.readConfigFile(configPath)
	if err != nil {
		return err
	}

	// Update theme line
	themePattern := regexp.MustCompile(`^theme\s*=\s*.*`)
	newThemeLine := fmt.Sprintf("theme = catppuccin-%s", themeName)

	updated := false
	for i, line := range lines {
		if themePattern.MatchString(line) {
			lines[i] = newThemeLine
			updated = true
			break
		}
	}

	// If no theme line found, add it
	if !updated {
		lines = append(lines, newThemeLine)
	}

	// Write back to file
	return m.writeConfigFile(configPath, lines)
}

// applyZellijTheme applies theme to Zellij multiplexer
func (m *manager) applyZellijTheme(themeName string) error {
	configPath := m.config.Themes.Paths["zellij"]
	if configPath == "" {
		return fmt.Errorf("Zellij config path not configured")
	}

	// Expand home directory
	if strings.HasPrefix(configPath, "~/") {
		home := os.Getenv("HOME")
		configPath = filepath.Join(home, configPath[2:])
	}

	// Read current config
	lines, err := m.readConfigFile(configPath)
	if err != nil {
		return err
	}

	// Update theme line in KDL format
	themePattern := regexp.MustCompile(`^\s*theme\s+".*"`)
	newThemeLine := fmt.Sprintf(`theme "catppuccin-%s"`, themeName)

	updated := false
	for i, line := range lines {
		if themePattern.MatchString(line) {
			// Preserve indentation
			indent := ""
			for _, char := range line {
				if char == ' ' || char == '\t' {
					indent += string(char)
				} else {
					break
				}
			}
			lines[i] = indent + newThemeLine
			updated = true
			break
		}
	}

	// If no theme line found, add it at the top
	if !updated {
		lines = append([]string{newThemeLine}, lines...)
	}

	// Write back to file
	return m.writeConfigFile(configPath, lines)
}

// applyBtopTheme applies theme to btop system monitor
func (m *manager) applyBtopTheme(themeName string) error {
	configPath := m.config.Themes.Paths["btop"]
	if configPath == "" {
		return fmt.Errorf("btop config path not configured")
	}

	// Expand home directory
	if strings.HasPrefix(configPath, "~/") {
		home := os.Getenv("HOME")
		configPath = filepath.Join(home, configPath[2:])
	}

	// Read current config
	lines, err := m.readConfigFile(configPath)
	if err != nil {
		return err
	}

	// Map theme names to btop color schemes
	colorSchemeMap := map[string]string{
		"mocha":     "catppuccin_mocha",
		"frappe":    "catppuccin_frappe",
		"latte":     "catppuccin_latte",
		"macchiato": "catppuccin_macchiato",
	}

	colorScheme, exists := colorSchemeMap[themeName]
	if !exists {
		return fmt.Errorf("no btop color scheme found for theme '%s'", themeName)
	}

	// Update color_theme line
	themePattern := regexp.MustCompile(`^color_theme\s*=\s*.*`)
	newThemeLine := fmt.Sprintf(`color_theme = "%s"`, colorScheme)

	updated := false
	for i, line := range lines {
		if themePattern.MatchString(line) {
			lines[i] = newThemeLine
			updated = true
			break
		}
	}

	// If no theme line found, add it
	if !updated {
		lines = append(lines, newThemeLine)
	}

	// Write back to file
	return m.writeConfigFile(configPath, lines)
}

// applyZshTheme applies theme colors to .zshrc for FZF
func (m *manager) applyZshTheme(themeName string) error {
	zshrcPath := filepath.Join(os.Getenv("HOME"), ".zshrc")

	// Theme color mappings for FZF
	fzfColors := map[string]string{
		"mocha":     `export FZF_DEFAULT_OPTS="--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6ac,pointer:#f5e0dc --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6ac,hl+:#f38ba8"`,
		"latte":     `export FZF_DEFAULT_OPTS="--color=bg+:#ccd0da,bg:#eff1f5,spinner:#dc8a78,hl:#d20f39 --color=fg:#4c4f69,header:#d20f39,info:#8839ef,pointer:#dc8a78 --color=marker:#dc8a78,fg+:#4c4f69,prompt:#8839ef,hl+:#d20f39"`,
		"frappe":    `export FZF_DEFAULT_OPTS="--color=bg+:#414559,bg:#303446,spinner:#f2d5cf,hl:#e78284 --color=fg:#c6d0f5,header:#e78284,info:#ca9ee6,pointer:#f2d5cf --color=marker:#f2d5cf,fg+:#c6d0f5,prompt:#ca9ee6,hl+:#e78284"`,
		"macchiato": `export FZF_DEFAULT_OPTS="--color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 --color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 --color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796"`,
	}

	newFzfLine, exists := fzfColors[themeName]
	if !exists {
		return fmt.Errorf("no FZF colors found for theme '%s'", themeName)
	}

	// Read current .zshrc
	lines, err := m.readConfigFile(zshrcPath)
	if err != nil {
		return err
	}

	// Update FZF_DEFAULT_OPTS line
	fzfPattern := regexp.MustCompile(`^export FZF_DEFAULT_OPTS=.*`)

	updated := false
	for i, line := range lines {
		if fzfPattern.MatchString(line) {
			lines[i] = newFzfLine
			updated = true
			break
		}
	}

	// If no FZF line found, add it
	if !updated {
		lines = append(lines, "", "# Catppuccin theme colors for FZF", newFzfLine)
	}

	// Write back to file
	return m.writeConfigFile(zshrcPath, lines)
}

// readConfigFile reads a configuration file and returns lines
func (m *manager) readConfigFile(filePath string) ([]string, error) {
	// Create directory if it doesn't exist
	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create directory %s: %w", dir, err)
	}

	// Check if file exists
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		// Return empty slice for new file
		return []string{}, nil
	}

	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to open file %s: %w", filePath, err)
	}
	defer file.Close()

	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("failed to read file %s: %w", filePath, err)
	}

	return lines, nil
}

// writeConfigFile atomically writes lines to a configuration file
func (m *manager) writeConfigFile(filePath string, lines []string) error {
	// Create temporary file
	tempFile, err := os.CreateTemp(filepath.Dir(filePath), ".tmp-*")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tempFile.Name())

	// Write lines to temp file
	writer := bufio.NewWriter(tempFile)
	for _, line := range lines {
		if _, err := writer.WriteString(line + "\n"); err != nil {
			tempFile.Close()
			return fmt.Errorf("failed to write to temp file: %w", err)
		}
	}

	if err := writer.Flush(); err != nil {
		tempFile.Close()
		return fmt.Errorf("failed to flush temp file: %w", err)
	}

	if err := tempFile.Close(); err != nil {
		return fmt.Errorf("failed to close temp file: %w", err)
	}

	// Atomically replace original file
	if err := os.Rename(tempFile.Name(), filePath); err != nil {
		return fmt.Errorf("failed to replace config file: %w", err)
	}

	return nil
}
