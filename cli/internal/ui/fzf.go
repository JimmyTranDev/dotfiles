package ui

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// FzfConfig holds configuration for fzf selection
type FzfConfig struct {
	Prompt      string   // Prompt text
	Header      string   // Header text
	Multi       bool     // Allow multiple selection
	NoSort      bool     // Disable sorting
	Height      string   // Height (e.g., "40%", "20")
	Preview     string   // Preview command
	Options     []string // Additional fzf options
	Placeholder string   // Placeholder text for input
}

// FzfOption represents an option for fzf selection
type FzfOption struct {
	Value   string // The actual value to return
	Display string // What to display to the user
}

// FzfResult holds the result of fzf selection
type FzfResult struct {
	Selected []string // Selected values
	Query    string   // Final query text
	ExitCode int      // Exit code from fzf
}

// checkFzfAvailable verifies if fzf is installed and available
func checkFzfAvailable() error {
	if _, err := exec.LookPath("fzf"); err != nil {
		return fmt.Errorf("fzf is not installed or not in PATH. Please install fzf first")
	}
	return nil
}

// isTTY checks if we're running in an interactive terminal
func isTTY() bool {
	// Check if stdout is connected to a terminal
	fileInfo, err := os.Stdout.Stat()
	if err != nil {
		return false
	}
	return (fileInfo.Mode() & os.ModeCharDevice) != 0
}

// RunFzf runs fzf with the given options and returns the selected items
func RunFzf(ctx context.Context, options []FzfOption, config FzfConfig) (*FzfResult, error) {
	if err := checkFzfAvailable(); err != nil {
		return nil, err
	}

	// Check if we're in a TTY environment
	if !isTTY() {
		return nil, fmt.Errorf("fzf requires an interactive terminal")
	}

	// Build fzf command args
	args := []string{}

	// Add basic options
	if config.Prompt != "" {
		args = append(args, "--prompt", config.Prompt+" > ")
	}
	if config.Header != "" {
		args = append(args, "--header", config.Header)
	}
	if config.Multi {
		args = append(args, "--multi")
	}
	if config.NoSort {
		args = append(args, "--no-sort")
	}
	if config.Height != "" {
		args = append(args, "--height", config.Height)
	} else {
		args = append(args, "--height", "40%")
	}
	if config.Preview != "" {
		args = append(args, "--preview", config.Preview)
	}
	if config.Placeholder != "" {
		args = append(args, "--query", config.Placeholder)
	}

	// Add styling and behavior
	args = append(args,
		"--layout=reverse",
		"--border",
		"--cycle",
		"--info=inline",
		"--color=fg:#cdd6f4,bg:#1e1e2e,hl:#f38ba8",
		"--color=fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8",
		"--color=info:#cba6f7,prompt:#cba6f7,pointer:#f5e0dc",
		"--color=marker:#f5e0dc,spinner:#f5e0dc,header:#f38ba8",
	)

	// Add any custom options
	args = append(args, config.Options...)

	// Create the command with timeout
	fzfCtx, cancel := context.WithTimeout(ctx, 5*time.Minute)
	defer cancel()

	cmd := exec.CommandContext(fzfCtx, "fzf", args...)

	// Prepare input for fzf
	var input strings.Builder
	for _, option := range options {
		if option.Display != "" {
			input.WriteString(option.Display + "\n")
		} else {
			input.WriteString(option.Value + "\n")
		}
	}

	// Set up pipes - fzf needs to inherit stdin/stdout/stderr for interactivity
	cmd.Stdin = strings.NewReader(input.String())
	cmd.Stdout = nil // Will be captured
	cmd.Stderr = os.Stderr

	// For fzf to work properly, we need to connect it to the actual terminal
	// Get the current terminal
	if tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0); err == nil {
		cmd.Stdin = strings.NewReader(input.String())
		cmd.Stderr = tty
		defer tty.Close()
	}

	// Run fzf and get output
	output, err := cmd.Output()
	result := &FzfResult{
		Selected: []string{},
		Query:    "",
	}

	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			result.ExitCode = exitError.ExitCode()
			// Exit code 1 means user pressed Escape or Ctrl+C
			if result.ExitCode == 1 || result.ExitCode == 130 {
				return result, nil
			}
		}
		return result, fmt.Errorf("fzf error: %w", err)
	}

	// Process output
	outputStr := strings.TrimSpace(string(output))
	if outputStr == "" {
		return result, nil
	}

	// Split by newlines for multiple selections
	selections := strings.Split(outputStr, "\n")

	// Map display values back to actual values
	for _, selection := range selections {
		selection = strings.TrimSpace(selection)
		if selection == "" {
			continue
		}

		// Find the corresponding value for this display
		found := false
		for _, option := range options {
			if option.Display == selection || (option.Display == "" && option.Value == selection) {
				result.Selected = append(result.Selected, option.Value)
				found = true
				break
			}
		}

		// If not found in options, use the selection as-is (for free text input)
		if !found {
			result.Selected = append(result.Selected, selection)
		}
	}

	return result, nil
}

// RunFzfSingle runs fzf for single selection and returns the selected value
func RunFzfSingle(ctx context.Context, options []FzfOption, config FzfConfig) (string, error) {
	config.Multi = false
	result, err := RunFzf(ctx, options, config)
	if err != nil {
		return "", err
	}

	if len(result.Selected) == 0 {
		return "", nil
	}

	return result.Selected[0], nil
}

// RunFzfMulti runs fzf for multiple selection and returns the selected values
func RunFzfMulti(ctx context.Context, options []FzfOption, config FzfConfig) ([]string, error) {
	config.Multi = true
	result, err := RunFzf(ctx, options, config)
	if err != nil {
		return nil, err
	}

	return result.Selected, nil
}

// RunFzfInput runs fzf as an input prompt (allows typing custom values)
func RunFzfInput(ctx context.Context, config FzfConfig) (string, error) {
	if err := checkFzfAvailable(); err != nil {
		return "", err
	}

	if !isTTY() {
		return "", fmt.Errorf("fzf requires an interactive terminal")
	}

	args := []string{
		"--print-query",
		"--no-multi",
		"--height", "3",
		"--layout=reverse",
		"--border",
	}

	if config.Prompt != "" {
		args = append(args, "--prompt", config.Prompt+" > ")
	}
	if config.Placeholder != "" {
		args = append(args, "--query", config.Placeholder)
	}

	// Create empty fzf for input only
	fzfCtx, cancel := context.WithTimeout(ctx, 5*time.Minute)
	defer cancel()

	cmd := exec.CommandContext(fzfCtx, "fzf", args...)
	cmd.Stdin = strings.NewReader("")

	// Connect to terminal for interaction
	if tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0); err == nil {
		cmd.Stdin = tty
		cmd.Stderr = tty
		defer tty.Close()
	}

	output, err := cmd.Output()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			exitCode := exitError.ExitCode()
			if exitCode == 1 || exitCode == 130 {
				return "", nil // User cancelled
			}
		}
		return "", fmt.Errorf("fzf input error: %w", err)
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) > 0 && lines[0] != "" {
		return lines[0], nil
	}

	return "", nil
}

// RunFzfConfirmation runs fzf for yes/no confirmation
func RunFzfConfirmation(ctx context.Context, message string) (bool, error) {
	options := []FzfOption{
		{Value: "yes", Display: "Yes"},
		{Value: "no", Display: "No"},
	}

	config := FzfConfig{
		Prompt:  message,
		Height:  "5",
		NoSort:  true,
		Options: []string{"--select-1"},
	}

	result, err := RunFzfSingle(ctx, options, config)
	if err != nil {
		return false, err
	}

	return result == "yes", nil
}
