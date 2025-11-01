package config

import (
	"os"
	"path/filepath"
)

// Config holds all configuration for the worktree manager
type Config struct {
	WorktreesDir   string
	ProgrammingDir string
	JiraPattern    string
	JiraTicketLink string
	WorktreeTypes  []string
	WorktreeEmojis []string
}

// Default configuration values
var (
	DefaultWorktreesDir   = filepath.Join(os.Getenv("HOME"), "Programming", "Worktrees")
	DefaultProgrammingDir = filepath.Join(os.Getenv("HOME"), "Programming")
	DefaultJiraPattern    = `^[A-Z]+-[0-9]+`
	DefaultWorktreeTypes  = []string{"ci", "build", "docs", "feat", "perf", "refactor", "style", "test", "fix", "revert"}
	DefaultWorktreeEmojis = []string{"👷", "📦", "📚", "✨", "🚀", "🔨", "💎", "🧪", "🐛", "⏪"}
)

// NewConfig creates a new configuration with default values
func NewConfig() *Config {
	return &Config{
		WorktreesDir:   getEnvOrDefault("WORKTREES_DIR", DefaultWorktreesDir),
		ProgrammingDir: getEnvOrDefault("PROGRAMMING_DIR", DefaultProgrammingDir),
		JiraPattern:    getEnvOrDefault("JIRA_PATTERN", DefaultJiraPattern),
		JiraTicketLink: os.Getenv("ORG_JIRA_TICKET_LINK"),
		WorktreeTypes:  DefaultWorktreeTypes,
		WorktreeEmojis: DefaultWorktreeEmojis,
	}
}

// getEnvOrDefault returns the environment variable value or the default if not set
func getEnvOrDefault(envVar, defaultValue string) string {
	if value := os.Getenv(envVar); value != "" {
		return value
	}
	return defaultValue
}

// GetEmojiForType returns the emoji for a given commit type
func (c *Config) GetEmojiForType(commitType string) string {
	for i, t := range c.WorktreeTypes {
		if t == commitType && i < len(c.WorktreeEmojis) {
			return c.WorktreeEmojis[i]
		}
	}
	// Default emoji mappings
	switch commitType {
	case "feat":
		return "✨"
	case "fix":
		return "🐛"
	case "docs":
		return "📚"
	case "style":
		return "💎"
	case "refactor":
		return "🔨"
	case "test":
		return "🧪"
	case "chore":
		return "🔧"
	case "revert":
		return "⏪"
	case "build":
		return "📦"
	case "ci":
		return "👷"
	case "perf":
		return "🚀"
	default:
		return "✨"
	}
}
