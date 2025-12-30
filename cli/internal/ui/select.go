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
	title           string
	options         []SelectOption
	filteredOptions []SelectOption
	cursor          int
	selected        string
	quitting        bool
	help            string
	searchMode      bool
	searchQuery     string
}

// NewSelectModel creates a new selection model
func NewSelectModel(title string, options []SelectOption) SelectModel {
	return SelectModel{
		title:           title,
		options:         options,
		filteredOptions: options,
		help:            "↑/↓: navigate • enter: select • /: search • esc: clear search/quit",
	}
}

// filterOptions filters options based on search query
func (m *SelectModel) filterOptions() {
	if m.searchQuery == "" {
		m.filteredOptions = m.options
		return
	}

	query := strings.ToLower(m.searchQuery)
	m.filteredOptions = make([]SelectOption, 0)

	for _, option := range m.options {
		if strings.Contains(strings.ToLower(option.Title), query) ||
			strings.Contains(strings.ToLower(option.Description), query) ||
			strings.Contains(strings.ToLower(option.Key), query) {
			m.filteredOptions = append(m.filteredOptions, option)
		}
	}

	// Reset cursor if it's out of bounds
	if m.cursor >= len(m.filteredOptions) {
		m.cursor = 0
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
		// Handle search mode
		if m.searchMode {
			switch msg.String() {
			case "esc":
				// Exit search mode and clear search
				m.searchMode = false
				m.searchQuery = ""
				m.filterOptions()
				return m, nil
			case "enter":
				// Exit search mode but keep the search
				m.searchMode = false
				return m, nil
			case "backspace":
				if len(m.searchQuery) > 0 {
					m.searchQuery = m.searchQuery[:len(m.searchQuery)-1]
					m.filterOptions()
				}
				return m, nil
			default:
				// Add character to search query
				if len(msg.String()) == 1 && msg.String() >= " " && msg.String() <= "~" {
					m.searchQuery += msg.String()
					m.filterOptions()
				}
				return m, nil
			}
		}

		// Handle normal mode
		switch msg.String() {
		case "q", "ctrl+c":
			m.quitting = true
			return m, tea.Quit
		case "esc":
			if m.searchQuery != "" {
				// Clear search if there's a query
				m.searchQuery = ""
				m.filterOptions()
				return m, nil
			} else {
				// Quit if no search query
				m.quitting = true
				return m, tea.Quit
			}
		case "/":
			// Enter search mode
			m.searchMode = true
			return m, nil
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.filteredOptions)-1 {
				m.cursor++
			}
		case "enter", " ":
			if len(m.filteredOptions) > 0 {
				m.selected = m.filteredOptions[m.cursor].Key
				m.quitting = true
				return m, tea.Quit
			}
		default:
			// Check for direct key selection
			for i, option := range m.filteredOptions {
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

	// Search bar
	if m.searchMode || m.searchQuery != "" {
		searchPrompt := "Search: "
		if m.searchMode {
			searchPrompt += m.searchQuery + "█" // cursor
		} else {
			searchPrompt += m.searchQuery
		}
		b.WriteString(styles.Help.Render(searchPrompt))
		b.WriteString("\n\n")
	}

	// Options
	for i, option := range m.filteredOptions {
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

	// Show message if no results
	if len(m.filteredOptions) == 0 && m.searchQuery != "" {
		b.WriteString("\n")
		b.WriteString(styles.Help.Render("No matches found for \"" + m.searchQuery + "\""))
		b.WriteString("\n")
	}

	// Help text with subtle styling
	b.WriteString("\n")
	if m.searchMode {
		b.WriteString(styles.Help.Render("enter: confirm search • esc: cancel search • backspace: delete"))
	} else {
		b.WriteString(styles.Help.Render(m.help))
	}

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
