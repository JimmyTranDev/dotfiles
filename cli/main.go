package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/cmd"
	"github.com/jimmy/dotfiles-cli/internal/config"
)

var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		color.Red("Error loading configuration: %v", err)
		os.Exit(1)
	}

	// Validate configuration
	if err := cfg.Validate(); err != nil {
		color.Red("Configuration validation failed: %v", err)
		os.Exit(1)
	}

	// Create root command
	rootCmd := &cobra.Command{
		Use:   "dotfiles",
		Short: "Dotfiles management CLI",
		Long: `A unified CLI tool for managing dotfiles, Git worktrees, themes, and development workflow.

This tool consolidates the functionality from various shell scripts into a single,
maintainable Go CLI with improved error handling and user experience.`,
		Version: fmt.Sprintf("%s (commit: %s, built: %s)", version, commit, date),
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			// Disable color output if requested
			if !cfg.UI.ColorEnabled {
				color.NoColor = true
			}
		},
	}

	// Add global flags
	rootCmd.PersistentFlags().Bool("no-color", false, "Disable colored output")
	rootCmd.PersistentFlags().BoolP("verbose", "v", false, "Verbose output")

	// Add subcommands
	rootCmd.AddCommand(cmd.NewWorktreeCmd(cfg))
	rootCmd.AddCommand(cmd.NewThemeCmd(cfg))
	rootCmd.AddCommand(cmd.NewProjectCmd(cfg))

	// Execute command
	if err := rootCmd.ExecuteContext(ctx); err != nil {
		color.Red("Error: %v", err)
		os.Exit(1)
	}
}
