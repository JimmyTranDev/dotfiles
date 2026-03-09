---
name: zellij-setup
description: Zellij terminal multiplexer configuration including keybindings, tab naming, plugin setup, and shell integration
---

## Configuration Files

- `src/zellij/config.kdl` — main config (KDL format)
- `src/zellij/catppuccin.kdl` — theme definitions (imported by config.kdl)
- Symlinked to `~/.config/zellij/`

## Global Settings

| Setting | Value |
|---------|-------|
| `theme` | `catppuccin-mocha` |
| `default_mode` | `locked` |
| `default_shell` | `zsh` |
| `pane_frames.rounded_corners` | `true` |
| `tab_bar.display_tab_index` | `true` |

## Modal Architecture

Default mode is `locked` — all keybindings are opt-in. The flow is:

```
locked -> Alt ; -> normal -> letter -> sub-mode -> action -> locked (auto-return)
```

### Modes and Entry Keys

| Mode | Entry | Purpose |
|------|-------|---------|
| `locked` | Default | Minimal bindings, safe typing |
| `normal` | `Alt ;` | Hub for entering sub-modes |
| `pane` | `p` | Navigate, split, close, float, fullscreen |
| `tab` | `t` | Navigate, create, close, rename, sync |
| `resize` | `r` | Pane resizing (hjkl = increase, HJKL = decrease) |
| `move` | `m` | Pane moving |
| `scroll` | `s` | Scrollback (vim-style) |
| `search` | `f` (from scroll) | Search within scrollback |
| `session` | `o` | Session management, plugins |

### Shared Bindings (available in locked + normal)

| Key | Action |
|-----|--------|
| `Alt h/j/k/l` or `Alt arrows` | Navigate panes/tabs |
| `Alt r` | Rename current tab |
| `Alt n` | New tab |
| `Alt q` | Close tab |
| `Alt i` / `Alt o` | Move tab left / right |
| `Alt u` | Re-index all tab numbers |
| `Alt 1-9` | Jump to tab by number |

## Navigation

All navigation uses **vim-style hjkl** plus arrow keys. Uppercase HJKL only in resize mode for decrease direction.

## Tab Naming Convention

Tabs follow `{index}. {directory_name}` format (e.g., `1. dotfiles`, `2. myproject`).

### How It Works

1. **On directory change**: `chpwd_functions` hook in `.zshrc` calls `zellij_tab_name_update()`
2. **On tab mutation**: A zsh wrapper around `zellij` command calls `zellij_tab_name_update()` after `new-tab`, `close-tab`, `go-to-tab`, `move-tab`, `toggle-tab`, `break-pane*`
3. **Manual re-index**: `Alt u` (in zellij) or `Ctrl+U` (in zsh) runs `zellij_update_tab_indexes.sh` to renumber all tabs sequentially

### Tab name formatting
- Strips JIRA-style prefixes: `BW-10257-feature-name` becomes `feature-name`
- Truncates to 20 characters (configurable via `ZELLIJ_TAB_NAME_MAX_LENGTH`)
- Format: `{tab_index}. {cleaned_dirname}`

## Plugins

All built-in, no third-party WASM plugins:

```kdl
plugins {
    compact-bar location="zellij:compact-bar"
    configuration location="zellij:configuration"
    filepicker location="zellij:strider" { cwd "/" }
    plugin-manager location="zellij:plugin-manager"
    session-manager location="zellij:session-manager"
    status-bar location="zellij:status-bar"
    strider location="zellij:strider"
    tab-bar location="zellij:tab-bar"
    welcome-screen location="zellij:session-manager" { welcome_screen true }
}
```

Plugins are launched via `LaunchOrFocusPlugin` in session mode with `floating true`.

## Shell Integration (zsh)

### Aliases
| Alias | Action |
|-------|--------|
| `zj` | `zellij` |
| `zja` | `zellij attach` |
| `zjl` | `zellij list-sessions` |
| `zellij-enable-auto` | Enable auto-attach on terminal open |
| `zellij-disable-auto` | Disable auto-attach |

### Keybindings
| Key | Action |
|-----|--------|
| `Ctrl+U` | Re-index all tab numbers (ZLE widget) |

### Ghostty Integration
`etc/scripts/ghostty_zellij_startup.sh` auto-starts Zellij when Ghostty opens:
- Attaches to existing session or creates new one
- Guards against nested sessions (`$ZELLIJ` and `$TMUX` checks)
- Uses `exec` to replace the shell process
- Toggle with `ghostty-use-script` / `ghostty-use-zsh` aliases

## Helper Scripts

| Script | Purpose |
|--------|---------|
| `zellij_update_tab_name.sh` | Update current tab name based on cwd |
| `zellij_update_tab_indexes.sh` | Re-index all tabs sequentially after reordering |
| `ghostty_zellij_startup.sh` | Auto-start Zellij in Ghostty terminal |

## When Modifying Zellij Config

1. Edit files in `src/zellij/` (symlinked, changes take effect on next session)
2. Use KDL format
3. Keep the `clear-defaults=true` pattern — define all keybindings explicitly
4. Actions should always end with `SwitchToMode "locked"` to auto-return
5. No custom layout files — use the default layout
6. Theme is `catppuccin-mocha`, defined in the imported `catppuccin.kdl`
