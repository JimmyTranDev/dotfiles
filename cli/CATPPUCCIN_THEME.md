# Catppuccin Theme Integration

This CLI now features a beautiful, comprehensive **Catppuccin** theme system that provides a cohesive, polished user experience across all interactive elements.

## ✨ Features

### 🎨 Complete Catppuccin Color Palette
- **Mocha** (Default) - Dark theme with warm, cozy colors
- **Macchiato** - Slightly lighter dark theme with softer contrast  
- **Frappe** - Cool-toned dark theme with blue undertones
- **Latte** - Light theme for daytime coding

### 🛠️ Enhanced UI Components
- **Beautiful Headers** - Styled with rounded borders and accent colors
- **Interactive Menus** - Consistent selection highlighting and navigation
- **Status Messages** - Color-coded success, error, warning, and info messages
- **Visual Hierarchy** - Proper typography and spacing throughout

### 🎯 Consistent Theming
All UI elements follow the Catppuccin design language:
- **Primary Actions** - Mauve accent color for important actions
- **Success States** - Green for successful operations
- **Errors** - Red for error conditions  
- **Warnings** - Peach for warnings and important notices
- **Information** - Blue for informational messages
- **Navigation** - Consistent emoji icons and key styling

## 🚀 Usage

### Theme Management Commands
```bash
# List all available themes for applications (Ghostty, Zellij, btop)
dotfiles theme list

# Set application theme interactively
dotfiles theme set

# Show current application theme
dotfiles theme current

# Set CLI UI theme (new feature!)
dotfiles ui set-theme  # Available in interactive mode: [t] → [u]
```

### Interactive Mode
The main interactive mode now features beautiful Catppuccin styling:

```
╭─────────────────────────────────────────────╮
│           🛠️  Dotfiles Manager              │
│     Interactive Development Workflow       │
╰─────────────────────────────────────────────╯

📋 Main Menu:

[w] 🌳 Worktree Management
[t] 🎨 Theme Management  
[i] 📦 Installation & Updates
[s] ☁️ Storage Management

[q] ❌ Exit
```

## 🎭 Theme Variants

### Catppuccin Mocha (Default)
- **Background**: Deep, warm dark tones (#1e1e2e)
- **Accent**: Purple/Mauve (#cba6f7)
- **Text**: Light, readable (#cdd6f4)
- **Perfect for**: Evening coding sessions

### Catppuccin Macchiato  
- **Background**: Medium dark tones (#24273a)
- **Accent**: Soft purple (#c6a0f6)
- **Text**: Bright, clear (#cad3f5)
- **Perfect for**: General use, softer contrast

### Catppuccin Frappe
- **Background**: Cool dark tones (#303446) 
- **Accent**: Balanced purple (#ca9ee6)
- **Text**: Clean, crisp (#c6d0f5)
- **Perfect for**: Focus sessions, blue-light preference

### Catppuccin Latte (Light)
- **Background**: Clean light tones (#eff1f5)
- **Accent**: Deep purple (#8839ef)  
- **Text**: Dark, readable (#4c4f69)
- **Perfect for**: Daytime coding, bright environments

## 🏗️ Architecture

### Theme System Structure
```
internal/ui/
├── catppuccin.go    # Complete color palette definitions
├── config.go       # Theme configuration management  
├── messages.go     # Consistent message utilities
└── select.go       # Enhanced Bubble Tea components
```

### Key Components
- **`CatppuccinTheme`** - Main theme struct with all color definitions
- **`CatppuccinStyles`** - Pre-configured lipgloss styles for all UI elements
- **Message Utilities** - Consistent `Success()`, `Error()`, `Warning()`, `Info()` functions
- **Dynamic Theme Loading** - Runtime theme switching without restart

## 🔧 Implementation Highlights

### Consistent Color Usage
Every CLI output now uses the appropriate Catppuccin color:
- Success messages use **Green** (#a6e3a1)
- Error messages use **Red** (#f38ba8)  
- Warnings use **Peach** (#fab387)
- Info messages use **Blue** (#89b4fa)
- Accents use **Mauve** (#cba6f7)

### Enhanced Visual Feedback
- **Selection Highlighting** - Clear visual indication of selected options
- **Emoji Integration** - Consistent, meaningful icons throughout
- **Border Styling** - Beautiful rounded borders using lipgloss
- **Spacing & Typography** - Professional layout and readability

### Accessibility
- **High Contrast** - All variants meet accessibility standards
- **Color Blind Friendly** - Catppuccin palette is designed for inclusivity
- **Clear Visual Hierarchy** - Proper emphasis and organization

## 🌟 Benefits

1. **Professional Appearance** - Modern, polished CLI that matches high-quality developer tools
2. **Brand Consistency** - Integrates perfectly with existing Catppuccin ecosystem (Ghostty, Zellij, btop)
3. **User Experience** - Intuitive navigation with clear visual feedback
4. **Maintainability** - Centralized theme system for easy updates and consistency
5. **Flexibility** - Support for all Catppuccin variants with runtime switching

This implementation transforms the CLI from a basic utility into a beautiful, professional development tool that developers will enjoy using daily.