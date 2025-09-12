# Dotfiles by Jimmy

A comprehensive, cross-platform dotfiles setup for macOS, Linux (WSL/Arch), and developer productivity. This repo manages configs, scripts, and themes for your terminal, editors, window managers, and more.

## Features

- **Automated setup scripts** for macOS and WSL/Arch Linux
- **Symlink management** for config files
- **Homebrew package management** via `Brewfile`
- **Custom scripts** for repo cloning, updating, and port management
- **Config and themes** for btop, ghostty, lazygit, skhd, yabai, yazi, zellij, and more
- **Yazi file manager plugins** and keymaps
- **User scripts** (e.g., auto-update GitHub branches)

## Structure

```
etc/
  docs/         # Setup guides for macOS, WSL, and common steps
  scripts/      # Shell scripts for install, update, repo cloning, etc.
  userscripts/  # Browser automation scripts
src/
  Brewfile      # Homebrew packages and casks
  starship.toml # Starship prompt config
  ...           # Configs for btop, ghostty, lazygit, skhd, yabai, yazi, zellij
```

## Quick Start

### 1. Clone Essential Repos

```sh
etc/scripts/clone_essential_repos.sh
```

### 2. Run the Install Script

```sh
etc/scripts/install.sh
```
- Symlinks configs to `~/.config`
- Installs Homebrew packages (macOS)
- Sets up configs for all supported tools

### 3. Update Dotfiles

```sh
etc/scripts/update_dotfiles.sh
```

### 4. Sync Secrets

- Place your secrets in `~/Programming/secrets/env.sh`
- Start the dotfiles server and run the sync command (see `etc/docs/setup_common.md`)

## Platform-Specific Setup

- **macOS:** See `etc/docs/setup_mac.md` for Homebrew and service setup (skhd, yabai)
- **WSL/Arch:** See `etc/docs/setup_wsl.md` for installation and user setup

## Highlights

- **Window Management:** `yabai` and `skhd` for tiling and hotkeys
- **Terminal Multiplexing:** `zellij` config and keybinds
- **File Management:** `yazi` with custom plugins and keymaps
- **Prompt:** `starship.toml` for a beautiful, informative shell prompt
- **Resource Monitoring:** `btop` with Catppuccin theme
- **Git Tools:** `lazygit` config and auto-update branch userscript

## Custom Scripts

- `kill_port.sh`: Kill processes by port
- `fetch_all_folders.sh`: Update all git repos in a directory

## Credits

- Catppuccin and Kanagawa themes for terminal and resource monitors
- Various open-source plugins for yazi
