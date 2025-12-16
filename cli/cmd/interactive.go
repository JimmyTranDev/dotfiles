package cmd

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/internal/config"
	"github.com/jimmy/dotfiles-cli/internal/ui"
)

// NewInteractiveMenuCmd creates an interactive menu command
func NewInteractiveMenuCmd(cfg *config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:    "interactive",
		Short:  "Interactive dotfiles management menu",
		Hidden: true, // Hide from help since it's the default
		RunE: func(cmd *cobra.Command, args []string) error {
			return runInteractiveMenu(cfg)
		},
	}
	return cmd
}

// MenuItem represents a menu item
type MenuItem struct {
	Key         string
	Description string
	Command     string
	SubItems    []MenuItem
}

// Main menu items
var mainMenuItems = []MenuItem{
	{
		Key:         "w",
		Description: ui.EmojiTree + " Worktree Management",
		Command:     "worktree",
		SubItems: []MenuItem{
			{Key: "c", Description: "Create new worktree", Command: "worktree create"},
			{Key: "l", Description: "List worktrees", Command: "worktree list"},
			{Key: "d", Description: "Delete worktree", Command: "worktree delete"},
			{Key: "x", Description: "Clean stale worktrees", Command: "worktree clean"},
		},
	},
	{
		Key:         "t",
		Description: ui.EmojiArt + " Theme Management",
		Command:     "theme",
		SubItems: []MenuItem{
			{Key: "s", Description: "Set application theme", Command: "theme set"},
			{Key: "l", Description: "List available themes", Command: "theme list"},
			{Key: "c", Description: "Show current theme", Command: "theme current"},
			{Key: "u", Description: "Set CLI UI theme", Command: "ui set-theme"},
		},
	},
	{
		Key:         "i",
		Description: ui.EmojiPackage + " Installation & Updates",
		Command:     "install",
	},
	{
		Key:         "s",
		Description: ui.EmojiCloud + " Storage Management",
		Command:     "storage",
		SubItems: []MenuItem{
			{Key: "i", Description: "Initialize secrets", Command: "storage init"},
			{Key: "s", Description: "Sync to cloud", Command: "storage sync"},
		},
	},
	{
		Key:         "q",
		Description: ui.EmojiExit + " Exit",
		Command:     "quit",
	},
}

func runInteractiveMenu(cfg *config.Config) error {
	for {
		// Clear screen and show header
		clearScreen()
		showHeader()

		// Show main menu
		if err := showMainMenu(); err != nil {
			return err
		}

		// Get user choice with Bubble Tea UI
		choice, err := selectMainMenuWithBubbleTea(mainMenuItems)
		if err != nil {
			if ui.IsQuitError(err) {
				fmt.Println()
				ui.Quit("Goodbye!")
				return nil
			}
			return err
		}

		// Process choice
		if err := processChoice(choice, cfg); err != nil {
			if err.Error() == "quit" || ui.IsQuitError(err) {
				fmt.Println()
				ui.Quit("Goodbye!")
				return nil
			}
			ui.Error("Error: " + err.Error())
			waitForUser()
			continue
		}

		waitForUser()
	}
}

func clearScreen() {
	// Clear screen command (works on Unix-like systems)
	cmd := exec.Command("clear")
	cmd.Stdout = os.Stdout
	cmd.Run()
}

func showHeader() {
	// Use Catppuccin theme colors for a beautiful header
	theme := ui.GetCurrentTheme()
	styles := theme.Styles()

	// Create a beautiful header using lipgloss
	headerText := `
╭─────────────────────────────────────────────╮
│           ` + ui.EmojiTool + `  Dotfiles Manager              │
│     Interactive Development Workflow       │
╰─────────────────────────────────────────────╯`

	fmt.Println(styles.Accent.Render(headerText))
	fmt.Println()
}

func showMainMenu() error {
	ui.Section("Main Menu:")
	fmt.Println()

	for _, item := range mainMenuItems {
		if item.Command == "quit" {
			fmt.Println()
		}
		ui.Option(item.Key, item.Description)
	}
	fmt.Println()
	return nil
}

func getUserInput(prompt string) (string, error) {
	color.Cyan(prompt)
	scanner := bufio.NewScanner(os.Stdin)
	if !scanner.Scan() {
		return "", fmt.Errorf("failed to read input")
	}
	return strings.ToLower(strings.TrimSpace(scanner.Text())), nil
}

// selectMainMenuWithBubbleTea provides main menu selection with Bubble Tea
func selectMainMenuWithBubbleTea(items []MenuItem) (string, error) {
	options := convertMenuItemsToUIOptions(items)
	return ui.RunSelection("Dotfiles Manager - Main Menu", options)
}

// convertMenuItemsToUIOptions converts menu items to UI selection options
func convertMenuItemsToUIOptions(items []MenuItem) []ui.SelectOption {
	options := make([]ui.SelectOption, 0, len(items))
	for _, item := range items {
		description := buildMenuItemDescription(item)
		title := cleanMenuItemTitle(item.Description)

		options = append(options, ui.SelectOption{
			Key:         item.Key,
			Title:       title,
			Description: description,
		})
	}
	return options
}

// buildMenuItemDescription creates appropriate description for menu items
func buildMenuItemDescription(item MenuItem) string {
	switch {
	case item.Command == "quit":
		return "Exit the dotfiles manager"
	case len(item.SubItems) > 0:
		subDescriptions := make([]string, len(item.SubItems))
		for i, subItem := range item.SubItems {
			subDescriptions[i] = subItem.Description
		}
		return fmt.Sprintf("%d options: %s", len(item.SubItems), strings.Join(subDescriptions, ", "))
	default:
		return fmt.Sprintf("Execute %s command", item.Command)
	}
}

// cleanMenuItemTitle removes emoji prefix from menu titles
func cleanMenuItemTitle(title string) string {
	// Find first space after emoji and return the rest
	if spaceIndex := strings.Index(title, " "); spaceIndex > 0 {
		return strings.TrimSpace(title[spaceIndex:])
	}
	return title
}

// selectSubMenuWithBubbleTea provides submenu selection with Bubble Tea
func selectSubMenuWithBubbleTea(parentItem MenuItem) (string, error) {
	options := convertSubMenuItemsToUIOptions(parentItem)
	title := cleanMenuItemTitle(parentItem.Description)
	return ui.RunSelection(title, options)
}

// convertSubMenuItemsToUIOptions converts submenu items to UI options
func convertSubMenuItemsToUIOptions(parentItem MenuItem) []ui.SelectOption {
	options := make([]ui.SelectOption, 0, len(parentItem.SubItems)+1)

	// Add submenu items
	for _, subItem := range parentItem.SubItems {
		options = append(options, ui.SelectOption{
			Key:         subItem.Key,
			Title:       subItem.Description,
			Description: fmt.Sprintf("Execute: %s", subItem.Command),
		})
	}

	// Add back navigation option
	options = append(options, ui.SelectOption{
		Key:         "b",
		Title:       "Back to Main Menu",
		Description: "Return to the main menu",
	})

	return options
}

func processChoice(choice string, cfg *config.Config) error {
	// Find matching menu item
	for _, item := range mainMenuItems {
		if item.Key == choice {
			if item.Command == "quit" {
				return fmt.Errorf("quit")
			}

			// If item has subitems, show submenu
			if len(item.SubItems) > 0 {
				return showSubMenu(item, cfg)
			}

			// Execute command directly
			return executeCommand(item.Command, cfg)
		}
	}

	return fmt.Errorf("invalid choice: %s", choice)
}

func showSubMenu(parentItem MenuItem, cfg *config.Config) error {
	for {
		clearScreen()
		showHeader()

		ui.Section(parentItem.Description)
		fmt.Println()

		for _, subItem := range parentItem.SubItems {
			ui.Option(subItem.Key, subItem.Description)
		}
		fmt.Println()

		theme := ui.GetCurrentTheme()
		styles := theme.Styles()
		backText := styles.Key.Render("[b]")
		backDesc := styles.Info.Render(ui.EmojiBackArrow + " Back to main menu")
		fmt.Printf("%s %s\n", backText, backDesc)
		fmt.Println()

		choice, err := selectSubMenuWithBubbleTea(parentItem)
		if err != nil {
			if ui.IsQuitError(err) {
				return ui.QuitError{Message: "quit"}
			}
			return err
		}

		if choice == "b" {
			return nil // Go back to main menu
		}

		// Find matching sub item
		for _, subItem := range parentItem.SubItems {
			if subItem.Key == choice {
				if err := executeCommand(subItem.Command, cfg); err != nil {
					ui.Error("Error: " + err.Error())
				}
				waitForUser()
				return nil // Return to main menu after command
			}
		}

		ui.Error("Invalid choice: " + choice)
		waitForUser()
	}
}

func executeCommand(commandStr string, cfg *config.Config) error {
	if commandStr == "" {
		return fmt.Errorf("empty command")
	}

	// Handle special interactive commands
	if handler := getInteractiveCommandHandler(commandStr, cfg); handler != nil {
		return handler()
	}

	// Execute standard commands
	return executeStandardCommand(commandStr)
}

// getInteractiveCommandHandler returns the appropriate handler for interactive commands
func getInteractiveCommandHandler(commandStr string, cfg *config.Config) func() error {
	handlers := map[string]func() error{
		"theme set":    func() error { return executeInteractiveThemeSet(cfg) },
		"storage sync": func() error { return executeInteractiveStorageSync(cfg) },
		"ui set-theme": func() error { return executeInteractiveUIThemeSet(cfg) },
	}
	return handlers[commandStr]
}

// executeStandardCommand executes standard CLI commands
func executeStandardCommand(commandStr string) error {
	parts := strings.Fields(commandStr)
	cmd := exec.Command("./dotfiles", parts...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

func executeInteractiveThemeSet(cfg *config.Config) error {
	// Use the interactive theme selection from theme.go which includes arrow keys
	selected, err := selectThemeInteractively(cfg.Themes.Available)
	if err != nil {
		return err
	}

	// Execute theme set command
	cmd := exec.Command("./dotfiles", "theme", "set", selected)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func executeInteractiveStorageSync(cfg *config.Config) error {
	// Create sync options for Bubble Tea
	options := []ui.SelectOption{
		{
			Key:         "1",
			Title:       "Dry Run",
			Description: "Preview changes without actually syncing files",
		},
		{
			Key:         "2",
			Title:       "Full Sync",
			Description: "Upload secrets to Backblaze B2 cloud storage",
		},
	}

	choice, err := ui.RunSelection("☁️ Storage Sync Options", options)
	if err != nil {
		if ui.IsQuitError(err) {
			ui.Info("Storage sync cancelled")
			return nil
		}
		return err
	}

	args := []string{"storage", "sync"}
	if choice == "1" {
		args = append(args, "--dry-run")
	}

	cmd := exec.Command("./dotfiles", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func waitForUser() {
	fmt.Println()
	ui.Help("Press Enter to continue (or 'q' to quit)...")
	scanner := bufio.NewScanner(os.Stdin)
	if scanner.Scan() {
		input := strings.TrimSpace(strings.ToLower(scanner.Text()))
		if input == "q" {
			ui.Quit("Goodbye!")
			os.Exit(0)
		}
	}
}

func executeInteractiveUIThemeSet(cfg *config.Config) error {
	// Create UI theme options
	options := []ui.SelectOption{
		{
			Key:         "1",
			Title:       "Mocha (Dark)",
			Description: "Dark theme with warm, cozy colors - perfect for evening coding",
		},
		{
			Key:         "2",
			Title:       "Macchiato (Dark)",
			Description: "Slightly lighter dark theme with softer contrast",
		},
		{
			Key:         "3",
			Title:       "Frappe (Dark)",
			Description: "Cool-toned dark theme with blue undertones",
		},
		{
			Key:         "4",
			Title:       "Latte (Light)",
			Description: "Light theme for daytime coding - easy on the eyes",
		},
	}

	choice, err := ui.RunSelection(ui.EmojiArt+" CLI Theme Selection", options)
	if err != nil {
		if ui.IsQuitError(err) {
			ui.Info("UI theme selection cancelled")
			return nil
		}
		return err
	}

	var selectedVariant ui.CatppuccinVariant
	switch choice {
	case "1":
		selectedVariant = ui.CatppuccinMocha
	case "2":
		selectedVariant = ui.CatppuccinMacchiato
	case "3":
		selectedVariant = ui.CatppuccinFrappe
	case "4":
		selectedVariant = ui.CatppuccinLatte
	default:
		return fmt.Errorf("invalid theme selection")
	}

	if err := ui.SetCurrentTheme(selectedVariant); err != nil {
		return fmt.Errorf("failed to set UI theme: %w", err)
	}

	ui.Success("CLI UI theme updated to " + string(selectedVariant))
	ui.Info("Theme will take effect on next CLI startup")
	return nil
}
