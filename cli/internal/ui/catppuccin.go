package ui

import "github.com/charmbracelet/lipgloss"

// CatppuccinVariant represents different Catppuccin theme variants
type CatppuccinVariant string

const (
	CatppuccinMocha     CatppuccinVariant = "mocha"
	CatppuccinMacchiato CatppuccinVariant = "macchiato"
	CatppuccinFrappe    CatppuccinVariant = "frappe"
	CatppuccinLatte     CatppuccinVariant = "latte"
)

// CatppuccinColors defines the complete Catppuccin color palette for a variant
type CatppuccinColors struct {
	// Base colors
	Base   string // Base background
	Mantle string // Darker background
	Crust  string // Darkest background

	// Surface colors
	Surface0 string // Surface backgrounds
	Surface1 string
	Surface2 string

	// Overlay colors
	Overlay0 string // Overlay backgrounds
	Overlay1 string
	Overlay2 string

	// Text colors
	Text     string // Primary text
	Subtext0 string // Secondary text
	Subtext1 string // Tertiary text

	// Accent colors
	Rosewater string // Rosewater accent
	Flamingo  string // Flamingo accent
	Pink      string // Pink accent
	Mauve     string // Mauve accent (primary brand)
	Red       string // Red (errors)
	Maroon    string // Maroon (dark red)
	Peach     string // Peach (warnings/important)
	Yellow    string // Yellow (warnings/info)
	Green     string // Green (success)
	Teal      string // Teal accent
	Sky       string // Sky accent
	Sapphire  string // Sapphire accent
	Blue      string // Blue (information/links)
	Lavender  string // Lavender (special highlights)
}

// GetCatppuccinColors returns the color palette for the specified variant
func GetCatppuccinColors(variant CatppuccinVariant) CatppuccinColors {
	switch variant {
	case CatppuccinMocha:
		return CatppuccinColors{
			Base:      "#1e1e2e",
			Mantle:    "#181825",
			Crust:     "#11111b",
			Surface0:  "#313244",
			Surface1:  "#45475a",
			Surface2:  "#585b70",
			Overlay0:  "#6c7086",
			Overlay1:  "#7f849c",
			Overlay2:  "#9399b2",
			Text:      "#cdd6f4",
			Subtext0:  "#a6adc8",
			Subtext1:  "#bac2de",
			Rosewater: "#f5e0dc",
			Flamingo:  "#f2cdcd",
			Pink:      "#f5c2e7",
			Mauve:     "#cba6f7",
			Red:       "#f38ba8",
			Maroon:    "#eba0ac",
			Peach:     "#fab387",
			Yellow:    "#f9e2af",
			Green:     "#a6e3a1",
			Teal:      "#94e2d5",
			Sky:       "#89dceb",
			Sapphire:  "#74c7ec",
			Blue:      "#89b4fa",
			Lavender:  "#b4befe",
		}
	case CatppuccinMacchiato:
		return CatppuccinColors{
			Base:      "#24273a",
			Mantle:    "#1e2030",
			Crust:     "#181926",
			Surface0:  "#363a4f",
			Surface1:  "#494d64",
			Surface2:  "#5b6078",
			Overlay0:  "#6e738d",
			Overlay1:  "#8087a2",
			Overlay2:  "#939ab7",
			Text:      "#cad3f5",
			Subtext0:  "#a5adcb",
			Subtext1:  "#b8c0e0",
			Rosewater: "#f4dbd6",
			Flamingo:  "#f0c6c6",
			Pink:      "#f5bde6",
			Mauve:     "#c6a0f6",
			Red:       "#ed8796",
			Maroon:    "#ee99a0",
			Peach:     "#f5a97f",
			Yellow:    "#eed49f",
			Green:     "#a6da95",
			Teal:      "#8bd5ca",
			Sky:       "#91d7e3",
			Sapphire:  "#7dc4e4",
			Blue:      "#8aadf4",
			Lavender:  "#b7bdf8",
		}
	case CatppuccinFrappe:
		return CatppuccinColors{
			Base:      "#303446",
			Mantle:    "#292c3c",
			Crust:     "#232634",
			Surface0:  "#414559",
			Surface1:  "#51576d",
			Surface2:  "#626880",
			Overlay0:  "#737994",
			Overlay1:  "#838ba7",
			Overlay2:  "#949cbb",
			Text:      "#c6d0f5",
			Subtext0:  "#a5adce",
			Subtext1:  "#b5bfe2",
			Rosewater: "#f2d5cf",
			Flamingo:  "#eebebe",
			Pink:      "#f4b8e4",
			Mauve:     "#ca9ee6",
			Red:       "#e78284",
			Maroon:    "#ea999c",
			Peach:     "#ef9f76",
			Yellow:    "#e5c890",
			Green:     "#a6d189",
			Teal:      "#81c8be",
			Sky:       "#99d1db",
			Sapphire:  "#85c1dc",
			Blue:      "#8caaee",
			Lavender:  "#babbf1",
		}
	case CatppuccinLatte:
		return CatppuccinColors{
			Base:      "#eff1f5",
			Mantle:    "#e6e9ef",
			Crust:     "#dce0e8",
			Surface0:  "#ccd0da",
			Surface1:  "#bcc0cc",
			Surface2:  "#acb0be",
			Overlay0:  "#9ca0b0",
			Overlay1:  "#8c8fa1",
			Overlay2:  "#7c7f93",
			Text:      "#4c4f69",
			Subtext0:  "#6c6f85",
			Subtext1:  "#5c5f77",
			Rosewater: "#dc8a78",
			Flamingo:  "#dd7878",
			Pink:      "#ea76cb",
			Mauve:     "#8839ef",
			Red:       "#d20f39",
			Maroon:    "#e64553",
			Peach:     "#fe640b",
			Yellow:    "#df8e1d",
			Green:     "#40a02b",
			Teal:      "#179299",
			Sky:       "#04a5e5",
			Sapphire:  "#209fb5",
			Blue:      "#1e66f5",
			Lavender:  "#7287fd",
		}
	default:
		// Default to Mocha
		return GetCatppuccinColors(CatppuccinMocha)
	}
}

// CatppuccinTheme provides styled components using Catppuccin colors
type CatppuccinTheme struct {
	Colors  CatppuccinColors
	Variant CatppuccinVariant
}

// NewCatppuccinTheme creates a new Catppuccin theme
func NewCatppuccinTheme(variant CatppuccinVariant) *CatppuccinTheme {
	return &CatppuccinTheme{
		Colors:  GetCatppuccinColors(variant),
		Variant: variant,
	}
}

// Styles returns themed lipgloss styles
func (t *CatppuccinTheme) Styles() CatppuccinStyles {
	return CatppuccinStyles{
		// Title styles
		Title: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Mauve)).
			Bold(true).
			MarginLeft(2),

		// Header with beautiful border
		Header: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Mauve)).
			Bold(true).
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color(t.Colors.Mauve)).
			Padding(0, 2).
			MarginBottom(1),

		// Selected item (highlighted)
		Selected: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Text)).
			Background(lipgloss.Color(t.Colors.Surface1)).
			Bold(true).
			Padding(0, 1),

		// Unselected item
		Unselected: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Subtext0)),

		// Cursor/arrow
		Cursor: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Mauve)).
			Bold(true),

		// Description text
		Description: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Subtext1)).
			MarginLeft(4),

		// Help text
		Help: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Overlay1)).
			MarginTop(1).
			MarginLeft(2),

		// Success messages
		Success: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Green)).
			Bold(true),

		// Error messages
		Error: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Red)).
			Bold(true),

		// Warning messages
		Warning: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Peach)).
			Bold(true),

		// Info messages
		Info: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Blue)).
			Bold(true),

		// Accent (for highlights, brands, etc.)
		Accent: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Mauve)).
			Bold(true),

		// Secondary accent
		AccentSecondary: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Lavender)).
			Bold(true),

		// Subtle accent
		AccentSubtle: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Pink)),

		// Border styles
		Border: lipgloss.NewStyle().
			BorderForeground(lipgloss.Color(t.Colors.Surface2)),

		// Box styles
		Box: lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color(t.Colors.Surface2)).
			Padding(1, 2).
			MarginBottom(1),

		// Key-value styles
		Key: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Blue)).
			Bold(true),

		Value: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Colors.Text)),
	}
}

// CatppuccinStyles contains all themed styles
type CatppuccinStyles struct {
	Title           lipgloss.Style
	Header          lipgloss.Style
	Selected        lipgloss.Style
	Unselected      lipgloss.Style
	Cursor          lipgloss.Style
	Description     lipgloss.Style
	Help            lipgloss.Style
	Success         lipgloss.Style
	Error           lipgloss.Style
	Warning         lipgloss.Style
	Info            lipgloss.Style
	Accent          lipgloss.Style
	AccentSecondary lipgloss.Style
	AccentSubtle    lipgloss.Style
	Border          lipgloss.Style
	Box             lipgloss.Style
	Key             lipgloss.Style
	Value           lipgloss.Style
}

// Default theme instance (Mocha)
var DefaultTheme = NewCatppuccinTheme(CatppuccinMocha)

// Emoji constants for consistent UI
const (
	EmojiTool      = "🛠️"
	EmojiTree      = "🌳"
	EmojiArt       = "🎨"
	EmojiPackage   = "📦"
	EmojiCloud     = "☁️"
	EmojiExit      = "❌"
	EmojiSuccess   = "✓"
	EmojiError     = "❌"
	EmojiWarning   = "⚠️"
	EmojiInfo      = "ℹ️"
	EmojiArrow     = "→"
	EmojiBackArrow = "←"
	EmojiMenu      = "📋"
	EmojiConfig    = "⚙️"
	EmojiFolder    = "📁"
	EmojiFile      = "📄"
	EmojiGit       = "🔀"
	EmojiSync      = "🔄"
	EmojiKey       = "🔑"
	EmojiEye       = "👁"
	EmojiRocket    = "🚀"
	EmojiStar      = "⭐"
	EmojiMagic     = "✨"
	EmojiWave      = "👋"
)
