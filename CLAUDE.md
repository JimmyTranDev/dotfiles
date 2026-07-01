## Universal Rules

- **Never create documentation files** (README, docs, markdown) unless explicitly asked.
- **Catppuccin Mocha** is the unified color theme across all tools.

## Repository Structure

```
dotfiles/
├── src/                    # Config files (symlinked to their destinations)
│   ├── nvim/               # -> ~/.config/nvim/
│   ├── opencode/           # -> ~/.config/opencode/
│   ├── claude/             # -> ~/.claude/
│   ├── ghostty/            # -> ~/.config/ghostty/
│   ├── kitty/              # -> ~/.config/kitty/
│   ├── yazi/               # -> ~/.config/yazi/
│   ├── zellij/             # -> ~/.config/zellij/
│   ├── lazygit/            # -> ~/.config/lazygit/
│   ├── skhd/               # -> ~/.config/skhd/ (macOS only)
│   ├── yabai/              # -> ~/.config/yabai/ (macOS only)
│   ├── hypr/               # -> ~/.config/hypr/ (Linux only)
│   ├── git/hooks/          # -> ~/.config/git/hooks/
│   ├── .zshrc              # -> ~/.zshrc
│   ├── .ideavimrc          # -> ~/.ideavimrc
│   ├── .gitignore_global   # -> ~/.gitignore_global
│   ├── starship.toml       # -> ~/.config/starship.toml
│   └── Brewfile            # -> ~/Brewfile (macOS only)
├── etc/
│   ├── scripts/            # Setup and utility scripts
│   │   ├── common/         # Shared shell utilities (logging, git helpers)
│   │   ├── install/        # Platform-specific install scripts (mac, arch, common)
│   │   ├── sync_links.sh   # Creates symlinks from src/ to destinations
│   │   ├── install.sh      # Main install entry point
│   │   └── doctor.sh       # Health check script
│   ├── templates/          # Template configs (.gitconfig, .npmrc, .m2)
│   ├── docs/               # Setup guides (mac, wsl, common)
│   └── theme.conf          # Catppuccin Mocha theme reference
└── .gitignore
```

## How Symlinks Work

`etc/scripts/src/install/sync_links.sh` maps each `src/` entry to its destination via `ln -s`. Run it directly or via `install.sh`. Platform detection (`uname`) determines which links apply (macOS includes skhd/yabai/ghostty/Brewfile; Linux includes hypr). Neovim config lives at `src/nvim` and is linked to `~/.config/nvim`.

## Working with This Repo

- **Adding a new tool config**: Create a directory under `src/`, add it to the appropriate `get_macos_links()` or `get_linux_links()` function in `sync_links.sh`, then run the script.
- **Shell scripts**: All scripts use bash, source `common/logging.sh` and `common/utility.sh` for shared functions. Follow the existing pattern of `set -e`, function-based structure, and the logging helpers (`log_info`, `log_success`, `log_warning`, `log_error`).
- **OpenCode config**: `src/opencode/` contains agents (`agent/*.md`), commands (`command/*.md`), and skills (`skills/<name>/SKILL.md`, auto-discovered). Global LLM rules live in `src/opencode/CLAUDE.md`, loaded by opencode via the `instructions` array in `opencode.jsonc`; `src/claude/CLAUDE.md` symlinks to that file (and links to `~/.claude/CLAUDE.md`) so Claude Code reads the same rules. Deprecated items are moved to `_depreciated/` subdirectories within `command/` and `skills/` — they are excluded from auto-discovery.
