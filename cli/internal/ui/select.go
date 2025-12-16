package ui

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

// Get the current theme dynamically
func getCurrentTheme() *CatppuccinTheme {
	return GetCurrentTheme()
}

// SelectOption represents a selectable option
type SelectOption struct {
	Key         string
	Title       string
	Description string
}

// SelectModel represents the Bubble Tea model for selection
type SelectModel struct {
	title    string
	options  []SelectOption
	cursor   int
	selected string
	quitting bool
	help     string
}

// NewSelectModel creates a new selection model
func NewSelectModel(title string, options []SelectOption) SelectModel {
	return SelectModel{
		title:   title,
		options: options,
		help:    "↑/↓: navigate • enter: select • q/esc: quit anytime",
	}
}

// Init initializes the model
func (m SelectModel) Init() tea.Cmd {
	return nil
}

// Update handles user input
func (m SelectModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c", "esc":
			m.quitting = true
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.options)-1 {
				m.cursor++
			}
		case "enter", " ":
			m.selected = m.options[m.cursor].Key
			m.quitting = true
			return m, tea.Quit
		default:
			// Check for direct key selection
			for i, option := range m.options {
				if option.Key == msg.String() {
					m.cursor = i
					m.selected = option.Key
					m.quitting = true
					return m, tea.Quit
				}
			}
		}
	}
	return m, nil
}

// View renders the UI
func (m SelectModel) View() string {
	if m.quitting {
		return ""
	}

	var b strings.Builder

	styles := getCurrentTheme().Styles()

	// Header with emoji and beautiful styling
	b.WriteString(styles.Header.Render(EmojiTool + "  " + m.title))
	b.WriteString("\n\n")

	// Options
	for i, option := range m.options {
		cursor := "  "
		if i == m.cursor {
			cursor = styles.Cursor.Render(EmojiArrow + " ")
		}

		// Title with key shortcut
		title := fmt.Sprintf("[%s] %s", option.Key, option.Title)
		if i == m.cursor {
			title = styles.Selected.Render(title)
		} else {
			title = styles.Unselected.Render(title)
		}

		b.WriteString(cursor + title)

		// No descriptions shown for cleaner selection interface
		b.WriteString("\n")
	}

	// Help text with subtle styling
	b.WriteString("\n")
	b.WriteString(styles.Help.Render(m.help))

	return b.String()
}

// GetSelected returns the selected option key
func (m SelectModel) GetSelected() string {
	return m.selected
}

// QuitError represents a user-initiated quit
type QuitError struct {
	Message string
}

func (e QuitError) Error() string {
	return e.Message
}

// IsQuitError checks if an error is a quit error
func IsQuitError(err error) bool {
	_, ok := err.(QuitError)
	return ok
}

// RunSelection runs the selection UI and returns the selected option
func RunSelection(title string, options []SelectOption) (string, error) {
	model := NewSelectModel(title, options)

	program := tea.NewProgram(model, tea.WithAltScreen())
	finalModel, err := program.Run()
	if err != nil {
		return "", err
	}

	selectModel := finalModel.(SelectModel)
	if selectModel.GetSelected() == "" {
		return "", QuitError{Message: "quit"}
	}

	return selectModel.GetSelected(), nil
}

// RunConfirmation is a convenience function for yes/no confirmations
func RunConfirmation(title string, description string) (bool, error) {
	options := []SelectOption{
		{
			Key:         "y",
			Title:       "Yes",
			Description: "Proceed with the action",
		},
		{
			Key:         "n",
			Title:       "No",
			Description: "Cancel the action",
		},
	}

	choice, err := RunSelection(title, options)
	if err != nil {
		return false, err
	}

	return choice == "y", nil
}
