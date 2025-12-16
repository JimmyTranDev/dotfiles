package cmd

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/internal/config"
	"github.com/jimmy/dotfiles-cli/internal/install"
	"github.com/jimmy/dotfiles-cli/internal/ui"
)

// NewWorktreeCmd creates the worktree command
func NewWorktreeCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "worktree",
		Short: "Manage Git worktrees",
		Long: `Manage Git worktrees for your repositories.

Worktrees allow you to have multiple working directories for a single Git repository,
each with different branches checked out. This is useful for:
- Working on multiple features simultaneously
- Testing different branches
- Code review workflows`,
	}

	// Add subcommands
	cmd.AddCommand(newWorktreeCreateCmd(cfg))
	cmd.AddCommand(newWorktreeListCmd(cfg))
	cmd.AddCommand(newWorktreeDeleteCmd(cfg))
	cmd.AddCommand(newWorktreeCleanCmd(cfg))

	return cmd
}

// NewThemeCmd creates the theme command
func NewThemeCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "theme",
		Short: "Manage themes across applications",
		Long: `Manage and switch themes across multiple applications.

Supports switching themes for:
- Ghostty terminal
- Zellij multiplexer
- btop system monitor
- And more...`,
	}

	// Add subcommands
	cmd.AddCommand(newThemeSetCmd(cfg))
	cmd.AddCommand(newThemeListCmd(cfg))
	cmd.AddCommand(newThemeCurrentCmd(cfg))

	return cmd
}

// NewStorageCmd creates the storage command
func NewStorageCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "storage",
		Short: "Manage cloud storage and secrets",
		Long: `Manage cloud storage operations and secrets backup.

Provides functionality for:
- Initializing secrets directory with template files
- Syncing secrets to Backblaze B2 cloud storage
- Managing backup operations`,
	}

	// Add subcommands
	cmd.AddCommand(newStorageInitCmd(cfg))
	cmd.AddCommand(newStorageSyncCmd(cfg))

	return cmd
}

// NewInstallCmd creates the install command
func NewInstallCmd(cfg *config.Config) *cobra.Command {
	var targetDir string

	cmd := &cobra.Command{
		Use:   "install [install-type]",
		Short: "Run installation and update scripts",
		Long: `Run installation and update scripts for dotfiles setup.

Available install types:
- full: Complete dotfiles setup for macOS/Linux
- clone-repos: Clone essential repositories
- fetch-all: Pull latest changes for all repositories  
- update: Update Neovim plugins, Mason tools, and dotfiles

If no install type is provided, interactive selection is shown.`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			// Create install manager
			installManager := install.NewManager(cfg)

			// Validate environment
			if err := installManager.ValidateEnvironment(); err != nil {
				color.Red("❌ Environment validation failed:")
				color.Yellow("   %v", err)
				return err
			}

			var installType install.InstallType

			// If no install type provided, show interactive selection
			if len(args) == 0 {
				color.Cyan("🚀 Interactive Installation Selection")
				fmt.Println()

				// Show system info
				systemInfo := installManager.GetSystemInfo()
				color.Yellow("System Information:")
				for key, value := range systemInfo {
					color.White("  • %s: %s", key, value)
				}
				fmt.Println()

				// Get available options
				options := installManager.GetInstallOptions()

				// Interactive selection using Bubble Tea
				selectedOption, err := selectInstallOptionInteractively(options)
				if err != nil {
					if ui.IsQuitError(err) {
						color.Cyan("👋 Installation cancelled")
						return nil
					}
					return fmt.Errorf("install option selection failed: %w", err)
				}
				installType = selectedOption.Type

				color.Green("✓ Selected: %s", selectedOption.Name)
				fmt.Println()

				// Confirmation prompt
				fmt.Print("Continue with installation? [Y/n/q]: ")
				var response string
				fmt.Scanln(&response)

				response = strings.ToLower(strings.TrimSpace(response))
				if response == "n" || response == "q" {
					color.Cyan("👋 Installation cancelled")
					return nil
				}
			} else {
				// Parse provided install type
				installType = install.InstallType(args[0])
			}

			color.Cyan("🚀 Running installation: %s", installType)

			// Run installation
			if err := installManager.RunInstall(installType, targetDir); err != nil {
				return fmt.Errorf("installation failed: %w", err)
			}

			return nil
		},
	}

	cmd.Flags().StringVar(&targetDir, "target", "", "Target directory for fetch-all operation")
	return cmd
}

// selectInstallOptionInteractively provides interactive install option selection
func selectInstallOptionInteractively(options []install.InstallOption) (*install.InstallOption, error) {
	// Convert options to UI options
	var uiOptions []ui.SelectOption
	for i, option := range options {
		uiOptions = append(uiOptions, ui.SelectOption{
			Key:         fmt.Sprintf("%d", i+1),
			Title:       option.Name,
			Description: option.Description,
		})
	}

	// Use Bubble Tea selection
	selected, err := ui.RunSelection("📦 Installation & Updates", uiOptions)
	if err != nil {
		return nil, err
	}

	// Convert back to install option
	selectedIndex, err := strconv.Atoi(selected)
	if err != nil || selectedIndex < 1 || selectedIndex > len(options) {
		return nil, fmt.Errorf("invalid selection")
	}

	return &options[selectedIndex-1], nil
}
