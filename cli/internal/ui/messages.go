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
