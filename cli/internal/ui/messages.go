package ui

import "fmt"

// Message utilities for consistent themed output throughout the CLI

// Success prints a success message with consistent theming
func Success(message string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	fmt.Println(styles.Success.Render(EmojiSuccess + " " + message))
}

// Error prints an error message with consistent theming
func Error(message string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	fmt.Println(styles.Error.Render(EmojiError + " " + message))
}

// Warning prints a warning message with consistent theming
func Warning(message string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	fmt.Println(styles.Warning.Render(EmojiWarning + " " + message))
}

// Info prints an info message with consistent theming
func Info(message string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	fmt.Println(styles.Info.Render(EmojiInfo + " " + message))
}

// Progress prints a progress message with consistent theming
func Progress(message string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	fmt.Println(styles.Accent.Render(EmojiRocket + " " + message))
}

// Header prints a header message with consistent theming
func Header(message string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	fmt.Println(styles.Header.Render(EmojiTool + "  " + message))
}

// KeyValue prints a key-value pair with consistent theming
func KeyValue(key, value string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	keyText := styles.Key.Render(key + ":")
	valueText := styles.Value.Render(value)
	fmt.Printf("%s %s\n", keyText, valueText)
}

// Quit prints a goodbye message with consistent theming
func Quit(message string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	fmt.Println(styles.Info.Render(EmojiWave + " " + message))
}

// Section prints a section header with consistent theming
func Section(title string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	fmt.Println(styles.AccentSecondary.Render(EmojiMenu + " " + title))
}

// Option prints an option with key and description
func Option(key, description string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	keyText := styles.Key.Render("[" + key + "]")
	descText := styles.Value.Render(description)
	fmt.Printf("%s %s\n", keyText, descText)
}

// Help prints help text with consistent theming
func Help(message string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	fmt.Print(styles.Help.Render(message))
}

// Accent prints accented text (for branding, highlights, etc.)
func Accent(message string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	fmt.Println(styles.Accent.Render(message))
}

// Subtle prints subtle text (for less important information)
func Subtle(message string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	fmt.Println(styles.AccentSubtle.Render(message))
}

// CompletionSummary prints a task completion summary with results
func CompletionSummary(title string, results []string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()

	fmt.Println()
	fmt.Println(styles.Success.Render(EmojiSuccess + " Task Completed: " + title))

	if len(results) > 0 {
		fmt.Println()
		fmt.Println(styles.AccentSecondary.Render("Results:"))
		for _, result := range results {
			fmt.Println(styles.Value.Render("  • " + result))
		}
	}
	fmt.Println()
}

// TaskStart prints a task start message
func TaskStart(title string) {
	theme := GetCurrentTheme()
	styles := theme.Styles()
	fmt.Println(styles.Accent.Render(EmojiRocket + " Starting: " + title))
}

// TaskResult stores task execution results
type TaskResult struct {
	Title   string
	Success bool
	Message string
	Details []string
}

// ShowTaskResult displays a formatted task result
func ShowTaskResult(result TaskResult) {
	theme := GetCurrentTheme()
	styles := theme.Styles()

	fmt.Println()

	if result.Success {
		fmt.Println(styles.Success.Render(EmojiSuccess + " " + result.Title + " - Completed Successfully"))
		if result.Message != "" {
			fmt.Println(styles.Success.Render("  " + result.Message))
		}
	} else {
		fmt.Println(styles.Error.Render(EmojiError + " " + result.Title + " - Failed"))
		if result.Message != "" {
			fmt.Println(styles.Error.Render("  " + result.Message))
		}
	}

	if len(result.Details) > 0 {
		fmt.Println()
		fmt.Println(styles.AccentSecondary.Render("Details:"))
		for _, detail := range result.Details {
			fmt.Println(styles.Value.Render("  • " + detail))
		}
	}
	fmt.Println()
}
