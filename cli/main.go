package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/jimmy/worktree-cli/cmd"
	"github.com/jimmy/worktree-cli/internal/config"
	"github.com/jimmy/worktree-cli/internal/ui"
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
		Use:   "worktree",
		Short: "Git worktree management CLI",
		Long: `A CLI tool for managing Git worktrees.

Worktrees allow you to have multiple working directories for a single Git repository,
each with different branches checked out. This is useful for:
- Working on multiple features simultaneously
- Testing different branches
- Code review workflows`,
		Version: fmt.Sprintf("%s (commit: %s, built: %s)", version, commit, date),
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			if !cfg.UI.ColorEnabled {
				color.NoColor = true
			}
		},
		RunE: func(c *cobra.Command, args []string) error {
			// Show interactive menu when run with no arguments
			return runInteractiveMode(c, cfg)
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
	rootCmd.AddCommand(cmd.NewWorktreeCreateCmd(cfg))
	rootCmd.AddCommand(cmd.NewWorktreeListCmd(cfg))
	rootCmd.AddCommand(cmd.NewWorktreeDeleteCmd(cfg))
	rootCmd.AddCommand(cmd.NewWorktreeCleanCmd(cfg))

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
  Run 'worktree' with no arguments to see available commands
  Most commands support interactive prompts when arguments are omitted
  Press 'q', 'esc', or 'ctrl+c' to quit anytime during interactive mode

Examples:
  worktree create                  # Interactive worktree creation
  worktree create my-feature       # Create worktree for 'my-feature' branch
  worktree list                    # List all existing worktrees
  worktree delete                  # Interactively delete a worktree
  worktree clean                   # Clean up stale worktree references
  
{{if .HasAvailableSubCommands}}Use "{{.CommandPath}} [command] --help" for more information about a command.{{end}}
`
}

// runInteractiveMode displays an interactive menu for command selection
func runInteractiveMode(rootCmd *cobra.Command, cfg *config.Config) error {
	options := []ui.SelectOption{
		{
			Key:         "c",
			Title:       "Create worktree",
			Description: "Create a new worktree for development",
		},
		{
			Key:         "l",
			Title:       "List worktrees",
			Description: "Show all existing worktrees",
		},
		{
			Key:         "d",
			Title:       "Delete worktree",
			Description: "Remove a worktree",
		},
		{
			Key:         "k",
			Title:       "Clean worktrees",
			Description: "Clean up stale worktree references",
		},
		{
			Key:         "h",
			Title:       "Help",
			Description: "Show help information",
		},
	}

	selected, err := ui.RunSelection("Select a command:", options)
	if err != nil {
		if ui.IsQuitError(err) {
			// User quit the selection, just exit gracefully
			return nil
		}
		return err
	}

	// Execute the selected command
	switch selected {
	case "c":
		createCmd := cmd.NewWorktreeCreateCmd(cfg)
		return createCmd.Execute()
	case "l":
		listCmd := cmd.NewWorktreeListCmd(cfg)
		return listCmd.Execute()
	case "d":
		deleteCmd := cmd.NewWorktreeDeleteCmd(cfg)
		return deleteCmd.Execute()
	case "k":
		cleanCmd := cmd.NewWorktreeCleanCmd(cfg)
		return cleanCmd.Execute()
	case "h":
		return rootCmd.Help()
	default:
		return fmt.Errorf("unknown selection: %s", selected)
	}
}
