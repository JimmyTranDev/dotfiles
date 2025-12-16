package install

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	"github.com/fatih/color"

	"github.com/jimmy/dotfiles-cli/internal/config"
)

// Manager handles install operations
type Manager struct {
	cfg *config.Config
}

// NewManager creates a new install manager
func NewManager(cfg *config.Config) *Manager {
	return &Manager{cfg: cfg}
}

// InstallType represents the type of installation
type InstallType string

const (
	InstallTypeFull       InstallType = "full"
	InstallTypeCloneRepos InstallType = "clone-repos"
	InstallTypeFetchAll   InstallType = "fetch-all"
	InstallTypeUpdate     InstallType = "update"
)

// InstallOption represents an install option
type InstallOption struct {
	Type        InstallType
	Name        string
	Description string
	ScriptPath  string
}

// GetInstallOptions returns available install options
func (m *Manager) GetInstallOptions() []InstallOption {
	dotfilesDir := filepath.Join(m.cfg.Directories.Home, "Programming", "dotfiles")

	return []InstallOption{
		{
			Type:        InstallTypeFull,
			Name:        "Full Installation",
			Description: "Complete dotfiles setup for macOS/Linux with symlinks and packages",
			ScriptPath:  filepath.Join(dotfilesDir, "etc", "scripts", "install", "install.sh"),
		},
		{
			Type:        InstallTypeCloneRepos,
			Name:        "Clone Essential Repositories",
			Description: "Clone essential repositories like nvim-config",
			ScriptPath:  filepath.Join(dotfilesDir, "etc", "scripts", "install", "clone_essential_repos.sh"),
		},
		{
			Type:        InstallTypeFetchAll,
			Name:        "Fetch All Repositories",
			Description: "Pull latest changes for all repositories in Programming directory",
			ScriptPath:  filepath.Join(dotfilesDir, "etc", "scripts", "install", "fetch_all_folders.sh"),
		},
		{
			Type:        InstallTypeUpdate,
			Name:        "Update Development Environment",
			Description: "Update Neovim plugins, Mason tools, and pull dotfiles changes",
			ScriptPath:  filepath.Join(dotfilesDir, "etc", "scripts", "update_dotfiles.sh"),
		},
	}
}

// RunInstall executes the specified install type
func (m *Manager) RunInstall(installType InstallType, targetDir string) error {
	options := m.GetInstallOptions()

	var selectedOption *InstallOption
	for _, option := range options {
		if option.Type == installType {
			selectedOption = &option
			break
		}
	}

	if selectedOption == nil {
		return fmt.Errorf("unknown install type: %s", installType)
	}

	// Check if script exists
	if _, err := os.Stat(selectedOption.ScriptPath); os.IsNotExist(err) {
		return fmt.Errorf("install script not found: %s", selectedOption.ScriptPath)
	}

	color.Cyan("🚀 Running: %s", selectedOption.Name)
	color.Yellow("   %s", selectedOption.Description)
	fmt.Println()

	// Prepare command
	var cmd *exec.Cmd

	switch installType {
	case InstallTypeFetchAll:
		// For fetch-all, we can optionally specify a target directory
		if targetDir == "" {
			targetDir = filepath.Join(m.cfg.Directories.Home, "Programming")
		}
		cmd = exec.Command("bash", selectedOption.ScriptPath, targetDir)
	default:
		cmd = exec.Command("bash", selectedOption.ScriptPath)
	}

	// Set up command execution
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	// Set environment variables
	cmd.Env = append(os.Environ(),
		fmt.Sprintf("HOME=%s", m.cfg.Directories.Home),
		fmt.Sprintf("DOTFILES_DIR=%s", filepath.Join(m.cfg.Directories.Home, "Programming", "dotfiles")),
	)

	// Execute command
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("install failed: %w", err)
	}

	color.Green("✓ Installation completed successfully!")
	return nil
}

// ValidateEnvironment checks if the environment is ready for installation
func (m *Manager) ValidateEnvironment() error {
	// Check operating system
	if runtime.GOOS != "darwin" && runtime.GOOS != "linux" {
		return fmt.Errorf("unsupported operating system: %s (supported: macOS, Linux)", runtime.GOOS)
	}

	// Check if dotfiles directory exists
	dotfilesDir := filepath.Join(m.cfg.Directories.Home, "Programming", "dotfiles")
	if _, err := os.Stat(dotfilesDir); os.IsNotExist(err) {
		return fmt.Errorf("dotfiles directory not found: %s", dotfilesDir)
	}

	// Check if scripts directory exists
	scriptsDir := filepath.Join(dotfilesDir, "etc", "scripts", "install")
	if _, err := os.Stat(scriptsDir); os.IsNotExist(err) {
		return fmt.Errorf("install scripts directory not found: %s", scriptsDir)
	}

	// Check for required tools
	requiredTools := []string{"bash", "git"}
	for _, tool := range requiredTools {
		if _, err := exec.LookPath(tool); err != nil {
			return fmt.Errorf("required tool not found: %s", tool)
		}
	}

	return nil
}

// GetSystemInfo returns information about the current system
func (m *Manager) GetSystemInfo() map[string]string {
	info := make(map[string]string)

	info["OS"] = runtime.GOOS
	info["Architecture"] = runtime.GOARCH

	// Check for package managers
	if runtime.GOOS == "darwin" {
		if _, err := exec.LookPath("brew"); err == nil {
			info["Package Manager"] = "Homebrew"
		}
	} else if runtime.GOOS == "linux" {
		if _, err := exec.LookPath("pacman"); err == nil {
			info["Package Manager"] = "Pacman (Arch)"
		} else if _, err := exec.LookPath("apt"); err == nil {
			info["Package Manager"] = "APT (Debian/Ubuntu)"
		} else if _, err := exec.LookPath("dnf"); err == nil {
			info["Package Manager"] = "DNF (Fedora)"
		}
	}

	return info
}
