package cmd

import (
	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/internal/config"
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
	cmd := &cobra.Command{
		Use:   "install",
		Short: "Run installation and update scripts",
		Long: `Run installation and update scripts for dotfiles setup.

Provides functionality for:
- Complete dotfiles installation for macOS/Linux
- Cloning essential repositories  
- Updating all repositories in Programming directory
- Updating development environment (Neovim plugins, Mason tools)`,
	}

	// Add subcommands
	cmd.AddCommand(newInstallRunCmd(cfg))
	cmd.AddCommand(newInstallListCmd(cfg))

	return cmd
}
