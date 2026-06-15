---
name: tool-zellij
description: Zellij terminal multiplexer patterns covering KDL config, keybindings, modes, panes, tabs, layouts, plugins, sessions, and theme configuration
---

## Config Format

Zellij uses KDL (KDocument Language) for configuration. Config location: `~/.config/zellij/config.kdl`.

```kdl
keybinds clear-defaults=true {
    locked {
        bind "Alt ;" { SwitchToMode "normal"; }
    }
}

theme "catppuccin-mocha"
default_mode "locked"
default_shell "zsh"
```

## Modes

| Mode | Purpose | Entry |
|------|---------|-------|
| `normal` | Default unlocked mode | Base mode |
| `locked` | Ignores most keybinds | `SwitchToMode "locked"` |
| `pane` | Pane operations | `SwitchToMode "pane"` |
| `tab` | Tab operations | `SwitchToMode "tab"` |
| `resize` | Resize panes | `SwitchToMode "resize"` |
| `move` | Move panes | `SwitchToMode "move"` |
| `scroll` | Scroll buffer | `SwitchToMode "scroll"` |
| `search` | Search buffer | `SwitchToMode "search"` |
| `session` | Session management | `SwitchToMode "session"` |
| `entersearch` | Type search query | `SwitchToMode "entersearch"` |
| `renametab` | Rename active tab | `SwitchToMode "renametab"` |
| `renamepane` | Rename active pane | `SwitchToMode "renamepane"` |

## Keybind Blocks

```kdl
keybinds clear-defaults=true {
    // Mode-specific bindings
    pane {
        bind "n" { NewPane; SwitchToMode "locked"; }
    }

    // Shared across specific modes
    shared_among "normal" "locked" {
        bind "Alt n" { NewPane; }
    }

    // Shared across all modes except listed
    shared_except "locked" "renametab" "renamepane" {
        bind "esc" { SwitchToMode "locked"; }
    }
}
```

## Pane Actions

| Action | Description |
|--------|-------------|
| `NewPane` | New pane (auto direction) |
| `NewPane "down"` | Split horizontally |
| `NewPane "right"` | Split vertically |
| `CloseFocus` | Close focused pane |
| `MoveFocus "left/down/up/right"` | Move focus |
| `MovePane "left/down/up/right"` | Move pane position |
| `ToggleFocusFullscreen` | Toggle fullscreen |
| `TogglePaneEmbedOrFloating` | Toggle embed/float |
| `ToggleFloatingPanes` | Toggle all floating panes |
| `TogglePaneFrames` | Toggle pane borders |
| `SwitchFocus` | Cycle focus |
| `PaneNameInput 0` | Clear and start name input |

## Tab Actions

| Action | Description |
|--------|-------------|
| `GoToTab 1` | Go to tab by index |
| `GoToNextTab` | Next tab |
| `GoToPreviousTab` | Previous tab |
| `ToggleTab` | Toggle last active tab |
| `BreakPane` | Break pane to new tab |
| `BreakPaneLeft` | Break pane to tab left |
| `BreakPaneRight` | Break pane to tab right |
| `ToggleActiveSyncTab` | Sync input across panes |
| `TabNameInput 0` | Clear and start name input |

## Resize Actions

| Action | Description |
|--------|-------------|
| `Resize "Increase left"` | Grow left |
| `Resize "Decrease left"` | Shrink left |
| `Resize "Increase"` | Grow all directions |
| `Resize "Decrease"` | Shrink all directions |

## Scroll and Search Actions

| Action | Description |
|--------|-------------|
| `ScrollDown` / `ScrollUp` | Line scroll |
| `PageScrollDown` / `PageScrollUp` | Page scroll |
| `HalfPageScrollDown` / `HalfPageScrollUp` | Half-page scroll |
| `ScrollToBottom` | Jump to bottom |
| `EditScrollback` | Open scrollback in `$EDITOR` |
| `SearchInput 0` | Clear and start search input |
| `Search "down"` / `Search "up"` | Navigate matches |
| `SearchToggleOption "CaseSensitivity"` | Toggle case-sensitive |
| `SearchToggleOption "WholeWord"` | Toggle whole-word |
| `SearchToggleOption "Wrap"` | Toggle wrap |

## Session Actions

| Action | Description |
|--------|-------------|
| `Detach` | Detach from session |
| `Quit` | Quit Zellij |
| `LaunchOrFocusPlugin "session-manager"` | Open session manager |
| `LaunchOrFocusPlugin "plugin-manager"` | Open plugin manager |
| `LaunchOrFocusPlugin "configuration"` | Open config UI |

## Run Action (External Commands)

```kdl
bind "n" {
    Run "zsh" "-c" "/path/to/script.sh" {
        close_on_exit true
        in_place true
    }
    SwitchToMode "locked"
}
```

| Option | Description |
|--------|-------------|
| `close_on_exit true` | Close pane when command exits |
| `in_place true` | Run in current pane instead of new one |

## Plugins

```kdl
plugins {
    compact-bar location="zellij:compact-bar"
    configuration location="zellij:configuration"
    filepicker location="zellij:strider" {
        cwd "/"
    }
    plugin-manager location="zellij:plugin-manager"
    session-manager location="zellij:session-manager"
    status-bar location="zellij:status-bar"
    strider location="zellij:strider"
    tab-bar location="zellij:tab-bar"
    welcome-screen location="zellij:session-manager" {
        welcome_screen true
    }
}
```

Plugin launch in keybinds:

```kdl
bind "w" {
    LaunchOrFocusPlugin "session-manager" {
        floating true
        move_to_focused_tab true
    }
    SwitchToMode "locked"
}
```

## UI Settings

```kdl
ui {
    pane_frames {
        rounded_corners true
    }
    tab_bar {
        display_tab_index true
        hide_session_name true
    }
}
```

## Layouts

Layout files go in `~/.config/zellij/layouts/`. Format is KDL.

```kdl
layout {
    pane size=1 borderless=true {
        plugin location="zellij:tab-bar"
    }
    pane split_direction="vertical" {
        pane
        pane
    }
    pane size=2 borderless=true {
        plugin location="zellij:status-bar"
    }
}
```

| Attribute | Values |
|-----------|--------|
| `size` | Fixed row/col count |
| `borderless` | `true` / `false` |
| `split_direction` | `"horizontal"` / `"vertical"` |
| `focus` | `true` to auto-focus |
| `name` | Pane display name |
| `cwd` | Working directory |
| `command` | Command to run |
| `args` | Command arguments |

## CLI Commands

| Command | Description |
|---------|-------------|
| `zellij` | Start new session |
| `zellij -s <name>` | Start named session |
| `zellij attach <name>` | Attach to session |
| `zellij ls` | List sessions |
| `zellij kill-session <name>` | Kill session |
| `zellij kill-all-sessions` | Kill all sessions |
| `zellij action new-tab` | Create tab via CLI |
| `zellij action rename-tab <name>` | Rename tab via CLI |
| `zellij action go-to-tab <index>` | Switch tab via CLI |
| `zellij action write-chars <text>` | Type text into focused pane |
| `zellij plugin -- <url>` | Launch plugin |

## Theme Import

```kdl
import "catppuccin.kdl"
theme "catppuccin-mocha"
```

Theme files define color schemes in KDL:

```kdl
themes {
    catppuccin-mocha {
        bg "#585b70"
        fg "#cdd6f4"
        red "#f38ba8"
        green "#a6e3a1"
        blue "#89b4fa"
        yellow "#f9e2af"
        magenta "#f5c2e7"
        orange "#fab387"
        cyan "#89dceb"
        black "#181825"
        white "#cdd6f4"
    }
}
```
