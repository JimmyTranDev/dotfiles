# 🚀 Jimmy's Dotfiles

> *A comprehensive, cross-platform dotfiles configuration for maximum developer productivity*

![Platform Support](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-blue)
![Shell](https://img.shields.io/badge/shell-zsh-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

This repository contains my personal dotfiles setup, meticulously crafted for a seamless development experience across macOS, Linux, and WSL environments. It includes configurations, themes, and automation scripts for a modern terminal-based workflow.

## ✨ Features

### 🎯 **One-Command Setup**
- Automated installation scripts for both macOS and Linux/WSL
- Smart OS detection and platform-specific configurations
- Symlink management with conflict resolution

### 📦 **Package Management**
- Homebrew integration with comprehensive `Brewfile`
- Arch Linux package management via `pacman` and `paru`
- Automatic dependency installation

### 🔧 **Development Tools**
- **Terminal Multiplexing**: Zellij with custom layouts and keybinds
- **File Management**: Yazi with plugins (bookmarks, git integration, smart navigation)
- **Git Workflow**: Lazygit configuration and branch automation
- **Window Management**: Yabai + SKHD for tiling window management (macOS)
- **System Monitoring**: Btop with beautiful Catppuccin themes

### 🎨 **Beautiful Themes**
- Consistent Catppuccin color scheme across all tools
- Multiple terminal themes (Ghostty configurations)
- Starship prompt with informative modules

### 🤖 **Automation Scripts**
- Git worktree management
- Bulk repository updates
- Port cleanup utilities
- Branch auto-updating userscripts

## 📁 Repository Structure

```
├── etc/
│   ├── docs/                    # 📚 Platform-specific setup guides
│   │   ├── setup_mac.md        # macOS installation guide  
│   │   ├── setup_wsl.md        # WSL/Linux setup instructions
│   │   └── setup_common.md     # Common setup steps
│   ├── scripts/                # 🔧 Automation scripts
│   │   ├── install/            # Installation utilities
│   │   │   ├── install.sh      # Main installation script
│   │   │   ├── clone_essential_repos.sh
│   │   │   └── fetch_all_folders.sh
│   │   ├── common/             # Shared utilities
│   │   ├── kill_port.sh        # Port cleanup utility
│   │   ├── update_dotfiles.sh  # Dotfiles update script
│   │   └── worktrees.sh        # Git worktree management
│   └── userscripts/            # 🌐 Browser automation
│       └── auto-update-branch.js
└── src/                        # ⚙️ Configuration files
    ├── Brewfile                # Homebrew package definitions
    ├── .zshrc                  # Zsh shell configuration
    ├── starship.toml           # Starship prompt config
    ├── btop/                   # System monitor themes
    ├── ghostty/                # Terminal emulator configs
    ├── lazygit/                # Git TUI configuration
    ├── skhd/                   # Hotkey daemon (macOS)
    ├── yabai/                  # Window manager (macOS)
    ├── yazi/                   # File manager + plugins
    └── zellij/                 # Terminal multiplexer
```

## 🚀 Quick Start

### Prerequisites
- Git installed and configured
- Internet connection for package downloads

### Installation

1. **Clone this repository**
   ```bash
   git clone https://github.com/JimmyTranDev/dotfiles-new.git ~/Programming/dotfiles
   cd ~/Programming/dotfiles
   ```

2. **Clone essential repositories** (optional)
   ```bash
   ./etc/scripts/install/clone_essential_repos.sh
   ```

3. **Run the main installation script**
   ```bash
   ./etc/scripts/install/install.sh
   ```
   
   This script will:
   - 🔍 Detect your operating system (macOS/Linux)
   - 🔗 Create symlinks for all configuration files
   - 📦 Install packages via Homebrew (macOS) or pacman/paru (Arch Linux)
   - ⚙️ Set up configurations for all supported tools

4. **Set up shell aliases** (recommended)
   ```bash
   # Add to your shell profile or use the provided .zshrc
   alias i="$HOME/Programming/dotfiles/etc/scripts/install/install.sh"
   alias I="$HOME/Programming/dotfiles/etc/scripts/update_dotfiles.sh"
   ```

### Updating

Keep your dotfiles in sync:
```bash
./etc/scripts/update_dotfiles.sh
# or simply: I (if alias is set)
```

## 🖥️ Platform-Specific Setup

### 🍎 macOS
```bash
# Follow the detailed macOS setup guide
cat etc/docs/setup_mac.md
```
**Includes:**
- Homebrew installation and configuration
- System services setup (skhd, yabai)
- macOS-specific optimizations

### 🐧 Linux/WSL
```bash
# Follow the Linux/WSL setup guide  
cat etc/docs/setup_wsl.md
```
**Includes:**
- Package manager setup (pacman/paru)
- User permissions and systemd services
- WSL-specific configurations

### 🔐 Secrets Management
For sensitive configurations:
1. Create `~/Programming/secrets/` directory
2. Add your private configs (`.gitconfig`, `.npmrc`, `.m2`, etc.)
3. The install script will automatically symlink them

## 🛠️ Tool Configurations

### 🪟 Window Management (macOS)
- **Yabai**: Tiling window manager with automatic layouts
- **SKHD**: Hotkey daemon for window manipulation and app launching

### 📺 Terminal & Shell  
- **Zellij**: Terminal multiplexer with custom layouts and keybindings
- **Starship**: Beautiful, fast, and informative shell prompt
- **Ghostty**: Modern terminal emulator with multiple theme options

### 📁 File Management
- **Yazi**: Blazingly fast terminal file manager
  - **Plugins**: Bookmarks, Git integration, Smart navigation, Copy file contents
  - **Custom keymaps**: Optimized for productivity

### 🎨 Monitoring & System
- **Btop**: Resource monitor with gorgeous Catppuccin themes
- **Git workflows**: Lazygit configuration + automated branch management

## 📜 Utility Scripts

| Script                  | Description                                       |
| ----------------------- | ------------------------------------------------- |
| `kill_port.sh`          | 🔪 Kill processes running on specific ports        |
| `fetch_all_folders.sh`  | 🔄 Bulk update all git repositories in a directory |
| `worktrees.sh`          | 🌳 Git worktree management utilities               |
| `update_dotfiles.sh`    | ⬆️ Update and sync dotfiles configuration          |
| `auto-update-branch.js` | 🤖 Browser automation for GitHub branch updates    |

## 🎭 Themes & Aesthetics

This dotfiles setup maintains consistent theming across all tools:

- **🎨 Catppuccin**: Beautiful pastel color scheme (Mocha, Frappé, Latte, Macchiato variants)
- **✨ Consistent**: Unified color palette across terminal, file manager, system monitor, and more

## 🤝 Contributing

Feel free to fork this repository and customize it for your own needs! If you find improvements or fixes, pull requests are welcome.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Credits & Acknowledgments

- [Catppuccin](https://github.com/catppuccin) - Beautiful pastel theme
- [Yazi community](https://github.com/sxyazi/yazi) - File manager plugins and configurations
- The open-source community for the amazing tools that make this setup possible
