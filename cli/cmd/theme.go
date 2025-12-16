package cmd

import (
	"context"
	"fmt"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/internal/config"
	"github.com/jimmy/dotfiles-cli/internal/domain"
	"github.com/jimmy/dotfiles-cli/internal/project"
	"github.com/jimmy/dotfiles-cli/internal/storage"
	"github.com/jimmy/dotfiles-cli/internal/theme"
	"github.com/jimmy/dotfiles-cli/internal/utils"
)

// getPackageIcon returns an emoji icon for the given package type
func getPackageIcon(packageType domain.PackageType) string {
	switch packageType {
	case domain.PackageTypeNpm:
		return "📦"
	case domain.PackageTypePnpm:
		return "⚡"
	case domain.PackageTypeYarn:
		return "🧶"
	case domain.PackageTypeGo:
		return "🐹"
	case domain.PackageTypeCargo:
		return "🦀"
	case domain.PackageTypePython:
		return "🐍"
	default:
		return "📁"
	}
}

// newThemeSetCmd creates the theme set command
func newThemeSetCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "set [theme-name]",
		Short: "Set the current theme",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			themeName := args[0]
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

// newProjectListCmd creates the project list command
func newProjectListCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "list",
		Short: "List development projects",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := context.Background()

			// Create project manager
			projectManager := project.NewManager(cfg)

			color.Cyan("📂 Discovering development projects...")
			projects, err := projectManager.ListProjects(ctx)
			if err != nil {
				return fmt.Errorf("failed to list projects: %w", err)
			}

			if len(projects) == 0 {
				color.Yellow("No projects found in %s", cfg.Directories.Programming)
				return nil
			}

			color.Green("\n✓ Found %d projects:\n", len(projects))

			for _, proj := range projects {
				packageIcon := getPackageIcon(proj.PackageType)
				worktreeCount := len(proj.Worktrees)

				fmt.Printf("%s %s\n", packageIcon, color.CyanString(proj.Name))
				fmt.Printf("  📁 %s\n", proj.Path)
				if worktreeCount > 0 {
					fmt.Printf("  🌳 %d worktrees\n", worktreeCount)
				}
				fmt.Printf("  🕒 Last used: %s\n", proj.LastUsed.Format("2006-01-02 15:04"))
				fmt.Println()
			}

			return nil
		},
	}
	return cmd
}

// newProjectSelectCmd creates the project select command
func newProjectSelectCmd(cfg *config.Config) *cobra.Command {
	var createSymlink bool
	var suffix string
	var nonInteractive bool

	cmd := &cobra.Command{
		Use:   "select",
		Short: "Select and open a project",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := context.Background()

			// Create project manager
			projectManager := project.NewManager(cfg)

			color.Cyan("🔍 Selecting project...")

			// Use interactive project selection (unless --no-interactive flag is set)
			project, err := projectManager.SelectProject(ctx, !nonInteractive)
			if err != nil {
				return fmt.Errorf("failed to select project: %w", err)
			}

			color.Green("✓ Selected project: %s", project.Name)
			fmt.Printf("📁 Path: %s\n", project.Path)

			// Create symlink if requested
			if createSymlink {
				if suffix == "" {
					suffix = "actx"
				}

				color.Cyan("🔗 Creating symlink with suffix: %s", suffix)
				if err := projectManager.CreateSymlink(project, suffix); err != nil {
					return fmt.Errorf("failed to create symlink: %w", err)
				}

				symlinkPath := fmt.Sprintf("%s-%s", project.Name, suffix)
				color.Green("✓ Symlink created: %s", symlinkPath)
			}

			// Update last selection
			if err := projectManager.SyncProjects(ctx); err != nil {
				color.Yellow("⚠ Failed to update project cache: %v", err)
			}

			return nil
		},
	}

	cmd.Flags().BoolVarP(&createSymlink, "symlink", "s", false, "Create symlink with suffix")
	cmd.Flags().StringVar(&suffix, "suffix", "actx", "Suffix for symlink creation")
	cmd.Flags().BoolVar(&nonInteractive, "no-interactive", false, "Skip interactive selection, use most recent project")

	return cmd
}

// newProjectSyncCmd creates the project sync command
func newProjectSyncCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "sync",
		Short: "Sync project metadata",
		RunE: func(cmd *cobra.Command, args []string) error {
			color.Cyan("🔄 Syncing projects:")
			// TODO: Implement project sync logic
			color.Yellow("Project sync not yet implemented")
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
			color.Cyan("🔧 Initializing secrets directory...")

			// Create storage manager
			storageManager := storage.NewManager(cfg)

			if err := storageManager.InitSecretsDirectory(); err != nil {
				return fmt.Errorf("failed to initialize secrets directory: %w", err)
			}

			color.Green("✓ Secrets directory initialized successfully!")
			color.Green("  Location: %s/Programming/secrets", cfg.Directories.Home)
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
			if dryRun {
				color.Cyan("🔍 Dry run: Checking what would be synced...")
			} else {
				color.Cyan("☁️ Syncing secrets to cloud storage...")
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

// newUtilsKillPortCmd creates the utils kill-port command
func newUtilsKillPortCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "kill-port <port>",
		Short: "Kill processes running on a specific port",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			// Parse port number
			port := 0
			if _, err := fmt.Sscanf(args[0], "%d", &port); err != nil {
				return fmt.Errorf("invalid port number: %s", args[0])
			}

			if port <= 0 || port > 65535 {
				return fmt.Errorf("port must be between 1 and 65535, got: %d", port)
			}

			color.Cyan("🔪 Killing processes on port %d...", port)

			// Create utils manager
			utilsManager := utils.NewManager(cfg)

			if err := utilsManager.KillPort(port); err != nil {
				return fmt.Errorf("failed to kill port %d: %w", port, err)
			}

			color.Green("✓ Successfully killed processes on port %d", port)
			return nil
		},
	}
	return cmd
}

// newUtilsCSVSortCmd creates the utils csv-sort command
func newUtilsCSVSortCmd(cfg *config.Config) *cobra.Command {
	var interactive bool

	cmd := &cobra.Command{
		Use:   "csv-sort [file-path]",
		Short: "Sort CSV files by commonness score",
		Long: `Sort CSV files by commonness score (highest first).

The script expects CSV files with 'word' and 'commonness_score' columns.
If no file path is provided, interactive selection is used.`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			color.Cyan("📊 CSV Commonness Score Sorter")

			var filePath string
			if len(args) == 1 {
				filePath = args[0]
				interactive = false
			} else {
				interactive = true
			}

			// Create utils manager
			utilsManager := utils.NewManager(cfg)

			if err := utilsManager.SortCSV(filePath, interactive); err != nil {
				return fmt.Errorf("failed to sort CSV: %w", err)
			}

			color.Green("✓ CSV file sorted successfully!")
			return nil
		},
	}

	cmd.Flags().BoolVarP(&interactive, "interactive", "i", false, "Use interactive file selection")
	return cmd
}
