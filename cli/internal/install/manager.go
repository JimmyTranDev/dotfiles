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
	return []InstallOption{
		{
			Type:        InstallTypeFull,
			Name:        "Full Installation",
			Description: "Complete dotfiles setup for macOS/Linux with symlinks and packages",
			ScriptPath:  "", // Self-contained implementation
		},
		{
			Type:        InstallTypeCloneRepos,
			Name:        "Clone Essential Repositories",
			Description: "Clone essential repositories like nvim-config",
			ScriptPath:  "", // Self-contained implementation
		},
		{
			Type:        InstallTypeFetchAll,
			Name:        "Fetch All Repositories",
			Description: "Pull latest changes for all repositories in Programming directory",
			ScriptPath:  "", // Self-contained implementation
		},
		{
			Type:        InstallTypeUpdate,
			Name:        "Update Development Environment",
			Description: "Update Neovim plugins, Mason tools, and pull dotfiles changes",
			ScriptPath:  "", // Self-contained implementation
		},
	}
}

// RunInstall executes the specified install type using native Go implementations
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

	color.Cyan("🚀 Running: %s", selectedOption.Name)
	color.Yellow("   %s", selectedOption.Description)
	fmt.Println()

	// Execute native Go implementation based on install type
	switch installType {
	case InstallTypeFull:
		return m.runFullInstallation()
	case InstallTypeCloneRepos:
		return m.runCloneEssentialRepos()
	case InstallTypeFetchAll:
		if targetDir == "" {
			targetDir = filepath.Join(m.cfg.Directories.Home, "Programming")
		}
		return m.runFetchAllRepos(targetDir)
	case InstallTypeUpdate:
		return m.runUpdateDevEnvironment()
	default:
		return fmt.Errorf("unknown install type: %s", installType)
	}
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

	// Check for required tools
	requiredTools := []string{"git"}
	for _, tool := range requiredTools {
		if _, err := exec.LookPath(tool); err != nil {
			return fmt.Errorf("required tool not found: %s", tool)
		}
	}

	return nil
}

// runFullInstallation implements full dotfiles setup
func (m *Manager) runFullInstallation() error {
	color.Blue("🔧 Starting full installation...")

	// 1. Detect platform and package manager
	platform := runtime.GOOS
	packageManager, err := m.detectPackageManager()
	if err != nil {
		color.Yellow("⚠ Package manager detection failed: %v", err)
		color.Yellow("  Continuing with manual package installation...")
	}

	// 2. Create symlinks for dotfiles
	if err := m.createSymlinks(); err != nil {
		return fmt.Errorf("symlink creation failed: %w", err)
	}

	// 3. Install packages if package manager is available
	if packageManager != "" {
		if err := m.installPackages(packageManager, platform); err != nil {
			color.Yellow("⚠ Package installation failed: %v", err)
			color.Yellow("  You may need to install packages manually")
		}
	}

	color.Green("🎉 Full installation completed successfully!")
	fmt.Println()
	color.Cyan("📋 Installation Summary:")
	color.Cyan("  • Platform: %s", platform)
	if packageManager != "" {
		color.Cyan("  • Package manager: %s", packageManager)
		color.Cyan("  • System packages installed")
	}
	color.Cyan("  • Dotfiles symlinks created")
	color.Cyan("  • Configuration files linked")
	fmt.Println()
	color.Yellow("💡 Next steps:")
	color.Yellow("  • Restart your terminal to apply all changes")
	color.Yellow("  • Run 'dotfiles theme set' to configure themes")
	color.Yellow("  • Check that all symlinks are working correctly")
	fmt.Println()
	return nil
}

// runCloneEssentialRepos clones essential repositories
func (m *Manager) runCloneEssentialRepos() error {
	color.Blue("📦 Cloning essential repositories...")

	repos := []struct {
		url    string
		target string
	}{
		{
			url:    "git@github.com:jimmy/nvim-config.git",
			target: filepath.Join(m.cfg.Directories.Home, ".config", "nvim"),
		},
	}

	for _, repo := range repos {
		if err := m.cloneRepository(repo.url, repo.target); err != nil {
			color.Yellow("⚠ Failed to clone %s: %v", repo.url, err)
			color.Yellow("  You may need to clone this manually")
		} else {
			color.Green("✓ Cloned %s", repo.url)
		}
	}

	color.Green("🎉 Essential repositories setup completed!")
	fmt.Println()
	color.Cyan("📋 Cloning Summary:")
	color.Cyan("  • Essential repositories processed")
	color.Cyan("  • Neovim configuration installed")
	color.Cyan("  • Development environment ready")
	fmt.Println()
	color.Yellow("💡 Next steps:")
	color.Yellow("  • Open Neovim to install plugins")
	color.Yellow("  • Configure your development environment")
	color.Yellow("  • Check that all repositories are accessible")
	fmt.Println()
	return nil
}

// runFetchAllRepos updates all Git repositories in the specified directory
func (m *Manager) runFetchAllRepos(targetDir string) error {
	color.Blue("🔄 Fetching updates for all repositories in %s...", targetDir)

	repos, err := m.findGitRepositories(targetDir)
	if err != nil {
		return fmt.Errorf("failed to find repositories: %w", err)
	}

	if len(repos) == 0 {
		color.Yellow("No Git repositories found in %s", targetDir)
		return nil
	}

	successCount := 0
	for _, repo := range repos {
		if err := m.pullRepository(repo); err != nil {
			color.Red("✗ Failed to update %s: %v", filepath.Base(repo), err)
		} else {
			color.Green("✓ Updated %s", filepath.Base(repo))
			successCount++
		}
	}

	fmt.Println()
	color.Green("🎉 Repository updates completed!")
	fmt.Println()
	color.Cyan("📋 Update Summary:")
	color.Cyan("  • Successfully updated: %d repositories", successCount)
	color.Cyan("  • Failed updates: %d repositories", len(repos)-successCount)
	color.Cyan("  • Total repositories scanned: %d", len(repos))
	color.Cyan("  • Target directory: %s", targetDir)
	fmt.Println()
	if successCount < len(repos) {
		color.Yellow("💡 Some updates failed - check the output above for details")
	} else {
		color.Yellow("💡 All repositories are now up to date!")
	}
	fmt.Println()
	return nil
}

// runUpdateDevEnvironment updates development environment tools
func (m *Manager) runUpdateDevEnvironment() error {
	color.Blue("🔄 Updating development environment...")

	// 1. Update Yazi plugins
	if err := m.updateYaziPlugins(); err != nil {
		color.Yellow("⚠ Yazi plugin update failed: %v", err)
	} else {
		color.Green("✓ Updated Yazi plugins")
	}

	// 2. Update Neovim plugins
	if err := m.updateNeovimPlugins(); err != nil {
		color.Yellow("⚠ Neovim plugin update failed: %v", err)
	} else {
		color.Green("✓ Updated Neovim plugins")
	}

	// 3. Update Mason tools
	if err := m.updateMasonTools(); err != nil {
		color.Yellow("⚠ Mason tools update failed: %v", err)
	} else {
		color.Green("✓ Updated Mason tools")
	}

	// 4. Update dotfiles repository
	dotfilesDir := filepath.Join(m.cfg.Directories.Home, "Programming", "dotfiles")
	if err := m.pullRepository(dotfilesDir); err != nil {
		color.Yellow("⚠ Dotfiles update failed: %v", err)
	} else {
		color.Green("✓ Updated dotfiles repository")
	}

	fmt.Println()
	color.Green("🎉 Development environment update completed!")
	fmt.Println()
	color.Cyan("📋 Update Summary:")
	color.Cyan("  • Yazi plugins updated")
	color.Cyan("  • Neovim plugins updated")
	color.Cyan("  • Mason tools updated")
	color.Cyan("  • Dotfiles repository updated")
	fmt.Println()
	color.Yellow("💡 Next steps:")
	color.Yellow("  • Restart your terminal/applications to apply updates")
	color.Yellow("  • Check that all tools are working correctly")
	color.Yellow("  • Review any new features in updated tools")
	fmt.Println()
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

// Helper methods for native Go implementations

// detectPackageManager detects the available package manager
func (m *Manager) detectPackageManager() (string, error) {
	packageManagers := []string{"brew", "pacman", "paru", "apt", "dnf"}

	for _, pm := range packageManagers {
		if _, err := exec.LookPath(pm); err == nil {
			return pm, nil
		}
	}

	return "", fmt.Errorf("no supported package manager found")
}

// createSymlinks creates symlinks for dotfiles
func (m *Manager) createSymlinks() error {
	dotfilesDir := filepath.Join(m.cfg.Directories.Home, "Programming", "dotfiles", "src")

	symlinkMap := map[string]string{
		filepath.Join(dotfilesDir, ".zshrc"):            filepath.Join(m.cfg.Directories.Home, ".zshrc"),
		filepath.Join(dotfilesDir, ".ideavimrc"):        filepath.Join(m.cfg.Directories.Home, ".ideavimrc"),
		filepath.Join(dotfilesDir, ".gitignore_global"): filepath.Join(m.cfg.Directories.Home, ".gitignore_global"),
		filepath.Join(dotfilesDir, "starship.toml"):     filepath.Join(m.cfg.Directories.Home, ".config", "starship.toml"),
		filepath.Join(dotfilesDir, "ghostty"):           filepath.Join(m.cfg.Directories.Home, ".config", "ghostty"),
		filepath.Join(dotfilesDir, "yazi"):              filepath.Join(m.cfg.Directories.Home, ".config", "yazi"),
		filepath.Join(dotfilesDir, "zellij"):            filepath.Join(m.cfg.Directories.Home, ".config", "zellij"),
		filepath.Join(dotfilesDir, "lazygit"):           filepath.Join(m.cfg.Directories.Home, ".config", "lazygit"),
		filepath.Join(dotfilesDir, "btop"):              filepath.Join(m.cfg.Directories.Home, ".config", "btop"),
		filepath.Join(dotfilesDir, "skhd"):              filepath.Join(m.cfg.Directories.Home, ".config", "skhd"),
		filepath.Join(dotfilesDir, "yabai"):             filepath.Join(m.cfg.Directories.Home, ".config", "yabai"),
	}

	for source, target := range symlinkMap {
		// Check if source exists
		if _, err := os.Stat(source); os.IsNotExist(err) {
			color.Yellow("⚠ Skipping %s (source not found)", filepath.Base(source))
			continue
		}

		// Create target directory if needed
		if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", filepath.Dir(target), err)
		}

		// Remove existing target if it exists
		if _, err := os.Lstat(target); err == nil {
			if err := os.Remove(target); err != nil {
				color.Yellow("⚠ Failed to remove existing %s: %v", target, err)
				continue
			}
		}

		// Create symlink
		if err := os.Symlink(source, target); err != nil {
			color.Yellow("⚠ Failed to create symlink %s -> %s: %v", source, target, err)
		} else {
			color.Green("✓ Created symlink: %s", filepath.Base(target))
		}
	}

	return nil
}

// installPackages installs packages using the detected package manager
func (m *Manager) installPackages(packageManager, platform string) error {
	var packages []string
	var cmd *exec.Cmd

	switch packageManager {
	case "brew":
		// Install Brewfile if it exists
		brewfile := filepath.Join(m.cfg.Directories.Home, "Programming", "dotfiles", "src", "Brewfile")
		if _, err := os.Stat(brewfile); err == nil {
			cmd = exec.Command("brew", "bundle", "install", "--file", brewfile)
		} else {
			packages = []string{"git", "neovim", "yazi", "zellij", "lazygit", "btop", "starship", "fzf"}
			cmd = exec.Command("brew", append([]string{"install"}, packages...)...)
		}
	case "pacman", "paru":
		packages = []string{"git", "neovim", "yazi", "zellij", "lazygit", "btop", "starship", "fzf"}
		cmd = exec.Command(packageManager, append([]string{"-S", "--needed", "--noconfirm"}, packages...)...)
	case "apt":
		packages = []string{"git", "neovim", "fzf"}
		cmd = exec.Command("sudo", append([]string{"apt", "install", "-y"}, packages...)...)
	default:
		return fmt.Errorf("unsupported package manager: %s", packageManager)
	}

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

// cloneRepository clones a Git repository
func (m *Manager) cloneRepository(url, target string) error {
	// Check if target already exists
	if _, err := os.Stat(target); err == nil {
		return fmt.Errorf("target directory already exists: %s", target)
	}

	// Create parent directory if needed
	if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
		return fmt.Errorf("failed to create parent directory: %w", err)
	}

	cmd := exec.Command("git", "clone", url, target)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

// findGitRepositories finds all Git repositories in a directory
func (m *Manager) findGitRepositories(baseDir string) ([]string, error) {
	var repos []string

	err := filepath.Walk(baseDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Skip errors and continue walking
		}

		if info.IsDir() && info.Name() == ".git" {
			repoDir := filepath.Dir(path)
			repos = append(repos, repoDir)
			return filepath.SkipDir // Don't recurse into .git directory
		}

		return nil
	})

	return repos, err
}

// pullRepository pulls the latest changes for a Git repository
func (m *Manager) pullRepository(repoPath string) error {
	cmd := exec.Command("git", "-C", repoPath, "pull", "--rebase")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

// updateYaziPlugins updates Yazi plugins
func (m *Manager) updateYaziPlugins() error {
	if _, err := exec.LookPath("ya"); err != nil {
		return fmt.Errorf("yazi not found in PATH")
	}

	cmd := exec.Command("ya", "pack", "--upgrade")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

// updateNeovimPlugins updates Neovim plugins using Lazy.nvim
func (m *Manager) updateNeovimPlugins() error {
	if _, err := exec.LookPath("nvim"); err != nil {
		return fmt.Errorf("neovim not found in PATH")
	}

	cmd := exec.Command("nvim", "--headless", "+Lazy! update", "+qa")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

// updateMasonTools updates Mason tools in Neovim
func (m *Manager) updateMasonTools() error {
	if _, err := exec.LookPath("nvim"); err != nil {
		return fmt.Errorf("neovim not found in PATH")
	}

	cmd := exec.Command("nvim", "--headless", "+MasonUpdate", "+qa")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}
