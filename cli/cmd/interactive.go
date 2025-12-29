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

// getExecutablePath returns the path to the current executable
// Falls back to "dotfiles" if os.Executable() fails (assuming it's in PATH)
func getExecutablePath() string {
	if execPath, err := os.Executable(); err == nil {
		return execPath
	}
	// Fallback to assuming dotfiles is in PATH
	return "dotfiles"
}

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
		Key:         "l",
		Description: ui.EmojiTool + " Link Management",
		Command:     "link",
		SubItems: []MenuItem{
			{Key: "c", Description: "Create dotfiles symlinks", Command: "link create"},
			{Key: "r", Description: "Remove dotfiles symlinks", Command: "link remove"},
			{Key: "v", Description: "Validate existing symlinks", Command: "link validate"},
		},
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
		result := processChoiceWithResult(choice, cfg)
		if result.err != nil {
			if result.err.Error() == "quit" || ui.IsQuitError(result.err) {
				color.Cyan("\n👋 Goodbye!")
				return nil
			}
			color.Red("Error: %v", result.err)
			if err := waitForUser(); err != nil {
				if ui.IsQuitError(err) {
					color.Cyan("\n👋 Goodbye!")
					return nil
				}
				return err
			}
			continue
		}

		// Only wait for user input if it wasn't a back navigation
		if !result.wasBackNavigation {
			if err := waitForUser(); err != nil {
				if ui.IsQuitError(err) {
					color.Cyan("\n👋 Goodbye!")
					return nil
				}
				return err
			}
		}
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

// choiceResult holds the result of processing a menu choice
type choiceResult struct {
	err               error
	wasBackNavigation bool
}

func processChoice(choice string, cfg *config.Config) error {
	result := processChoiceWithResult(choice, cfg)
	return result.err
}

func processChoiceWithResult(choice string, cfg *config.Config) choiceResult {
	// Find matching menu item
	for _, item := range mainMenuItems {
		if item.Key == choice {
			if item.Command == "quit" {
				return choiceResult{err: fmt.Errorf("quit"), wasBackNavigation: false}
			}

			// If item has subitems, show submenu
			if len(item.SubItems) > 0 {
				return showSubMenuWithResult(item, cfg)
			}

			// Execute command directly
			result := executeCommandWithResult(item.Command, cfg)
			ui.ShowTaskResult(result)
			return choiceResult{err: nil, wasBackNavigation: false}
		}
	}

	return choiceResult{err: fmt.Errorf("invalid choice: %s", choice), wasBackNavigation: false}
}

func showSubMenu(parentItem MenuItem, cfg *config.Config) error {
	result := showSubMenuWithResult(parentItem, cfg)
	return result.err
}

func showSubMenuWithResult(parentItem MenuItem, cfg *config.Config) choiceResult {
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
				return choiceResult{err: ui.QuitError{Message: "quit"}, wasBackNavigation: false}
			}
			return choiceResult{err: err, wasBackNavigation: false}
		}

		if choice == "b" {
			return choiceResult{err: nil, wasBackNavigation: true} // Go back to main menu - this is back navigation
		}

		// Find matching sub item
		for _, subItem := range parentItem.SubItems {
			if subItem.Key == choice {
				result := executeCommandWithResult(subItem.Command, cfg)
				ui.ShowTaskResult(result)
				waitForUser()
				return choiceResult{err: nil, wasBackNavigation: true} // Return to main menu after command - treat as back navigation to avoid double prompt
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

// executeCommandWithResult executes a command and returns a structured result
func executeCommandWithResult(commandStr string, cfg *config.Config) ui.TaskResult {
	if commandStr == "" {
		return ui.TaskResult{
			Title:   "Command Execution",
			Success: false,
			Message: "Empty command provided",
		}
	}

	// Handle special interactive commands with results
	if handler := getInteractiveCommandResultHandler(commandStr, cfg); handler != nil {
		return handler()
	}

	// Execute standard commands and capture result
	return executeStandardCommandWithResult(commandStr)
}

// getInteractiveCommandHandler returns the appropriate handler for interactive commands
func getInteractiveCommandHandler(commandStr string, cfg *config.Config) func() error {
	handlers := map[string]func() error{
		"storage sync": func() error { return executeInteractiveStorageSync(cfg) },
		"ui set-theme": func() error { return executeInteractiveUIThemeSet(cfg) },
	}
	return handlers[commandStr]
}

// getInteractiveCommandResultHandler returns handlers that provide structured results
func getInteractiveCommandResultHandler(commandStr string, cfg *config.Config) func() ui.TaskResult {
	handlers := map[string]func() ui.TaskResult{
		"storage sync": func() ui.TaskResult { return executeInteractiveStorageSyncWithResult(cfg) },
		"ui set-theme": func() ui.TaskResult { return executeInteractiveUIThemeSetWithResult(cfg) },
	}
	return handlers[commandStr]
}

// executeStandardCommand executes standard CLI commands
func executeStandardCommand(commandStr string) error {
	parts := strings.Fields(commandStr)
	cmd := exec.Command(getExecutablePath(), parts...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

// executeStandardCommandWithResult executes standard CLI commands and returns structured result
func executeStandardCommandWithResult(commandStr string) ui.TaskResult {
	parts := strings.Fields(commandStr)

	ui.TaskStart(fmt.Sprintf("Executing: %s", commandStr))

	cmd := exec.Command(getExecutablePath(), parts...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	err := cmd.Run()

	result := ui.TaskResult{
		Title: fmt.Sprintf("%s Command", strings.Title(parts[0])),
	}

	if err != nil {
		result.Success = false
		result.Message = fmt.Sprintf("Command failed: %v", err)
	} else {
		result.Success = true
		result.Message = "Command executed successfully"
		result.Details = []string{
			fmt.Sprintf("Executed: %s", commandStr),
			"Check output above for specific results",
		}
	}

	return result
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

	cmd := exec.Command(getExecutablePath(), args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func waitForUser() error {
	fmt.Println()
	ui.Help("Press Enter to continue (or 'q' to quit)...")
	scanner := bufio.NewScanner(os.Stdin)
	if scanner.Scan() {
		input := strings.TrimSpace(strings.ToLower(scanner.Text()))
		if input == "q" {
			ui.Quit("Goodbye!")
			return ui.QuitError{Message: "user requested quit"}
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("failed to read input: %w", err)
	}
	return nil
}

func executeInteractiveUIThemeSet(cfg *config.Config) error {
	ui.Info("CLI theme is fixed to Catppuccin Mocha")
	ui.Success("Theme: Catppuccin Mocha (Dark)")
	return nil
}

// executeInteractiveStorageSyncWithResult provides interactive storage sync with structured result
func executeInteractiveStorageSyncWithResult(cfg *config.Config) ui.TaskResult {
	ui.TaskStart("Interactive Storage Sync")

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
			return ui.TaskResult{
				Title:   "Storage Sync",
				Success: false,
				Message: "Storage sync cancelled by user",
			}
		}
		return ui.TaskResult{
			Title:   "Storage Sync",
			Success: false,
			Message: fmt.Sprintf("Sync option selection failed: %v", err),
		}
	}

	args := []string{"storage", "sync"}
	isDryRun := choice == "1"
	if isDryRun {
		args = append(args, "--dry-run")
	}

	cmd := exec.Command(getExecutablePath(), args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Run()

	if err != nil {
		return ui.TaskResult{
			Title:   "Storage Sync",
			Success: false,
			Message: fmt.Sprintf("Storage sync failed: %v", err),
		}
	}

	var details []string
	if isDryRun {
		details = []string{
			"Performed dry run - no files were actually synced",
			"Showed preview of changes that would be made",
			"Use full sync to upload files to cloud storage",
		}
	} else {
		details = []string{
			"Successfully synchronized secrets to Backblaze B2",
			"Files uploaded to cloud storage",
			"Backup completed successfully",
		}
	}

	return ui.TaskResult{
		Title:   "Cloud Storage Sync",
		Success: true,
		Message: fmt.Sprintf("Storage sync completed (%s)", map[bool]string{true: "dry run", false: "full sync"}[isDryRun]),
		Details: details,
	}
}

// executeInteractiveUIThemeSetWithResult provides interactive UI theme selection with structured result
func executeInteractiveUIThemeSetWithResult(cfg *config.Config) ui.TaskResult {
	return ui.TaskResult{
		Title:   "CLI UI Theme",
		Success: true,
		Message: "CLI theme is fixed to Catppuccin Mocha",
		Details: []string{
			"Theme: Catppuccin Mocha (Dark)",
			"Warm, cozy colors perfect for coding",
			"No configuration needed - always uses Mocha",
		},
	}
}
