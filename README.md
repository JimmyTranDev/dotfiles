# Jimmy's Dotfiles

Cross-platform dotfiles for macOS, Linux, and WSL.

## Features

- Automated setup with OS detection
- Homebrew and pacman/paru package management
- SDK version management (Java, Go, etc.)
- Catppuccin theming across all tools

## AI-Powered Development

OpenCode configuration with 17 custom agents and 8 slash commands for AI-assisted coding:

**Agents**: auditor, classless, designer, expo, fixer, follower, fsrs, optimizer, pragmatic, prompter, re-export-destroyer, reuser, reviewer, solver, sounder, structure, tester

**Commands**: commit, continue, implement, refactor, test, update-commits

## Scripts

- **setup.sh** - Main setup script
- **sync_links.sh** - Symlink management
- **sync_packages.sh** - Package installation (Homebrew/pacman)
- **sync_secrets.sh** - Secrets symlink management
- **sdk_install.sh** - SDK version installation
- **sdk_select.sh** - SDK version selection
- **worktrees/** - Git worktree management (checkout, create, delete, move, rename, update)

## Tools

- **Zellij** - Terminal multiplexer
- **Yazi** - File manager with plugins
- **Lazygit** - Git TUI
- **Yabai + SKHD** - Window management (macOS)
- **Btop** - System monitoring
- **Ghostty** - Terminal emulator
- **Starship** - Shell prompt

## Structure

```
etc/
├── docs/              # Platform-specific setup guides (macOS, WSL, common)
├── scripts/           # Automation and utility scripts
│   ├── setup.sh       # Main entry point for installation
│   ├── sync_links.sh  # Creates symlinks from src/ to home directory
│   ├── sync_packages.sh # Installs packages via Homebrew or pacman/paru
│   ├── sync_secrets.sh  # Symlinks private configs from ~/Programming/secrets
│   ├── sdk_install.sh   # Installs SDK versions (Java, Go, etc.)
│   ├── sdk_select.sh    # Switches between installed SDK versions
│   └── worktrees/       # Git worktree utilities for branch management
└── theme.conf         # Global Catppuccin theme configuration

src/                   # Configuration files (symlinked to ~/.config or ~/)
├── .zshrc             # Zsh shell configuration with aliases and plugins
├── .ideavimrc         # Vim keybindings for JetBrains IDEs
├── Brewfile           # Homebrew package definitions
├── starship.toml      # Cross-shell prompt configuration
├── btop/              # System monitor with Catppuccin theme
├── ghostty/           # Terminal emulator config and themes
├── lazygit/           # Git TUI configuration
├── opencode/          # AI coding assistant (17 agents, 8 commands)
├── skhd/              # Hotkey daemon for macOS
├── yabai/             # Tiling window manager for macOS
├── yazi/              # Terminal file manager with plugins
└── zellij/            # Terminal multiplexer layouts and keybindings
```

## License

Apache 2.0
