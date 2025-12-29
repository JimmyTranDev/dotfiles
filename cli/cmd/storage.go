package cmd

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/internal/config"
	"github.com/jimmy/dotfiles-cli/internal/storage"
	"github.com/jimmy/dotfiles-cli/internal/ui"
)

// newStorageInitCmd creates the storage init command
func newStorageInitCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "init",
		Short: "Initialize secrets directory with template files",
		RunE: func(cmd *cobra.Command, args []string) error {
			thm := ui.DefaultTheme
			styles := thm.Styles()

			fmt.Println(styles.Accent.Render(ui.EmojiConfig + " Interactive Secrets Directory Initialization"))
			fmt.Println()

			secretsPath := fmt.Sprintf("%s/Programming/secrets", cfg.Directories.Home)
			fmt.Println(styles.AccentSecondary.Render("This will initialize the secrets directory at:"))
			fmt.Println(styles.Value.Render("  " + secretsPath))
			fmt.Println()

			fmt.Println(styles.AccentSecondary.Render("Template files that will be created:"))
			fmt.Println(styles.Value.Render("  • technical_links.json - For technical bookmarks"))
			fmt.Println(styles.Value.Render("  • useful_links.json - For useful resource links"))
			fmt.Println()

			// Confirmation prompt
			fmt.Print(styles.Help.Render("Continue with initialization? [Y/n]: "))
			var response string
			fmt.Scanln(&response)

			if strings.ToLower(strings.TrimSpace(response)) == "n" {
				fmt.Println(styles.Info.Render("Initialization cancelled"))
				return nil
			}

			fmt.Println(styles.Accent.Render(ui.EmojiConfig + " Initializing secrets directory..."))

			// Create storage manager
			storageManager := storage.NewManager(cfg)

			if err := storageManager.InitSecretsDirectory(); err != nil {
				return fmt.Errorf("failed to initialize secrets directory: %w", err)
			}

			fmt.Println(styles.Success.Render(ui.EmojiSuccess + " Secrets directory initialized successfully!"))
			fmt.Println()
			fmt.Println(styles.AccentSecondary.Render("Configuration Details:"))
			fmt.Println(styles.Value.Render("  • Location: " + secretsPath))
			fmt.Println(styles.Value.Render("  • Template files created: technical_links.json, useful_links.json"))
			fmt.Println(styles.Value.Render("  • Directory ready for secrets management"))
			fmt.Println(styles.Value.Render("  • You can now add your secrets and sync to cloud"))
			fmt.Println()
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
			thm := ui.DefaultTheme
			styles := thm.Styles()

			fmt.Println(styles.Accent.Render(ui.EmojiCloud + " Interactive Cloud Storage Sync"))
			fmt.Println()

			// Show sync details
			secretsPath := fmt.Sprintf("%s/Programming/secrets", cfg.Directories.Home)
			fmt.Println(styles.AccentSecondary.Render("Sync configuration:"))
			fmt.Println(styles.Value.Render("  • Source: " + secretsPath))
			fmt.Println(styles.Value.Render("  • Target: Backblaze B2 cloud storage"))
			fmt.Println(styles.Value.Render("  • Excludes: .m2/repository files"))
			fmt.Println()

			// If no dry-run flag provided, ask user
			if !cmd.Flags().Changed("dry-run") {
				fmt.Println(styles.AccentSecondary.Render("Sync mode options:"))
				fmt.Println(styles.Key.Render("[1]") + " " + styles.Value.Render("Dry run - Preview changes without syncing"))
				fmt.Println(styles.Key.Render("[2]") + " " + styles.Value.Render("Full sync - Upload files to cloud storage"))
				fmt.Println()

				fmt.Print(styles.Help.Render("Select sync mode [1/2]: "))
				var mode string
				fmt.Scanln(&mode)

				if strings.TrimSpace(mode) == "1" {
					dryRun = true
				}
			}

			if dryRun {
				fmt.Println(styles.Info.Render(ui.EmojiEye + " Dry run: Checking what would be synced..."))
			} else {
				fmt.Println(styles.Accent.Render(ui.EmojiCloud + " Syncing secrets to cloud storage..."))

				// Final confirmation for real sync
				fmt.Print(styles.Warning.Render("This will upload your secrets to cloud storage. Continue? [y/N]: "))
				var confirm string
				fmt.Scanln(&confirm)

				if strings.ToLower(strings.TrimSpace(confirm)) != "y" {
					fmt.Println(styles.Info.Render("Sync cancelled"))
					return nil
				}
			}

			// Create storage manager
			storageManager := storage.NewManager(cfg)

			// Validate credentials first
			if err := storageManager.ValidateB2Credentials(); err != nil {
				fmt.Println(styles.Error.Render(ui.EmojiError + " B2 credentials validation failed:"))
				fmt.Println(styles.Warning.Render("   Make sure these environment variables are set:"))
				fmt.Println(styles.Warning.Render("   - B2_BUCKET_NAME"))
				fmt.Println(styles.Warning.Render("   - B2_APPLICATION_KEY_ID"))
				fmt.Println(styles.Warning.Render("   - B2_APPLICATION_KEY"))
				return err
			}

			if err := storageManager.SyncSecrets(dryRun); err != nil {
				return fmt.Errorf("failed to sync secrets: %w", err)
			}

			if dryRun {
				fmt.Println(styles.Success.Render(ui.EmojiSuccess + " Dry run completed - no files were actually synced"))
				fmt.Println()
				fmt.Println(styles.AccentSecondary.Render("Summary:"))
				fmt.Println(styles.Value.Render("  • Preview mode - no actual file transfers"))
				fmt.Println(styles.Value.Render("  • Check output above for sync preview"))
				fmt.Println(styles.Value.Render("  • Use full sync to upload files"))
			} else {
				fmt.Println(styles.Success.Render(ui.EmojiSuccess + " Secrets synchronized successfully!"))
				fmt.Println()
				fmt.Println(styles.AccentSecondary.Render("Summary:"))
				fmt.Println(styles.Value.Render("  • Files uploaded to Backblaze B2"))
				fmt.Println(styles.Value.Render("  • Backup completed successfully"))
				fmt.Println(styles.Value.Render("  • Secrets are now stored in cloud"))
			}
			fmt.Println()
			return nil
		},
	}

	cmd.Flags().BoolVar(&dryRun, "dry-run", false, "Show what would be synced without actually syncing")
	return cmd
}
