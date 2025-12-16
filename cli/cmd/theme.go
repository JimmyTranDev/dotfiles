package cmd

import (
	"context"
	"fmt"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/internal/config"
	"github.com/jimmy/dotfiles-cli/internal/domain"
	"github.com/jimmy/dotfiles-cli/internal/project"
	"github.com/jimmy/dotfiles-cli/internal/theme"
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
