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

// setupRootCommand adds subcommands and usage template to the root command
func setupRootCommand(rootCmd *cobra.Command, cfg *config.Config) {
	// Add subcommands
	rootCmd.AddCommand(cmd.NewWorktreeCreateCmd(cfg))
	rootCmd.AddCommand(cmd.NewWorktreeCheckoutCmd(cfg))
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
  All commands are fully interactive with guided prompts and selections
  Press 'q', 'esc', or 'ctrl+c' to quit anytime during interactive mode

Examples:
  worktree create                  # Interactive worktree creation
  worktree checkout                # Interactive checkout of remote branch  
  worktree list                    # List all existing worktrees
  worktree delete                  # Interactively delete a worktree
  worktree clean                   # Clean up stale worktree references
  
{{if .HasAvailableSubCommands}}Use "{{.CommandPath}} [command] --help" for more information about a command.{{end}}
`
}

// runInteractiveMode displays an interactive menu for command selection
func runInteractiveMode(rootCmd *cobra.Command, cfg *config.Config) error {
	fzfOptions := []ui.FzfOption{
		{
			Value:   "c",
			Display: "create      Create a new worktree for development",
		},
		{
			Value:   "o",
			Display: "checkout    Checkout existing remote branch as worktree",
		},
		{
			Value:   "l",
			Display: "list        Show all existing worktrees",
		},
		{
			Value:   "d",
			Display: "delete      Remove a worktree",
		},
		{
			Value:   "k",
			Display: "clean       Clean up stale worktree references",
		},
		{
			Value:   "h",
			Display: "help        Show help information",
		},
	}

	config := ui.FzfConfig{
		Prompt: "Select a command",
		Header: "Worktree Management Tool",
		Height: "40%",
		NoSort: true,
	}

	ctx := context.Background()
	selected, err := ui.RunFzfSingle(ctx, fzfOptions, config)
	if err != nil {
		return fmt.Errorf("command selection failed: %w", err)
	}

	if selected == "" {
		return nil // User cancelled
	}

	// Execute the selected command
	switch selected {
	case "c":
		createCmd := cmd.NewWorktreeCreateCmd(cfg)
		return createCmd.Execute()
	case "o":
		checkoutCmd := cmd.NewWorktreeCheckoutCmd(cfg)
		return checkoutCmd.Execute()
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
