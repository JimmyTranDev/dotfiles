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

// NewProjectCmd creates the project command
func NewProjectCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "project",
		Short: "Manage development projects",
		Long: `Manage development projects and repositories.

Find, select, and work with your development projects across multiple directories.`,
	}

	// Add subcommands
	cmd.AddCommand(newProjectListCmd(cfg))
	cmd.AddCommand(newProjectSelectCmd(cfg))
	cmd.AddCommand(newProjectSyncCmd(cfg))

	return cmd
}
