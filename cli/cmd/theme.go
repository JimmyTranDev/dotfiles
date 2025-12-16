package cmd

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/internal/config"
	"github.com/jimmy/dotfiles-cli/internal/storage"
	"github.com/jimmy/dotfiles-cli/internal/theme"
	"github.com/jimmy/dotfiles-cli/internal/ui"
)

// selectThemeInteractively provides interactive theme selection
func selectThemeInteractively(themes []string) (string, error) {
	// Convert themes to UI options
	var options []ui.SelectOption
	for i, theme := range themes {
		description := fmt.Sprintf("Apply %s theme to Ghostty, Zellij, btop, and FZF", theme)

		options = append(options, ui.SelectOption{
			Key:         fmt.Sprintf("%d", i+1),
			Title:       theme,
			Description: description,
		})
	}

	// Use Bubble Tea selection
	selected, err := ui.RunSelection("🎨 Theme Selection", options)
	if err != nil {
		return "", err
	}

	// Convert back to theme name
	selectedIndex, err := strconv.Atoi(selected)
	if err != nil || selectedIndex < 1 || selectedIndex > len(themes) {
		return "", fmt.Errorf("invalid selection")
	}

	return themes[selectedIndex-1], nil
}

// newThemeSetCmd creates the theme set command
func newThemeSetCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "set [theme-name]",
		Short: "Set the current theme",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			var themeName string

			// If no theme provided, show interactive selection
			if len(args) == 0 {
				color.Cyan("🎨 Interactive Theme Selection")
				fmt.Println()

				// Show current theme
				color.Yellow("Current theme: %s", cfg.Themes.Current)
				fmt.Println()

				// Interactive selection using Bubble Tea
				selected, err := selectThemeInteractively(cfg.Themes.Available)
				if err != nil {
					if ui.IsQuitError(err) {
						color.Cyan("👋 Theme selection cancelled")
						return nil
					}
					return err
				}
				themeName = selected
			} else {
				themeName = args[0]
			}

			color.Cyan("🎨 Setting theme to: %s", themeName)

			// Create theme manager and apply theme
			themeManager := theme.NewManager(cfg)
			if err := themeManager.SetTheme(themeName); err != nil {
				return fmt.Errorf("failed to set theme: %w", err)
			}

			color.Green("✓ Theme set successfully!")
			color.Green("  Applied to: Ghostty, Zellij, btop, and FZF colors")
			return nil
		},
	}
	return cmd
}

// newThemeListCmd creates the theme list command
func newThemeListCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "list",
		Short: "List available themes",
		RunE: func(cmd *cobra.Command, args []string) error {
			color.Cyan("📋 Available themes:")
			for _, theme := range cfg.Themes.Available {
				if theme == cfg.Themes.Current {
					color.Green("→ %s (current)", theme)
				} else {
					fmt.Printf("  %s\n", theme)
				}
			}
			return nil
		},
	}
	return cmd
}

// newThemeCurrentCmd creates the theme current command
func newThemeCurrentCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "current",
		Short: "Show current theme",
		RunE: func(cmd *cobra.Command, args []string) error {
			color.Cyan("Current theme: %s", cfg.Themes.Current)
			return nil
		},
	}
	return cmd
}

// newStorageInitCmd creates the storage init command
func newStorageInitCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "init",
		Short: "Initialize secrets directory with template files",
		RunE: func(cmd *cobra.Command, args []string) error {
			color.Cyan("🔧 Interactive Secrets Directory Initialization")
			fmt.Println()

			secretsPath := fmt.Sprintf("%s/Programming/secrets", cfg.Directories.Home)
			color.Yellow("This will initialize the secrets directory at:")
			color.White("  %s", secretsPath)
			fmt.Println()

			color.Yellow("Template files that will be created:")
			color.White("  • technical_links.json - For technical bookmarks")
			color.White("  • useful_links.json - For useful resource links")
			fmt.Println()

			// Confirmation prompt
			fmt.Print("Continue with initialization? [Y/n]: ")
			var response string
			fmt.Scanln(&response)

			if strings.ToLower(strings.TrimSpace(response)) == "n" {
				color.Yellow("Initialization cancelled")
				return nil
			}

			color.Cyan("🔧 Initializing secrets directory...")

			// Create storage manager
			storageManager := storage.NewManager(cfg)

			if err := storageManager.InitSecretsDirectory(); err != nil {
				return fmt.Errorf("failed to initialize secrets directory: %w", err)
			}

			color.Green("✓ Secrets directory initialized successfully!")
			color.Green("  Location: %s", secretsPath)
			color.Green("  Template files: technical_links.json, useful_links.json")
			return nil
		},
	}
	return cmd
}

// newStorageSyncCmd creates the storage sync command
func newStorageSyncCmd(cfg *config.Config) *cobra.Command {
	var dryRun bool

	cmd := &cobra.Command{
		Use:   "sync",
		Short: "Sync secrets to cloud storage using B2",
		Long: `Sync secrets directory to Backblaze B2 cloud storage.

Requires the following environment variables:
- B2_BUCKET_NAME: Backblaze B2 bucket name
- B2_APPLICATION_KEY_ID: Backblaze B2 application key ID
- B2_APPLICATION_KEY: Backblaze B2 application key

Also requires the 'b2' CLI tool to be installed:
pip install b2`,
		RunE: func(cmd *cobra.Command, args []string) error {
			color.Cyan("☁️ Interactive Cloud Storage Sync")
			fmt.Println()

			// Show sync details
			secretsPath := fmt.Sprintf("%s/Programming/secrets", cfg.Directories.Home)
			color.Yellow("Sync configuration:")
			color.White("  • Source: %s", secretsPath)
			color.White("  • Target: Backblaze B2 cloud storage")
			color.White("  • Excludes: .m2/repository files")
			fmt.Println()

			// If no dry-run flag provided, ask user
			if !cmd.Flags().Changed("dry-run") {
				color.Yellow("Sync mode options:")
				color.White("[1] Dry run - Preview changes without syncing")
				color.White("[2] Full sync - Upload files to cloud storage")
				fmt.Println()

				fmt.Print("Select sync mode [1/2]: ")
				var mode string
				fmt.Scanln(&mode)

				if strings.TrimSpace(mode) == "1" {
					dryRun = true
				}
			}

			if dryRun {
				color.Cyan("🔍 Dry run: Checking what would be synced...")
			} else {
				color.Cyan("☁️ Syncing secrets to cloud storage...")

				// Final confirmation for real sync
				fmt.Print("This will upload your secrets to cloud storage. Continue? [y/N]: ")
				var confirm string
				fmt.Scanln(&confirm)

				if strings.ToLower(strings.TrimSpace(confirm)) != "y" {
					color.Yellow("Sync cancelled")
					return nil
				}
			}

			// Create storage manager
			storageManager := storage.NewManager(cfg)

			// Validate credentials first
			if err := storageManager.ValidateB2Credentials(); err != nil {
				color.Red("❌ B2 credentials validation failed:")
				color.Yellow("   Make sure these environment variables are set:")
				color.Yellow("   - B2_BUCKET_NAME")
				color.Yellow("   - B2_APPLICATION_KEY_ID")
				color.Yellow("   - B2_APPLICATION_KEY")
				return err
			}

			if err := storageManager.SyncSecrets(dryRun); err != nil {
				return fmt.Errorf("failed to sync secrets: %w", err)
			}

			if dryRun {
				color.Green("✓ Dry run completed - no files were actually synced")
			} else {
				color.Green("✓ Secrets synchronized successfully!")
			}
			return nil
		},
	}

	cmd.Flags().BoolVar(&dryRun, "dry-run", false, "Show what would be synced without actually syncing")
	return cmd
}
