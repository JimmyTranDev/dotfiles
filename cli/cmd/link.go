package cmd

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/internal/config"
	"github.com/jimmy/dotfiles-cli/internal/linking"
	"github.com/jimmy/dotfiles-cli/internal/ui"
)

// NewLinkCmd creates the link command
func NewLinkCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "link",
		Short: "Manage dotfiles symlinks",
		Long: `Manage symbolic links for your dotfiles configuration.

This command allows you to create, remove, and validate symlinks
for your dotfiles independently of the full installation process.`,
	}

	// Add subcommands
	cmd.AddCommand(newLinkCreateCmd(cfg))
	cmd.AddCommand(newLinkRemoveCmd(cfg))
	cmd.AddCommand(newLinkValidateCmd(cfg))

	return cmd
}

// newLinkCreateCmd creates the link create subcommand
func newLinkCreateCmd(cfg *config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "create",
		Short: "Create symlinks for dotfiles",
		Long: `Create symbolic links for your dotfiles configuration.

This will create symlinks for all default dotfiles mappings,
linking files from your dotfiles repository to their expected
locations in your home directory and ~/.config.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			linkManager := linking.NewManager(cfg)

			// Initialize theme for consistent styling
			theme := ui.DefaultTheme
			styles := theme.Styles()

			fmt.Println(styles.Accent.Render(ui.EmojiRocket + " Creating dotfiles symlinks..."))
			fmt.Println()

			if err := linkManager.CreateDefaultLinks(); err != nil {
				return fmt.Errorf("failed to create symlinks: %w", err)
			}

			fmt.Println()
			fmt.Println(styles.Success.Render(ui.EmojiSuccess + " Symlinks created successfully!"))

			return nil
		},
	}
}

// newLinkRemoveCmd creates the link remove subcommand
func newLinkRemoveCmd(cfg *config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "remove",
		Short: "Remove symlinks for dotfiles",
		Long: `Remove symbolic links for your dotfiles configuration.

This will remove all symlinks created by the link create command,
effectively unlinking your dotfiles from their target locations.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			linkManager := linking.NewManager(cfg)

			// Initialize theme for consistent styling
			theme := ui.DefaultTheme
			styles := theme.Styles()

			// Confirmation prompt
			fmt.Print(styles.Help.Render("Remove all dotfiles symlinks? This cannot be undone. [y/N]: "))
			var response string
			fmt.Scanln(&response)

			response = strings.ToLower(strings.TrimSpace(response))
			if response != "y" {
				fmt.Println(styles.Info.Render(ui.EmojiWave + " Operation cancelled"))
				return nil
			}

			fmt.Println()
			fmt.Println(styles.Accent.Render(ui.EmojiExit + " Removing dotfiles symlinks..."))
			fmt.Println()

			if err := linkManager.RemoveDefaultLinks(); err != nil {
				return fmt.Errorf("failed to remove symlinks: %w", err)
			}

			fmt.Println()
			fmt.Println(styles.Success.Render(ui.EmojiSuccess + " Symlinks removed successfully!"))

			return nil
		},
	}
}

// newLinkValidateCmd creates the link validate subcommand
func newLinkValidateCmd(cfg *config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "validate",
		Short: "Validate existing symlinks",
		Long: `Validate the current state of dotfiles symlinks.

This command checks all expected symlinks to ensure they exist
and point to the correct source files. It will report any
missing or broken links.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			linkManager := linking.NewManager(cfg)

			// Initialize theme for consistent styling
			theme := ui.DefaultTheme
			styles := theme.Styles()

			fmt.Println(styles.Accent.Render(ui.EmojiEye + " Validating dotfiles symlinks..."))
			fmt.Println()

			validLinks, brokenLinks, err := linkManager.ValidateDefaultLinks()
			if err != nil {
				return fmt.Errorf("failed to validate symlinks: %w", err)
			}

			// Display results
			fmt.Println(styles.AccentSecondary.Render("📋 Validation Results:"))
			fmt.Printf("  %s Valid links: %d\n", styles.Success.Render("✓"), len(validLinks))
			fmt.Printf("  %s Broken links: %d\n", styles.Error.Render("✗"), len(brokenLinks))
			fmt.Println()

			if len(validLinks) > 0 {
				fmt.Println(styles.Success.Render("Valid Links:"))
				for _, link := range validLinks {
					fmt.Printf("  %s %s\n", styles.Success.Render("✓"), link)
				}
				fmt.Println()
			}

			if len(brokenLinks) > 0 {
				fmt.Println(styles.Error.Render("Broken/Missing Links:"))
				for _, link := range brokenLinks {
					fmt.Printf("  %s %s\n", styles.Error.Render("✗"), link)
				}
				fmt.Println()

				fmt.Println(styles.Help.Render("💡 To fix broken links, run: dotfiles link create"))
				return fmt.Errorf("found %d broken links", len(brokenLinks))
			}

			fmt.Println(styles.Success.Render(ui.EmojiSuccess + " All symlinks are valid!"))

			return nil
		},
	}
}
