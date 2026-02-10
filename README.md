# Jimmy's Dotfiles

Cross-platform dotfiles for macOS, Linux, and WSL.

## Features

- Automated setup with OS detection
- Homebrew and pacman/paru package management
- SDK version management (Java, Go, etc.)
- Catppuccin theming across all tools

## Tools

- **Zellij** - Terminal multiplexer
- **Yazi** - File manager with plugins
- **Lazygit** - Git TUI
- **Yabai + SKHD** - Window management (macOS)
- **Btop** - System monitoring
- **Ghostty** - Terminal emulator
- **Starship** - Shell prompt
- **OpenCode** - AI coding assistant with custom agents

## Structure

```
etc/
├── docs/           # Setup guides
├── scripts/        # Automation scripts
│   ├── setup.sh
│   ├── sync_links.sh
│   ├── sync_packages.sh
│   ├── sync_secrets.sh
│   └── worktrees/  # Git worktree management
└── theme.conf

src/
├── .zshrc
├── .ideavimrc
├── Brewfile
├── starship.toml
├── btop/
├── ghostty/
├── lazygit/
├── opencode/       # 17 agents, 8 commands
├── skhd/
├── yabai/
├── yazi/
└── zellij/
```

## License

MIT
