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
		RunE: func(c *cobra.Command, args []string) error {
			// If no subcommand provided, show interactive menu
			return cmd.NewInteractiveMenuCmd(cfg).RunE(c, args)
		},
	}

	// Add global flags
	rootCmd.PersistentFlags().Bool("no-color", false, "Disable colored output")
	rootCmd.PersistentFlags().BoolP("verbose", "v", false, "Verbose output")

	// Add subcommands
	rootCmd.AddCommand(cmd.NewWorktreeCmd(cfg))
	rootCmd.AddCommand(cmd.NewThemeCmd(cfg))
	rootCmd.AddCommand(cmd.NewStorageCmd(cfg))
	rootCmd.AddCommand(cmd.NewInstallCmd(cfg))
	rootCmd.AddCommand(cmd.NewInteractiveMenuCmd(cfg))

	// Add interactive examples to help
	rootCmd.SetUsageTemplate(`Usage:{{if .Runnable}}
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

Examples:
  dotfiles theme set           # Interactive theme selection
  dotfiles worktree create     # Interactive worktree creation
  dotfiles install             # Interactive installation selection
  dotfiles storage sync        # Interactive sync options
  
{{if .HasAvailableSubCommands}}Use "{{.CommandPath}} [command] --help" for more information about a command.{{end}}
`)

	// Execute command
	if err := rootCmd.ExecuteContext(ctx); err != nil {
		color.Red("Error: %v", err)
		os.Exit(1)
	}
}
