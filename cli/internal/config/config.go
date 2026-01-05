package config

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/viper"
	"gopkg.in/yaml.v3"

	"github.com/jimmy/worktree-cli/pkg/errors"
)

// Config represents the application configuration
type Config struct {
	Directories struct {
		Worktrees   string `yaml:"worktrees" mapstructure:"worktrees"`
		Programming string `yaml:"programming" mapstructure:"programming"`
		Home        string `yaml:"home" mapstructure:"home"`
	} `yaml:"directories" mapstructure:"directories"`

	Git struct {
		DefaultBranch string   `yaml:"default_branch" mapstructure:"default_branch"`
		Remotes       []string `yaml:"remotes" mapstructure:"remotes"`
		MaxDepth      int      `yaml:"max_depth" mapstructure:"max_depth"`
	} `yaml:"git" mapstructure:"git"`

	UI struct {
		ColorEnabled bool `yaml:"color_enabled" mapstructure:"color_enabled"`
		Interactive  bool `yaml:"interactive" mapstructure:"interactive"`
	} `yaml:"ui" mapstructure:"ui"`

	JIRA struct {
		Pattern    string `yaml:"pattern" mapstructure:"pattern"`
		TicketLink string `yaml:"ticket_link" mapstructure:"ticket_link"`
	} `yaml:"jira" mapstructure:"jira"`
}

var (
	defaultConfig = Config{
		Directories: struct {
			Worktrees   string `yaml:"worktrees" mapstructure:"worktrees"`
			Programming string `yaml:"programming" mapstructure:"programming"`
			Home        string `yaml:"home" mapstructure:"home"`
		}{
			Worktrees:   filepath.Join(os.Getenv("HOME"), "Programming", "Worktrees"),
			Programming: filepath.Join(os.Getenv("HOME"), "Programming"),
			Home:        os.Getenv("HOME"),
		},
		Git: struct {
			DefaultBranch string   `yaml:"default_branch" mapstructure:"default_branch"`
			Remotes       []string `yaml:"remotes" mapstructure:"remotes"`
			MaxDepth      int      `yaml:"max_depth" mapstructure:"max_depth"`
		}{
			DefaultBranch: "main",
			Remotes:       []string{"origin"},
			MaxDepth:      3,
		},
		UI: struct {
			ColorEnabled bool `yaml:"color_enabled" mapstructure:"color_enabled"`
			Interactive  bool `yaml:"interactive" mapstructure:"interactive"`
		}{
			ColorEnabled: true,
			Interactive:  true,
		},
		JIRA: struct {
			Pattern    string `yaml:"pattern" mapstructure:"pattern"`
			TicketLink string `yaml:"ticket_link" mapstructure:"ticket_link"`
		}{
			Pattern:    `^[A-Z]+-[0-9]+$`,
			TicketLink: "",
		},
	}
)

// Load loads configuration from file or creates default
func Load() (*Config, error) {
	configDir, err := getConfigDir()
	if err != nil {
		return nil, errors.NewConfigError("failed to get config directory", err)
	}

	// Initialize viper
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(configDir)

	// Set environment variable bindings
	viper.SetEnvPrefix("DOTFILES")
	viper.AutomaticEnv()

	var config Config

	// Try to read existing config
	if err := viper.ReadInConfig(); err != nil {
		// Check if config file doesn't exist (viper returns different error types)
		configPath := filepath.Join(configDir, "config.yaml")
		if _, statErr := os.Stat(configPath); os.IsNotExist(statErr) {
			// Create default config
			config = defaultConfig
			if err := Save(&config); err != nil {
				return nil, errors.NewConfigError("failed to save default config", err)
			}
		} else {
			return nil, errors.NewConfigError("failed to read config", err)
		}
	} else {
		// Unmarshal existing config
		if err := viper.Unmarshal(&config); err != nil {
			return nil, errors.NewConfigError("failed to unmarshal config", err)
		}
	}

	// Override with environment variables
	if worktreeDir := os.Getenv("DOTFILES_WORKTREES_DIR"); worktreeDir != "" {
		config.Directories.Worktrees = worktreeDir
	}
	if progDir := os.Getenv("DOTFILES_PROGRAMMING_DIR"); progDir != "" {
		config.Directories.Programming = progDir
	}
	if jiraTicketLink := os.Getenv("ORG_JIRA_TICKET_LINK"); jiraTicketLink != "" {
		config.JIRA.TicketLink = jiraTicketLink
	}
	if jiraPattern := os.Getenv("JIRA_PATTERN"); jiraPattern != "" {
		config.JIRA.Pattern = jiraPattern
	}

	return &config, nil
}

// Save saves configuration to file
func Save(config *Config) error {
	configDir, err := getConfigDir()
	if err != nil {
		return errors.NewConfigError("failed to get config directory", err)
	}

	// Create config directory if it doesn't exist
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return errors.NewConfigError("failed to create config directory", err)
	}

	configPath := filepath.Join(configDir, "config.yaml")

	data, err := yaml.Marshal(config)
	if err != nil {
		return errors.NewConfigError("failed to marshal config", err)
	}

	if err := os.WriteFile(configPath, data, 0644); err != nil {
		return errors.NewConfigError("failed to write config file", err)
	}

	return nil
}

// Validate validates the configuration
func (c *Config) Validate() error {
	// Check required directories
	if c.Directories.Worktrees == "" {
		return errors.NewError(errors.ErrConfigInvalid, "worktrees directory not configured")
	}
	if c.Directories.Programming == "" {
		return errors.NewError(errors.ErrConfigInvalid, "programming directory not configured")
	}

	// Validate git configuration
	if c.Git.MaxDepth < 1 || c.Git.MaxDepth > 10 {
		return errors.NewError(errors.ErrConfigInvalid, "git max depth must be between 1 and 10")
	}

	return nil
}

// getConfigDir returns the configuration directory
func getConfigDir() (string, error) {
	configDir := os.Getenv("XDG_CONFIG_HOME")
	if configDir == "" {
		home := os.Getenv("HOME")
		if home == "" {
			return "", fmt.Errorf("HOME environment variable not set")
		}
		configDir = filepath.Join(home, ".config")
	}
	return filepath.Join(configDir, "worktree-cli"), nil
}
