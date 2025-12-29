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
