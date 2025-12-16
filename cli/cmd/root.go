package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/internal/config"
	"github.com/jimmy/dotfiles-cli/internal/install"
)

// NewWorktreeCmd creates the worktree command
func NewWorktreeCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "worktree",
		Short: "Manage Git worktrees",
		Long: `Manage Git worktrees for your repositories.

Worktrees allow you to have multiple working directories for a single Git repository,
each with different branches checked out. This is useful for:
- Working on multiple features simultaneously
- Testing different branches
- Code review workflows`,
	}

	// Add subcommands
	cmd.AddCommand(newWorktreeCreateCmd(cfg))
	cmd.AddCommand(newWorktreeListCmd(cfg))
	cmd.AddCommand(newWorktreeDeleteCmd(cfg))
	cmd.AddCommand(newWorktreeCleanCmd(cfg))

	return cmd
}

// NewThemeCmd creates the theme command
func NewThemeCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "theme",
		Short: "Manage themes across applications",
		Long: `Manage and switch themes across multiple applications.

Supports switching themes for:
- Ghostty terminal
- Zellij multiplexer
- btop system monitor
- And more...`,
	}

	// Add subcommands
	cmd.AddCommand(newThemeSetCmd(cfg))
	cmd.AddCommand(newThemeListCmd(cfg))
	cmd.AddCommand(newThemeCurrentCmd(cfg))

	return cmd
}

// NewStorageCmd creates the storage command
func NewStorageCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "storage",
		Short: "Manage cloud storage and secrets",
		Long: `Manage cloud storage operations and secrets backup.

Provides functionality for:
- Initializing secrets directory with template files
- Syncing secrets to Backblaze B2 cloud storage
- Managing backup operations`,
	}

	// Add subcommands
	cmd.AddCommand(newStorageInitCmd(cfg))
	cmd.AddCommand(newStorageSyncCmd(cfg))

	return cmd
}

// NewInstallCmd creates the install command
func NewInstallCmd(cfg *config.Config) *cobra.Command {
	var targetDir string

	cmd := &cobra.Command{
		Use:   "install [install-type]",
		Short: "Run installation and update scripts",
		Long: `Run installation and update scripts for dotfiles setup.

Available install types:
- full: Complete dotfiles setup for macOS/Linux
- clone-repos: Clone essential repositories
- fetch-all: Pull latest changes for all repositories  
- update: Update Neovim plugins, Mason tools, and dotfiles

If no install type is provided, interactive selection is shown.`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			// Create install manager
			installManager := install.NewManager(cfg)

			// Validate environment
			if err := installManager.ValidateEnvironment(); err != nil {
				color.Red("❌ Environment validation failed:")
				color.Yellow("   %v", err)
				return err
			}

			var installType install.InstallType

			// If no install type provided, show interactive selection
			if len(args) == 0 {
				color.Cyan("🚀 Interactive Installation Selection")
				fmt.Println()

				// Show system info
				systemInfo := installManager.GetSystemInfo()
				color.Yellow("System Information:")
				for key, value := range systemInfo {
					color.White("  • %s: %s", key, value)
				}
				fmt.Println()

				// Get available options
				options := installManager.GetInstallOptions()

				// Interactive selection using FZF or fallback
				selectedOption, err := selectInstallOptionInteractively(options)
				if err != nil {
					return fmt.Errorf("install option selection cancelled: %w", err)
				}
				installType = selectedOption.Type

				color.Green("✓ Selected: %s", selectedOption.Name)
				fmt.Println()

				// Confirmation prompt
				fmt.Print("Continue with installation? [Y/n]: ")
				var response string
				fmt.Scanln(&response)

				if strings.ToLower(strings.TrimSpace(response)) == "n" {
					color.Yellow("Installation cancelled")
					return nil
				}
			} else {
				// Parse provided install type
				installType = install.InstallType(args[0])
			}

			color.Cyan("🚀 Running installation: %s", installType)

			// Run installation
			if err := installManager.RunInstall(installType, targetDir); err != nil {
				return fmt.Errorf("installation failed: %w", err)
			}

			return nil
		},
	}

	cmd.Flags().StringVar(&targetDir, "target", "", "Target directory for fetch-all operation")
	return cmd
}

// selectInstallOptionInteractively provides interactive install option selection
func selectInstallOptionInteractively(options []install.InstallOption) (*install.InstallOption, error) {
	// Try FZF first
	selected, err := selectInstallOptionWithFZF(options)
	if err == nil {
		return selected, nil
	}

	// Fallback to arrow key selection
	return selectInstallOptionWithArrows(options)
}

// selectInstallOptionWithFZF uses FZF for install option selection
func selectInstallOptionWithFZF(options []install.InstallOption) (*install.InstallOption, error) {
	// Check if fzf is available
	if _, err := exec.LookPath("fzf"); err != nil {
		return nil, fmt.Errorf("fzf not available")
	}

	// Create preview for each option
	var buf strings.Builder
	for _, option := range options {
		buf.WriteString(fmt.Sprintf("%s: %s\n", option.Name, option.Description))
	}

	// Run FZF with preview
	cmd := exec.Command("fzf",
		"--prompt=Select install option: ",
		"--height=60%",
		"--border",
		"--reverse",
		"--delimiter=:",
		"--preview=echo 'Install Option: {1}'; echo; echo 'Description:'; echo '  {2}'")
	cmd.Stdin = strings.NewReader(buf.String())

	var output strings.Builder
	cmd.Stdout = &output
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("selection cancelled")
	}

	selected := strings.TrimSpace(output.String())
	if selected == "" {
		return nil, fmt.Errorf("no install option selected")
	}

	// Find the selected option
	selectedName := strings.Split(selected, ":")[0]
	for _, option := range options {
		if option.Name == selectedName {
			return &option, nil
		}
	}

	return nil, fmt.Errorf("invalid selection: %s", selected)
}

// selectInstallOptionWithArrows provides arrow key navigation for install option selection
func selectInstallOptionWithArrows(options []install.InstallOption) (*install.InstallOption, error) {
	// Disable input buffering to read single characters
	if err := disableInputBuffering(); err != nil {
		// Fallback to numbered selection if terminal setup fails
		return selectInstallOptionWithNumbersFallback(options)
	}
	defer enableInputBuffering()

	selectedIndex := 0

	for {
		// Clear screen and show menu
		clearScreen()
		color.Cyan("🚀 Select Installation Option")
		color.Yellow("Use ↑/↓ arrow keys to navigate, Enter to select, q to quit")
		fmt.Println()

		// Display options with highlight
		for i, option := range options {
			if i == selectedIndex {
				// Highlighted option
				color.Green("→ %s", option.Name)
				color.Cyan("  %s", option.Description)
			} else {
				// Normal option
				color.White("  %s", option.Name)
				color.White("  %s", option.Description)
			}
			fmt.Println()
		}

		// Read single character
		char, err := readChar()
		if err != nil {
			return nil, fmt.Errorf("failed to read input: %w", err)
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
					if selectedIndex < len(options)-1 {
						selectedIndex++
					}
				}
			}
		case 13, 10: // Enter
			return &options[selectedIndex], nil
		case 'q', 'Q':
			return nil, fmt.Errorf("selection cancelled")
		case '1', '2', '3', '4', '5', '6', '7', '8', '9':
			// Allow direct number selection as well
			num := int(char - '0')
			if num <= len(options) {
				selectedIndex = num - 1
				return &options[selectedIndex], nil
			}
		}
	}
}

// selectInstallOptionWithNumbersFallback provides numbered selection fallback
func selectInstallOptionWithNumbersFallback(options []install.InstallOption) (*install.InstallOption, error) {
	color.Yellow("Available install options:")
	fmt.Println()

	for i, option := range options {
		color.White("[%d] %s", i+1, option.Name)
		color.Cyan("    %s", option.Description)
		fmt.Println()
	}

	fmt.Print("Enter install option number (1-", len(options), "): ")

	var input string
	if _, err := fmt.Scanln(&input); err != nil {
		return nil, fmt.Errorf("failed to read input: %w", err)
	}

	selection, err := strconv.Atoi(strings.TrimSpace(input))
	if err != nil {
		return nil, fmt.Errorf("invalid number: %s", input)
	}

	if selection < 1 || selection > len(options) {
		return nil, fmt.Errorf("selection out of range: %d (valid: 1-%d)", selection, len(options))
	}

	return &options[selection-1], nil
}
