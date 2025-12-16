package cmd

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"unsafe"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/internal/config"
	"github.com/jimmy/dotfiles-cli/internal/storage"
	"github.com/jimmy/dotfiles-cli/internal/theme"
)

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

// selectThemeWithNumbers provides arrow key navigation for theme selection
func selectThemeWithNumbers(themes []string) (string, error) {
	return selectThemeWithArrows(themes)
}

// selectThemeWithArrows provides arrow key navigation with Enter to select for themes
func selectThemeWithArrows(themes []string) (string, error) {
	// Disable input buffering to read single characters
	if err := disableInputBuffering(); err != nil {
		// Fallback to numbered selection if terminal setup fails
		return selectThemeWithNumbersFallback(themes)
	}
	defer enableInputBuffering()

	selectedIndex := 0

	for {
		// Clear screen and show menu
		clearScreen()
		color.Cyan("🎨 Select Theme")
		color.Yellow("Use ↑/↓ arrow keys to navigate, Enter to select, q to quit")
		fmt.Println()

		// Display themes with highlight
		for i, theme := range themes {
			if i == selectedIndex {
				// Highlighted theme
				color.Green("→ %s", theme)
			} else {
				// Normal theme
				color.White("  %s", theme)
			}
		}
		fmt.Println()

		// Read single character
		char, err := readChar()
		if err != nil {
			return "", fmt.Errorf("failed to read input: %w", err)
		}

		switch char {
		case 27: // ESC sequence start
			// Read the rest of the arrow key sequence
			char2, _ := readChar()
			if char2 == 91 { // '['
				char3, _ := readChar()
				switch char3 {
				case 65: // Up arrow
					if selectedIndex > 0 {
						selectedIndex--
					}
				case 66: // Down arrow
					if selectedIndex < len(themes)-1 {
						selectedIndex++
					}
				}
			}
		case 13, 10: // Enter
			return themes[selectedIndex], nil
		case 'q', 'Q':
			return "", fmt.Errorf("selection cancelled")
		case '1', '2', '3', '4', '5', '6', '7', '8', '9':
			// Allow direct number selection as well
			num := int(char - '0')
			if num <= len(themes) {
				selectedIndex = num - 1
				return themes[selectedIndex], nil
			}
		}
	}
}

// selectThemeWithNumbersFallback provides numbered selection fallback for themes
func selectThemeWithNumbersFallback(themes []string) (string, error) {
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

// Terminal manipulation for arrow key navigation
const (
	tcgets = 0x5401
	tcsets = 0x5402
)

type termios struct {
	Iflag  uint32
	Oflag  uint32
	Cflag  uint32
	Lflag  uint32
	Cc     [20]uint8
	Ispeed uint32
	Ospeed uint32
}

var originalTermios *termios

// disableInputBuffering disables input buffering for raw character input
func disableInputBuffering() error {
	fd := int(os.Stdin.Fd())

	// Get current terminal settings
	originalTermios = &termios{}
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, uintptr(fd), tcgets, uintptr(unsafe.Pointer(originalTermios)))
	if errno != 0 {
		return fmt.Errorf("failed to get terminal attributes: %v", errno)
	}

	// Copy settings for modification
	newTermios := *originalTermios

	// Disable canonical mode and echo
	newTermios.Lflag &^= (syscall.ICANON | syscall.ECHO)

	// Set new terminal settings
	_, _, errno = syscall.Syscall(syscall.SYS_IOCTL, uintptr(fd), tcsets, uintptr(unsafe.Pointer(&newTermios)))
	if errno != 0 {
		return fmt.Errorf("failed to set terminal attributes: %v", errno)
	}

	return nil
}

// enableInputBuffering restores original terminal settings
func enableInputBuffering() {
	if originalTermios != nil {
		fd := int(os.Stdin.Fd())
		syscall.Syscall(syscall.SYS_IOCTL, uintptr(fd), tcsets, uintptr(unsafe.Pointer(originalTermios)))
	}
}

// readChar reads a single character from stdin
func readChar() (byte, error) {
	var buf [1]byte
	n, err := os.Stdin.Read(buf[:])
	if err != nil {
		return 0, err
	}
	if n == 0 {
		return 0, fmt.Errorf("no input")
	}
	return buf[0], nil
}
