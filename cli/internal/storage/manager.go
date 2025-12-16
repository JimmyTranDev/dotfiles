package storage

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/jimmy/dotfiles-cli/internal/config"
)

// Manager handles cloud storage operations
type Manager interface {
	InitSecretsDirectory() error
	SyncSecrets(dryRun bool) error
	ValidateB2Credentials() error
}

// manager implements the Manager interface
type manager struct {
	config      *config.Config
	secretsPath string
}

// TemplateFile represents a template file to create
type TemplateFile struct {
	Name    string
	Content string
}

// Default template files
var defaultTemplateFiles = []TemplateFile{
	{
		Name:    "technical_links.json",
		Content: "{}",
	},
	{
		Name:    "useful_links.json",
		Content: "{}",
	},
}

// NewManager creates a new storage manager
func NewManager(cfg *config.Config) Manager {
	secretsPath := filepath.Join(cfg.Directories.Programming, "secrets")
	return &manager{
		config:      cfg,
		secretsPath: secretsPath,
	}
}

// InitSecretsDirectory creates the secrets directory with template files
func (m *manager) InitSecretsDirectory() error {
	// Ensure secrets directory exists
	if err := os.MkdirAll(m.secretsPath, 0755); err != nil {
		return fmt.Errorf("failed to create secrets directory: %w", err)
	}

	// Create template files
	successCount := 0
	for _, template := range defaultTemplateFiles {
		filePath := filepath.Join(m.secretsPath, template.Name)

		// Only create file if it doesn't exist
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			if err := os.WriteFile(filePath, []byte(template.Content), 0644); err != nil {
				return fmt.Errorf("failed to create template file %s: %w", template.Name, err)
			}
			successCount++
		}
	}

	if successCount > 0 {
		return nil // Success - at least one file was created or all existed
	}

	return nil
}

// ValidateB2Credentials checks if B2 environment variables are set
func (m *manager) ValidateB2Credentials() error {
	required := []string{
		"B2_BUCKET_NAME",
		"B2_APPLICATION_KEY_ID",
		"B2_APPLICATION_KEY",
	}

	for _, env := range required {
		if os.Getenv(env) == "" {
			return fmt.Errorf("missing required B2 environment variable: %s", env)
		}
	}

	return nil
}

// setupB2Command configures a B2 command with proper environment to avoid terminal issues
func setupB2Command(cmd *exec.Cmd) {
	// Set environment variables to fix terminal size issues with B2 CLI
	// This prevents the "buffer overflow" error in rst2ansi package
	cmd.Env = append(os.Environ(),
		"COLUMNS=80", // Force terminal width
		"LINES=24",   // Force terminal height
		"TERM=xterm", // Force terminal type
		"NO_COLOR=1", // Disable colored output to avoid rst2ansi issues
	)
}

// SyncSecrets syncs the secrets directory to B2 cloud storage
func (m *manager) SyncSecrets(dryRun bool) error {
	// Validate B2 credentials first
	if err := m.ValidateB2Credentials(); err != nil {
		return fmt.Errorf("B2 credentials validation failed: %w", err)
	}

	// Check if secrets directory exists
	if _, err := os.Stat(m.secretsPath); os.IsNotExist(err) {
		return fmt.Errorf("secrets directory does not exist: %s", m.secretsPath)
	}

	// Check if b2 CLI is available
	if _, err := exec.LookPath("b2"); err != nil {
		return fmt.Errorf("b2 CLI not found. Install with: pip install b2")
	}

	bucketName := os.Getenv("B2_BUCKET_NAME")
	keyId := os.Getenv("B2_APPLICATION_KEY_ID")
	key := os.Getenv("B2_APPLICATION_KEY")

	// Authorize with B2
	authCmd := exec.Command("b2", "account", "authorize", keyId, key)
	setupB2Command(authCmd)
	if err := authCmd.Run(); err != nil {
		return fmt.Errorf("failed to authorize with B2: %w", err)
	}

	// Build sync command arguments
	args := []string{"sync", m.secretsPath, fmt.Sprintf("b2://%s", bucketName),
		"--exclude-regex", `.*\.m2/repository/.*`,
		"--replace-newer"} // Allow replacing newer files

	if dryRun {
		args = append(args, "--dry-run")
	}

	// Sync directory to B2
	syncCmd := exec.Command("b2", args...)
	syncCmd.Stdout = os.Stdout
	syncCmd.Stderr = os.Stderr
	setupB2Command(syncCmd)

	if err := syncCmd.Run(); err != nil {
		return fmt.Errorf("failed to sync to B2: %w", err)
	}

	return nil
}
