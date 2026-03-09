---
name: neovim-config
description: Neovim configuration architecture, plugin management with lazy.nvim, and integration with the dotfiles ecosystem
---

## Architecture

The Neovim config lives in a **separate repository**, not inside the dotfiles repo:

- **Repository**: `github.com:JimmyTranDev/nvim.git`
- **Clone location**: `~/Programming/JimmyTranDev/nvim`
- **Symlink**: `~/.config/nvim` -> `~/Programming/JimmyTranDev/nvim`
- **Plugin manager**: lazy.nvim (`lazy-lock.json` for lockfile)

The dotfiles repo manages everything *around* neovim:
- Installing the `neovim` binary (Brewfile / pacman)
- Cloning the nvim config repo during install
- Creating the symlink via `sync_links.sh`
- Configuring other tools to use nvim (git, lazygit, man pager)

## Tool Integration

### Git editor
```gitconfig
editor = nvim -u ~/Programming/nvim/init.lua --cmd 'set rtp+=~/Programming/nvim'
```

### Lazygit
```yaml
editPreset: 'nvim'
```

### Man pager
```zsh
export MANPAGER='nvim +Man!'
```

### Shell alias
```zsh
alias n='nvim'
```

## Related Tools

Lua development tooling installed via Brewfile:
- `stylua` — Lua formatter
- `luarocks` — Lua package manager
- `luacheck` — Lua linter

## Health Check

`doctor.sh` verifies:
- `nvim` command is available
- `~/Programming/JimmyTranDev/nvim` directory exists
- `~/.config/nvim` symlink points to the correct target

## When Working on the Nvim Config

1. Navigate to `~/Programming/JimmyTranDev/nvim`
2. The config uses Lua (init.lua + lua/ directory)
3. Plugin management is via lazy.nvim
4. Changes are committed separately from the dotfiles repo
5. Follow the same commit conventions (emoji + conventional commits)

## IdeaVim

JetBrains IDE vim keybindings are configured separately in `src/.ideavimrc` and emulate nvim plugins: leap.nvim, hop.nvim, nvim-surround, which-key.nvim, and others.
