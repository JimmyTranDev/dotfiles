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
		Description: "🌳 Worktree Management",
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
		Description: "🎨 Theme Management",
		Command:     "theme",
		SubItems: []MenuItem{
			{Key: "s", Description: "Set theme", Command: "theme set"},
			{Key: "l", Description: "List themes", Command: "theme list"},
			{Key: "c", Description: "Show current theme", Command: "theme current"},
		},
	},
	{
		Key:         "i",
		Description: "📦 Installation & Updates",
		Command:     "install",
	},
	{
		Key:         "s",
		Description: "☁️ Storage Management",
		Command:     "storage",
		SubItems: []MenuItem{
			{Key: "i", Description: "Initialize secrets", Command: "storage init"},
			{Key: "s", Description: "Sync to cloud", Command: "storage sync"},
		},
	},
	{
		Key:         "q",
		Description: "❌ Exit",
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
				color.Cyan("\n👋 Goodbye!")
				return nil
			}
			return err
		}

		// Process choice
		if err := processChoice(choice, cfg); err != nil {
			if err.Error() == "quit" || ui.IsQuitError(err) {
				color.Cyan("\n👋 Goodbye!")
				return nil
			}
			color.Red("Error: %v", err)
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
	color.Cyan("╭─────────────────────────────────────────────╮")
	color.Cyan("│           🛠️  Dotfiles Manager              │")
	color.Cyan("│     Interactive Development Workflow       │")
	color.Cyan("╰─────────────────────────────────────────────╯")
	fmt.Println()
}

func showMainMenu() error {
	color.Yellow("📋 Main Menu:")
	fmt.Println()

	for _, item := range mainMenuItems {
		if item.Command == "quit" {
			fmt.Println()
		}
		color.White("[%s] %s", item.Key, item.Description)
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

		color.Yellow("📋 %s", parentItem.Description)
		fmt.Println()

		for _, subItem := range parentItem.SubItems {
			color.White("[%s] %s", subItem.Key, subItem.Description)
		}
		fmt.Println()
		color.White("[b] ← Back to main menu")
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
					color.Red("Error: %v", err)
				}
				waitForUser()
				return nil // Return to main menu after command
			}
		}

		color.Red("Invalid choice: %s", choice)
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
			color.Cyan("👋 Storage sync cancelled")
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
	color.Cyan("\nPress Enter to continue (or 'q' to quit)...")
	scanner := bufio.NewScanner(os.Stdin)
	if scanner.Scan() {
		input := strings.TrimSpace(strings.ToLower(scanner.Text()))
		if input == "q" {
			color.Cyan("👋 Goodbye!")
			os.Exit(0)
		}
	}
}
