---
name: dotfiles-management
description: How this dotfiles repo is structured, how to add new configs, symlink patterns, and the install flow
---

## Repository Structure

```
dotfiles/
  src/             # Config source files — symlinked to ~/.config/ or ~/
  etc/
    scripts/       # Automation: install, sync, doctor, worktrees, utilities
    templates/     # Config templates with {{PLACEHOLDER}} vars (gitconfig, npmrc, settings.xml)
    docs/          # Setup guides (mac, wsl, common)
    theme.conf     # Catppuccin variant selector
    .github/       # Copilot instructions
  README.md
  LICENSE          # Apache 2.0
```

## How Configs Are Installed

The entire system is symlink-based. `src/<config>` is symlinked to its final location.

### Symlink Mapping (macOS)

| Source | Destination |
|--------|------------|
| `src/opencode` | `~/.config/opencode` |
| `src/zellij` | `~/.config/zellij` |
| `src/yazi` | `~/.config/yazi` |
| `src/lazygit` | `~/.config/lazygit` |
| `src/btop` | `~/.config/btop` |
| `src/ghostty` | `~/.config/ghostty` |
| `src/kitty` | `~/.config/kitty` |
| `src/skhd` | `~/.config/skhd` (macOS only) |
| `src/yabai` | `~/.config/yabai` (macOS only) |
| `src/git/hooks` | `~/.config/git/hooks` |
| `src/.zshrc` | `~/.zshrc` |
| `src/.ideavimrc` | `~/.ideavimrc` |
| `src/.gitignore_global` | `~/.gitignore_global` |
| `src/Brewfile` | `~/Brewfile` |
| `src/starship.toml` | `~/.config/starship.toml` |
| `~/Programming/JimmyTranDev/nvim` | `~/.config/nvim` (separate repo) |

Linux adds `src/hypr` -> `~/.config/hypr` and removes macOS-only entries.

### Install Flow

1. `etc/scripts/install.sh` — entry point, detects platform
2. `etc/scripts/install/common.sh` — installs Oh My Zsh, clones nvim-config repo, runs `sync_links.sh`, generates templated configs from `etc/templates/`
3. `etc/scripts/install/mac.sh` or `arch.sh` — platform packages
4. `etc/scripts/sync_links.sh` — creates/updates all symlinks with backup

### Template System

Templates in `etc/templates/` use `{{VARIABLE}}` placeholders replaced by `sed` during install. Variables are sourced from `~/Programming/JimmyTranDev/secrets/env.sh`:
- `{{HOME}}`, `{{PRI_EMAIL}}`, `{{PRI_GITHUB_USERNAME}}`, `{{PRI_GITHUB_TOKEN}}`, `{{ORG_GITHUB_NAME}}`

## How to Add a New Config

1. Create the config directory or file under `src/`
2. Add the symlink mapping to `etc/scripts/sync_links.sh` in both `get_macos_links()` and `get_linux_links()` (or just one if platform-specific)
3. Add a health check to `etc/scripts/doctor.sh` for the required tool and symlink
4. If the tool needs installing, add it to `src/Brewfile` (macOS) and `etc/scripts/install/arch.sh` (Linux)
5. Run `L` (alias for `sync_links.sh`) to create the symlink

## Key Aliases

| Alias | Action |
|-------|--------|
| `I` | Run full install (`install.sh`) |
| `L` | Sync symlinks (`sync_links.sh`) |
| `C` | chmod +x all scripts |
| `F` | Pull all repos across orgs |

## Health Checks

`etc/scripts/doctor.sh` validates:
- Default shell is zsh
- Oh My Zsh installed
- Required tools: git, nvim, fzf, rg, fd, starship, zellij, yazi, lazygit, bat, jq (+ brew/yabai/skhd on macOS)
- All symlinks point to correct targets
- Required directories exist (`~/Programming`, dotfiles repo, nvim config, secrets)
- Git hooks path and global gitignore configured

## Conventions

- **Catppuccin Mocha** is the unified theme across all tools
- **Neovim config** lives in a separate repo (`JimmyTranDev/nvim`), cloned to `~/Programming/JimmyTranDev/nvim`
- **Secrets** are kept in `~/Programming/JimmyTranDev/secrets/` (never committed to dotfiles)
- **Project organization**: `~/Programming/{OrgName}/{RepoName}`
- **Worktrees**: `~/Programming/wcreated/{branch-name}`
- Backup existing non-symlink files to `~/.dotfiles-backup/YYYYMMDD_HHMMSS/` before overwriting
