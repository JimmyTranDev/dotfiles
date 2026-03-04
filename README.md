# Jimmy's Dotfiles

[![Shell](https://img.shields.io/badge/Shell-Zsh-blue.svg?style=flat-square&logo=gnu-bash)](https://www.zsh.org)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg?style=flat-square)](LICENSE)

Cross-platform dotfiles for macOS, Linux, and WSL.

## Tech Stack

| Component | Technologies |
|-----------|--------------|
| **Shell** | Zsh, Starship prompt |
| **Terminal** | Ghostty, Zellij (multiplexer) |
| **Package Management** | Homebrew (macOS), pacman/yay (Arch Linux) |
| **Window Management** | Yabai + SKHD (macOS) |
| **File Management** | Yazi (terminal file manager) |
| **Git Tools** | Lazygit, custom worktree scripts |
| **System Monitoring** | Btop |
| **AI Development** | OpenCode (18 agents, 8 commands) |
| **Theme** | Catppuccin (consistent across all tools) |
| **Scripting** | Bash, Zsh |

## Features

| Feature | Description |
|---------|-------------|
| **Automated Setup** | OS detection with platform-specific configurations |
| **Package Management** | Homebrew (macOS) and pacman/yay (Arch Linux) |
| **SDK Management** | Version management for Java, Go, and other SDKs |
| **Catppuccin Theming** | Consistent theme across all tools |

## AI-Powered Development

OpenCode configuration with 18 custom agents and 8 slash commands for AI-assisted coding:

| Type | Available |
|------|-----------|
| **Agents** | auditor, classless, designer, expo, fixer, follower, fsrs, optimizer, pragmatic, profile-reviewer, prompter, re-export-destroyer, reuser, reviewer, solver, sounder, structure, tester |
| **Commands** | commit, continue, implement, refactor, test, update-commits |

## Scripts

| Script | Description |
|--------|-------------|
| **install.sh** | Main setup script (detects platform, runs common + platform-specific) |
| **sync_links.sh** | Symlink management (supports --dry-run and backups) |
| **sync_secrets.sh** | Secrets sync to/from Backblaze B2 |
| **sdk_install.sh** | SDK version installation |
| **sdk_select.sh** | SDK version selection |
| **doctor.sh** | Health check (validates symlinks, tools, environment) |
| **worktrees/** | Git worktree management (checkout, create, delete, move, rename, update) |

## Tools

| Tool | Description |
|------|-------------|
| **Zellij** | Terminal multiplexer |
| **Yazi** | File manager with plugins |
| **Lazygit** | Git TUI |
| **Yabai + SKHD** | Window management (macOS) |
| **Btop** | System monitoring |
| **Ghostty** | Terminal emulator |
| **Starship** | Shell prompt |

## Structure

```
etc/
├── docs/              # Platform-specific setup guides (macOS, WSL, common)
├── scripts/           # Automation and utility scripts
│   ├── install.sh     # Main entry point for installation
│   ├── sync_links.sh  # Creates symlinks from src/ to home directory
│   ├── sync_secrets.sh  # Syncs secrets to/from Backblaze B2
│   ├── doctor.sh        # Health check for environment validation
│   ├── common/          # Shared utilities (logging, functions)
│   ├── install/         # Platform-specific installers (common, mac, arch)
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
