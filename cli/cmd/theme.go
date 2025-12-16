package cmd

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"

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

// selectThemeInteractively provides interactive theme selection
func selectThemeInteractively(themes []string) (string, error) {
	// Try FZF first
	selected, err := selectThemeWithFZF(themes)
	if err == nil {
		return selected, nil
	}

	// Fallback to numbered selection
	return selectThemeWithNumbers(themes)
}

// selectThemeWithFZF uses FZF for theme selection
func selectThemeWithFZF(themes []string) (string, error) {
	// Check if fzf is available
	if _, err := exec.LookPath("fzf"); err != nil {
		return "", fmt.Errorf("fzf not available")
	}

	// Create preview for each theme
	var buf bytes.Buffer
	for _, theme := range themes {
		buf.WriteString(theme + "\n")
	}

	// Run FZF with preview
	cmd := exec.Command("fzf",
		"--prompt=Select theme: ",
		"--height=60%",
		"--border",
		"--reverse",
		"--preview=echo 'Theme: {}'; echo; echo 'This theme will be applied to:'; echo '  • Ghostty terminal'; echo '  • Zellij multiplexer'; echo '  • btop system monitor'; echo '  • FZF colors'")
	cmd.Stdin = strings.NewReader(buf.String())

	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("selection cancelled")
	}

	selected := strings.TrimSpace(output.String())
	if selected == "" {
		return "", fmt.Errorf("no theme selected")
	}

	return selected, nil
}

// selectThemeWithNumbers provides numbered theme selection
func selectThemeWithNumbers(themes []string) (string, error) {
	color.Yellow("Available themes:")
	fmt.Println()

	for i, theme := range themes {
		color.White("[%d] %s", i+1, theme)
	}
	fmt.Println()

	fmt.Print("Enter theme number (1-", len(themes), "): ")

	var input string
	if _, err := fmt.Scanln(&input); err != nil {
		return "", fmt.Errorf("failed to read input: %w", err)
	}

	selection, err := strconv.Atoi(strings.TrimSpace(input))
	if err != nil {
		return "", fmt.Errorf("invalid number: %s", input)
	}

	if selection < 1 || selection > len(themes) {
		return "", fmt.Errorf("selection out of range: %d (valid: 1-%d)", selection, len(themes))
	}

	return themes[selection-1], nil
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

				// Interactive selection using FZF or fallback
				selected, err := selectThemeInteractively(cfg.Themes.Available)
				if err != nil {
					return fmt.Errorf("theme selection cancelled: %w", err)
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

			color.Cyan("🔍 Interactive Project Selection")
			fmt.Println()

			// Always use interactive selection by default
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

// newUtilsKillPortCmd creates the utils kill-port command
func newUtilsKillPortCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "kill-port [port]",
		Short: "Kill processes running on a specific port",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			var port int
			var err error

			if len(args) == 1 {
				// Parse provided port number
				if port, err = strconv.Atoi(args[0]); err != nil {
					return fmt.Errorf("invalid port number: %s", args[0])
				}
			} else {
				// Interactive port selection
				color.Cyan("🔍 Interactive Port Killer")
				fmt.Println()

				// Show commonly used ports
				color.Yellow("Common ports:")
				commonPorts := map[string]int{
					"HTTP (dev server)": 3000,
					"HTTP alternative":  8000,
					"HTTPS alternative": 8443,
					"React dev server":  3000,
					"Next.js dev":       3000,
					"Vite dev server":   5173,
					"Express default":   3000,
					"Rails default":     3000,
					"Django default":    8000,
				}

				for desc, p := range commonPorts {
					color.White("  %d - %s", p, desc)
				}
				fmt.Println()

				// Prompt for port
				fmt.Print("Enter port number to kill: ")
				var input string
				if _, err := fmt.Scanln(&input); err != nil {
					return fmt.Errorf("failed to read input: %w", err)
				}

				if port, err = strconv.Atoi(strings.TrimSpace(input)); err != nil {
					return fmt.Errorf("invalid port number: %s", input)
				}
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
			color.Cyan("📊 Interactive CSV Commonness Score Sorter")
			fmt.Println()

			var filePath string
			if len(args) == 1 {
				filePath = args[0]
				interactive = false
			} else {
				// Always show interactive selection when no file provided
				interactive = true
				color.Yellow("🔍 Searching for CSV files in ranked words directories...")
			}

			// Create utils manager
			utilsManager := utils.NewManager(cfg)

			if err := utilsManager.SortCSV(filePath, interactive); err != nil {
				return fmt.Errorf("failed to sort CSV: %w", err)
			}

			color.Green("✓ CSV file sorted successfully!")
			color.Green("  Backup created with .backup extension")
			return nil
		},
	}

	cmd.Flags().BoolVarP(&interactive, "interactive", "i", false, "Use interactive file selection")
	return cmd
}
