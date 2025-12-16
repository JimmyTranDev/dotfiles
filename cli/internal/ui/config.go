package ui

import (
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// UIConfig represents the UI configuration
type UIConfig struct {
	Theme   CatppuccinVariant `yaml:"theme"`
	Enabled bool              `yaml:"enabled"`
}

// DefaultUIConfig returns the default UI configuration
func DefaultUIConfig() UIConfig {
	return UIConfig{
		Theme:   CatppuccinMocha, // Default to Mocha (dark theme)
		Enabled: true,
	}
}

// LoadUIConfig loads UI configuration from file
func LoadUIConfig() (*UIConfig, error) {
	configDir, err := getUIConfigDir()
	if err != nil {
		return nil, err
	}

	configPath := filepath.Join(configDir, "ui.yaml")

	// If config file doesn't exist, return default config
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		config := DefaultUIConfig()
		return &config, nil
	}

	// Read and parse config file
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, err
	}

	var config UIConfig
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	return &config, nil
}

// SaveUIConfig saves UI configuration to file
func SaveUIConfig(config *UIConfig) error {
	configDir, err := getUIConfigDir()
	if err != nil {
		return err
	}

	// Create config directory if it doesn't exist
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return err
	}

	configPath := filepath.Join(configDir, "ui.yaml")

	data, err := yaml.Marshal(config)
	if err != nil {
		return err
	}

	return os.WriteFile(configPath, data, 0644)
}

// getUIConfigDir returns the UI configuration directory
func getUIConfigDir() (string, error) {
	configDir := os.Getenv("XDG_CONFIG_HOME")
	if configDir == "" {
		home := os.Getenv("HOME")
		if home == "" {
			return "", os.ErrNotExist
		}
		configDir = filepath.Join(home, ".config")
	}
	return filepath.Join(configDir, "dotfiles-cli", "ui"), nil
}

// GetCurrentTheme returns the current theme instance
func GetCurrentTheme() *CatppuccinTheme {
	config, err := LoadUIConfig()
	if err != nil {
		// Fallback to default theme if config can't be loaded
		return DefaultTheme
	}

	return NewCatppuccinTheme(config.Theme)
}

// SetCurrentTheme sets and saves the current theme
func SetCurrentTheme(variant CatppuccinVariant) error {
	config := UIConfig{
		Theme:   variant,
		Enabled: true,
	}

	if err := SaveUIConfig(&config); err != nil {
		return err
	}

	// Update the global default theme
	DefaultTheme = NewCatppuccinTheme(variant)
	return nil
}
