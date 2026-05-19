# Jimmy's Dotfiles

[![Shell](https://img.shields.io/badge/Shell-Zsh-blue.svg?style=flat-square&logo=gnu-bash)](https://www.zsh.org)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg?style=flat-square)](LICENSE)

One command to set up a fully configured development environment on macOS, Linux, or WSL — complete with tiling windows, AI-powered coding agents, and a unified Catppuccin Mocha theme across every tool.

## Quick Start

```bash
git clone https://github.com/JimmyTranDev/dotfiles.git
cd dotfiles
./etc/scripts/install.sh
```

The installer detects your platform, installs packages, symlinks configs, and sets up SDKs. Run `./etc/scripts/doctor.sh` afterward to verify everything is healthy.

## What's Inside

### Terminal & Shell

| Tool | Role |
|------|------|
| **Ghostty** | GPU-accelerated terminal emulator |
| **Zsh** | Shell with custom aliases, plugins, and completions |
| **Starship** | Minimal, blazing-fast cross-shell prompt |
| **Zellij** | Terminal multiplexer with custom layouts |

### Development Tools

| Tool | Role |
|------|------|
| **Neovim** | Editor with LSP, completion, treesitter, and 40+ plugins |
| **Lazygit** | Git TUI for staging, branching, and rebasing |
| **Yazi** | Terminal file manager with preview and plugins |
| **Btop** | System resource monitor |

### Window Management

| Platform | Tools |
|----------|-------|
| **macOS** | Yabai (tiling WM) + SKHD (hotkey daemon) |

### Package Management

| Platform | Manager |
|----------|---------|
| **macOS** | Homebrew (Brewfile included) |
| **Arch Linux** | pacman + yay |

## AI-Powered Development

The `src/opencode/` directory contains a full OpenCode configuration that turns your terminal into an AI development environment:

| Resource | Count | Highlights |
|----------|-------|------------|
| **Agents** | 17 | auditor, critic, designer, devops, fixer, implementer, optimizer, reviewer, tester, and more |
| **Commands** | 44 | `/commit`, `/implement`, `/pr`, `/review`, `/specify`, `/fix`, `/quiz`, `/weekly-summary`, and more |
| **Skills** | 95 | Code quality, security, testing, Spring Boot, Expo, Drizzle, Tailwind, system design, and more |

Agents handle specialized tasks (code review, security audits, testing), commands orchestrate multi-step workflows (PR creation with worktrees, spec-driven implementation), and skills inject domain-specific knowledge on demand.

## Scripts

```bash
./etc/scripts/install.sh       # Full setup (detects platform, installs everything)
./etc/scripts/sync_links.sh    # Symlink configs (supports --dry-run)
./etc/scripts/doctor.sh        # Health check (validates symlinks, tools, env)
./etc/scripts/sdk_install.sh   # Install SDK versions (Java, Go, etc.)
./etc/scripts/sdk_select.sh    # Switch between installed SDK versions
```

Reusable AI utility scripts live in `etc/scripts/src/ai/` — stack detection, branch info, test runners, linting, PR status, and more.

## Structure

```
src/                     # Configs (symlinked to ~/.config or ~/)
├── .zshrc               # Shell config
├── .ideavimrc           # Vim keybindings for JetBrains
├── Brewfile             # Homebrew packages
├── starship.toml        # Prompt config
├── ghostty/             # Terminal emulator
├── lazygit/             # Git TUI
├── nvim/                # Neovim (LSP, completion, treesitter, plugins)
├── opencode/            # AI coding (17 agents, 44 commands, 95 skills)
├── skhd/                # Hotkeys (macOS)
├── yabai/               # Tiling WM (macOS)
├── yazi/                # File manager
└── zellij/              # Multiplexer

etc/
├── scripts/             # Install, sync, health check, SDK management
│   ├── common/          # Shared utilities (logging, git helpers)
│   ├── install/         # Platform-specific installers
│   └── src/ai/          # Reusable AI utility scripts
├── templates/           # Template configs (.gitconfig, .npmrc)
├── docs/                # Setup guides
└── theme.conf           # Catppuccin Mocha reference
```

## Theme

Every tool uses **Catppuccin Mocha** — terminal, prompt, multiplexer, file manager, git TUI, window manager, and editor. One palette, zero visual friction.

## License

Apache 2.0
