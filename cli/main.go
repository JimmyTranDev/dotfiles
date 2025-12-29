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
	if err := run(); err != nil {
		// Import the theme for consistent error styling
		// Note: We'll keep this simple for now since main.go should be minimal
		fmt.Fprintf(os.Stderr, "❌ Error: %v\n", err)
		os.Exit(1)
	}
}

// run contains the main application logic
func run() error {
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	// Load and validate configuration
	cfg, err := loadConfig()
	if err != nil {
		return err
	}

	// Create and execute root command
	rootCmd := createRootCommand(cfg)
	return rootCmd.ExecuteContext(ctx)
}

// loadConfig loads and validates the application configuration
func loadConfig() (*config.Config, error) {
	cfg, err := config.Load()
	if err != nil {
		return nil, fmt.Errorf("loading configuration: %w", err)
	}

	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("configuration validation: %w", err)
	}

	return cfg, nil
}

// createRootCommand creates the root cobra command with all subcommands
func createRootCommand(cfg *config.Config) *cobra.Command {
	rootCmd := &cobra.Command{
		Use:   "dotfiles",
		Short: "Dotfiles management CLI",
		Long: `A unified CLI tool for managing dotfiles, Git worktrees, and development workflow.

This tool consolidates the functionality from various shell scripts into a single,
maintainable Go CLI with improved error handling and user experience.`,
		Version: fmt.Sprintf("%s (commit: %s, built: %s)", version, commit, date),
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			if !cfg.UI.ColorEnabled {
				color.NoColor = true
			}
		},
		RunE: func(c *cobra.Command, args []string) error {
			return cmd.NewInteractiveMenuCmd(cfg).RunE(c, args)
		},
	}

	// Add remaining setup and return the command
	setupRootCommand(rootCmd, cfg)
	return rootCmd
}

// setupRootCommand adds flags, subcommands, and usage template to the root command
func setupRootCommand(rootCmd *cobra.Command, cfg *config.Config) {
	// Add global flags
	rootCmd.PersistentFlags().Bool("no-color", false, "Disable colored output")
	rootCmd.PersistentFlags().BoolP("verbose", "v", false, "Verbose output")

	// Add subcommands
	rootCmd.AddCommand(cmd.NewWorktreeCmd(cfg))
	rootCmd.AddCommand(cmd.NewStorageCmd(cfg))
	rootCmd.AddCommand(cmd.NewLinkCmd(cfg))
	rootCmd.AddCommand(cmd.NewInteractiveMenuCmd(cfg))

	// Set custom usage template
	rootCmd.SetUsageTemplate(getUsageTemplate())
}

// getUsageTemplate returns the custom usage template for the CLI
func getUsageTemplate() string {
	return `Usage:{{if .Runnable}}
  {{.UseLine}}{{end}}{{if .HasAvailableSubCommands}}
  {{.CommandPath}} [command]{{end}}{{if gt (len .Aliases) 0}}

Aliases:
  {{.NameAndAliases}}{{end}}{{if .HasExample}}

Examples:
{{.Example}}{{end}}{{if .HasAvailableSubCommands}}

Available Commands:{{range .Commands}}{{if (or .IsAvailableCommand (eq .Name "help"))}}
  {{rpad .Name .NamePadding }} {{.Short}}{{end}}{{end}}{{end}}{{if .HasAvailableLocalFlags}}

Flags:
{{.LocalFlags.FlagUsages | trimTrailingWhitespaces}}{{end}}{{if .HasAvailableInheritedFlags}}

Global Flags:
{{.InheritedFlags.FlagUsages | trimTrailingWhitespaces}}{{end}}{{if .HasHelpSubCommands}}

Additional help topics:{{range .Commands}}{{if .IsAdditionalHelpTopicCommand}}
  {{rpad .Name .NamePadding }} {{.Short}}{{end}}{{end}}{{end}}

Interactive Mode:
  Run 'dotfiles' with no arguments to enter interactive mode
  Most commands support interactive prompts when arguments are omitted
  Press 'q', 'esc', or 'ctrl+c' to quit anytime during interactive mode

Examples:
  dotfiles worktree create     # Interactive worktree creation
  dotfiles link create         # Create dotfiles symlinks
  dotfiles link validate       # Validate existing symlinks
  dotfiles storage sync        # Interactive sync options
  
{{if .HasAvailableSubCommands}}Use "{{.CommandPath}} [command] --help" for more information about a command.{{end}}
`
}
