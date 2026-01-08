package cmd

import (
	"github.com/spf13/cobra"

	"github.com/jimmy/worktree-cli/internal/config"
)

// NewWorktreeCreateCmd creates the worktree create command
func NewWorktreeCreateCmd(cfg *config.Config) *cobra.Command {
	return newWorktreeCreateCmd(cfg)
}

// NewWorktreeListCmd creates the worktree list command
func NewWorktreeListCmd(cfg *config.Config) *cobra.Command {
	return newWorktreeListCmd(cfg)
}

// NewWorktreeDeleteCmd creates the worktree delete command
func NewWorktreeDeleteCmd(cfg *config.Config) *cobra.Command {
	return newWorktreeDeleteCmd(cfg)
}

// NewWorktreeCheckoutCmd creates the worktree checkout command
func NewWorktreeCheckoutCmd(cfg *config.Config) *cobra.Command {
	return newWorktreeCheckoutCmd(cfg)
}

// NewWorktreeCleanCmd creates the worktree clean command
func NewWorktreeCleanCmd(cfg *config.Config) *cobra.Command {
	return newWorktreeCleanCmd(cfg)
}
