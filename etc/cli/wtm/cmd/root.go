package cmd

import (
	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "wtm",
	Short: "Git Worktree Management CLI",
	Long: `A comprehensive CLI tool for managing git worktrees with JIRA integration.

Provides commands to create, checkout, delete, update, and manage git worktrees
across multiple repositories with advanced JIRA ticket integration.`,
	Version: "1.0.0",
}

func Execute() error {
	return rootCmd.Execute()
}

func init() {
	// Add all command implementations
	rootCmd.AddCommand(createCmd)
	rootCmd.AddCommand(checkoutCmd)
	rootCmd.AddCommand(deleteCmd)
	rootCmd.AddCommand(updateCmd)
	rootCmd.AddCommand(cleanCmd)
	rootCmd.AddCommand(renameCmd)
	rootCmd.AddCommand(moveCmd)
}
