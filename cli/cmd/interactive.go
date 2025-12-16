package cmd

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/internal/config"
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

		// Get user choice with arrow key support
		choice, err := getUserInputWithArrows("Select an option: ", mainMenuItems)
		if err != nil {
			return err
		}

		// Process choice
		if err := processChoice(choice, cfg); err != nil {
			if err.Error() == "quit" {
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

// getUserInputWithArrows provides arrow key navigation for menu selection
func getUserInputWithArrows(prompt string, items []MenuItem) (string, error) {
	// Try arrow key navigation first
	selected, err := selectMenuItemWithArrows(items)
	if err == nil {
		return selected, nil
	}

	// Fallback to regular input
	return getUserInput(prompt)
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

		// Create sub items with back option
		subItemsWithBack := append(parentItem.SubItems, MenuItem{Key: "b", Description: "← Back to main menu", Command: "back"})

		choice, err := selectSubMenuWithArrows(parentItem, subItemsWithBack)
		if err != nil {
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

// selectMenuItemWithArrows provides arrow key navigation for menu items
func selectMenuItemWithArrows(items []MenuItem) (string, error) {
	// Disable input buffering to read single characters
	if err := disableInputBuffering(); err != nil {
		return "", fmt.Errorf("arrow navigation not available")
	}
	defer enableInputBuffering()

	selectedIndex := 0

	for {
		// Clear screen and show menu
		clearScreen()
		showHeader()

		color.Yellow("📋 Main Menu:")
		color.Cyan("Use ↑/↓ arrow keys to navigate, Enter to select, q to quit")
		fmt.Println()

		// Display menu items with highlight
		for i, item := range items {
			if i == selectedIndex {
				// Highlighted item
				if item.Command == "quit" {
					fmt.Println()
					color.Green("→ [%s] %s", item.Key, item.Description)
				} else {
					color.Green("→ [%s] %s", item.Key, item.Description)
				}
			} else {
				// Normal item
				if item.Command == "quit" {
					fmt.Println()
					color.White("[%s] %s", item.Key, item.Description)
				} else {
					color.White("[%s] %s", item.Key, item.Description)
				}
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
					if selectedIndex < len(items)-1 {
						selectedIndex++
					}
				}
			}
		case 13, 10: // Enter
			return items[selectedIndex].Key, nil
		case 'q', 'Q':
			return "q", nil
		default:
			// Check if the character matches any menu key
			char_str := strings.ToLower(string(char))
			for _, item := range items {
				if item.Key == char_str {
					return item.Key, nil
				}
			}
		}
	}
}

// selectSubMenuWithArrows provides arrow key navigation for submenu items
func selectSubMenuWithArrows(parentItem MenuItem, items []MenuItem) (string, error) {
	// Try arrow key navigation first
	if err := disableInputBuffering(); err != nil {
		// Fallback to regular input
		choice, err := getUserInput("Select an option: ")
		return choice, err
	}
	defer enableInputBuffering()

	selectedIndex := 0

	for {
		clearScreen()
		showHeader()

		color.Yellow("📋 %s", parentItem.Description)
		color.Cyan("Use ↑/↓ arrow keys to navigate, Enter to select, q to quit")
		fmt.Println()

		// Display submenu items with highlight
		for i, item := range items {
			if i == selectedIndex {
				// Highlighted item
				if item.Command == "back" {
					fmt.Println()
					color.Green("→ [%s] %s", item.Key, item.Description)
				} else {
					color.Green("→ [%s] %s", item.Key, item.Description)
				}
			} else {
				// Normal item
				if item.Command == "back" {
					fmt.Println()
					color.White("[%s] %s", item.Key, item.Description)
				} else {
					color.White("[%s] %s", item.Key, item.Description)
				}
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
					if selectedIndex < len(items)-1 {
						selectedIndex++
					}
				}
			}
		case 13, 10: // Enter
			return items[selectedIndex].Key, nil
		case 'q', 'Q':
			return "b", nil // Go back on 'q'
		default:
			// Check if the character matches any menu key
			char_str := strings.ToLower(string(char))
			for _, item := range items {
				if item.Key == char_str {
					return item.Key, nil
				}
			}
		}
	}
}

func executeCommand(commandStr string, cfg *config.Config) error {
	parts := strings.Fields(commandStr)
	if len(parts) == 0 {
		return fmt.Errorf("empty command")
	}

	// Handle special commands that need interactive input
	switch commandStr {
	case "theme set":
		return executeInteractiveThemeSet(cfg)
	case "storage sync":
		// Add dry-run prompt
		return executeInteractiveStorageSync(cfg)
	}

	// Execute the command using the CLI
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
	color.Yellow("Storage sync options:")
	color.White("[1] Dry run (preview changes)")
	color.White("[2] Full sync")
	fmt.Println()

	choice, err := getUserInput("Select sync mode: ")
	if err != nil {
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

func selectWithFZF(items []string, prompt string) (string, error) {
	// Check if fzf is available
	if _, err := exec.LookPath("fzf"); err != nil {
		return "", fmt.Errorf("fzf not available")
	}

	// Prepare input for FZF
	input := strings.Join(items, "\n")

	// Run FZF
	cmd := exec.Command("fzf", "--prompt="+prompt, "--height=40%", "--reverse")
	cmd.Stdin = strings.NewReader(input)

	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("selection cancelled")
	}

	selected := strings.TrimSpace(output.String())
	if selected == "" {
		return "", fmt.Errorf("no selection made")
	}

	return selected, nil
}

func selectWithNumbers(items []string, title string) (string, error) {
	fmt.Printf("\n%s:\n", title)
	for i, item := range items {
		color.White("[%d] %s", i+1, item)
	}
	fmt.Println()

	choice, err := getUserInput(fmt.Sprintf("Enter number (1-%d): ", len(items)))
	if err != nil {
		return "", err
	}

	index, err := strconv.Atoi(choice)
	if err != nil {
		return "", fmt.Errorf("invalid number: %s", choice)
	}

	if index < 1 || index > len(items) {
		return "", fmt.Errorf("choice out of range: %d", index)
	}

	return items[index-1], nil
}

func waitForUser() {
	color.Cyan("\nPress Enter to continue...")
	bufio.NewReader(os.Stdin).ReadLine()
}
