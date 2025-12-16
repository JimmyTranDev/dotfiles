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
		SubItems: []MenuItem{
			{Key: "r", Description: "Run installation script", Command: "install run"},
			{Key: "l", Description: "List install options", Command: "install list"},
		},
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

		// Get user choice
		choice, err := getUserInput("Select an option: ")
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

		choice, err := getUserInput("Select an option: ")
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
	// Get available themes using fzf or numbered selection
	themes := []string{"catppuccin-mocha", "catppuccin-frappe", "catppuccin-latte", "catppuccin-macchiato"}

	selected, err := selectWithFZF(themes, "Select theme: ")
	if err != nil {
		// Fallback to numbered selection
		selected, err = selectWithNumbers(themes, "Select theme")
		if err != nil {
			return err
		}
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
