# Innovate: Yazi Configuration Improvements

## Overview

The yazi config at `src/yazi/` has a solid base with git integration, relative motions, bookmarks, smart-enter, smart-filter, and copy-file-contents. However there are bugs, unused plugins, missing theming, and several high-value additions that would improve the daily file-management workflow.

## Architecture

All changes are confined to `src/yazi/`. After editing, run `sync_links.sh` to propagate symlinks to `~/.config/yazi/`.

- `yazi.toml` — core settings, plugin fetchers/previewers, opener rules
- `keymap.toml` — keybindings
- `init.lua` — plugin initialization
- `package.toml` — plugin dependencies

## Tasks

### 1. Fix duplicate `g, d` keybinding (BUG)
- **File**: `src/yazi/keymap.toml`
- **What**: Lines 92-98 bind `g, d` to `~/Downloads`, lines 101-104 rebind `g, d` to `~/.config`. The second silently overrides the first. Change config dir to `g, c` (mnemonic: config).
- **Complexity**: small
- **Parallel**: yes

### 2. Activate `skip-single.yazi` plugin
- **File**: `src/yazi/keymap.toml`
- **What**: The plugin exists in `plugins/` but has no keybinding or integration. Bind it to `l` as a wrapper or chain it with smart-enter. Alternatively bind to `<A-l>` to skip into single-child directories.
- **Complexity**: small
- **Parallel**: yes

### 3. Add Catppuccin Mocha flavor
- **File**: `src/yazi/package.toml`, `src/yazi/yazi.toml`
- **What**: Add `catppuccin-mocha` flavor from `yazi-rs/flavors`. Set `[flavor]` in `package.toml` and reference it in `yazi.toml` via `[mgr]` or `[flavor]` section. This aligns with the dotfiles-wide Catppuccin Mocha theme.
- **Complexity**: small
- **Parallel**: yes

### 4. Add `full-border` plugin for visual clarity
- **File**: `src/yazi/package.toml`, `src/yazi/init.lua`
- **What**: Add `yazi-rs/plugins:full-border` to draw borders around all panes. Initialize in `init.lua`.
- **Complexity**: small
- **Parallel**: yes

### 5. Add `chmod` plugin for quick permission changes
- **File**: `src/yazi/package.toml`, `src/yazi/keymap.toml`
- **What**: Add `yazi-rs/plugins:chmod`. Bind to `c, m` in keymap. Useful for making scripts executable without leaving yazi.
- **Complexity**: small
- **Parallel**: yes

### 6. Add `diff` plugin for quick file diffs
- **File**: `src/yazi/package.toml`, `src/yazi/keymap.toml`
- **What**: Add `yazi-rs/plugins:diff`. Bind to `<A-d>`. Allows diffing selected file against hovered file.
- **Complexity**: small
- **Parallel**: yes

### 7. Add `max-preview` toggle
- **File**: `src/yazi/package.toml`, `src/yazi/keymap.toml`, `src/yazi/init.lua`
- **What**: Add `yazi-rs/plugins:max-preview`. Bind to `T` to toggle maximized preview pane. Useful for reading code files.
- **Complexity**: small
- **Parallel**: yes

### 8. Add custom opener rules
- **File**: `src/yazi/yazi.toml`
- **What**: Add `[opener]` section to open common file types in preferred apps: `.md`/code files in `$EDITOR`, images in Preview.app, PDFs in Preview.app. Currently relies on system defaults which may not be optimal.
- **Complexity**: small
- **Parallel**: yes

### 9. Re-enable media previews with proper previewers
- **File**: `src/yazi/yazi.toml`
- **What**: The config noop's all media/archive previews. Consider selectively enabling image preview (yazi supports Kitty/Ghostty graphics protocol). At minimum, enable image previews since Ghostty supports the protocol. Keep archive/video/audio as noop if terminal can't handle them.
- **Complexity**: medium
- **Parallel**: yes

### 10. Add `zoxide` integration for smart directory jumping
- **File**: `src/yazi/keymap.toml`
- **What**: Yazi has built-in zoxide support. Add keybinding `z` for `cd --interactive` (zoxide jump). This is built-in, no plugin needed — just needs the keymap entry.
- **Complexity**: small
- **Parallel**: yes

### 11. Add `fzf` integration for fuzzy file search
- **File**: `src/yazi/keymap.toml`
- **What**: Bind `<C-f>` to a shell command that uses `fzf` + `fd` to fuzzy-find files and navigate to the result. Can use yazi's built-in `shell` command.
- **Complexity**: small
- **Parallel**: yes

## Edge Cases

- Plugin version pinning: `package.toml` uses rev hashes. After adding new plugins, run `ya pack -i` to install and lock versions.
- Ghostty graphics protocol support should be verified for image preview — if not working, keep the noop.
- The `skip-single` plugin uses `ya.sleep(0.05)` which may cause slight lag in deep single-child chains.

## Testing Approach

- Manual verification: open yazi after `sync_links.sh`, test each keybinding
- Verify no keybinding conflicts by checking for duplicate `on` values in keymap
- Verify plugins load without errors: `yazi --debug`

## Decisions

1. **[Conventions]** Decision: Enable image previews via Ghostty graphics protocol. Keep other media (video, audio, archives) as noop.
2. **[Scope]** Decision: Current quick-nav paths are sufficient. No additions needed.
3. **[Requirements]** Decision: Auto-activate skip-single on `l`/smart-enter — chain it so navigating right automatically skips through single-child directories.
