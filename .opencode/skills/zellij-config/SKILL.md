---
name: zellij-config
description: Edits this dotfiles repo's Zellij config under src/zellij — config.kdl (locked-mode, Alt-prefixed keybinds, plugins, options), the Catppuccin Mocha theme in catppuccin.kdl, and the KDL pane layouts in src/zellij/layouts/ — which is symlinked to ~/.config/zellij. Many Alt binds shell out via `Run` to launcher scripts in etc/scripts/src/zellij/ that drive `zellij action` to build opencode/nvim pane layouts and reindex tab names. Use ONLY when changing this repo's Zellij config — adding or rebinding an Alt keybind, adding/editing a pane layout, retheming, or wiring a layout to a launcher keybind. Triggers on "add a zellij keybind", "new zellij layout", "edit src/zellij", "zellij config.kdl", "opencode sidebar layout", "rebind Alt". For launcher script bodies use dotfiles-shell-scripts; for the src/zellij↔~/.config/zellij symlink use add-tool-config or sync-and-doctor.
---

# Zellij config (src/zellij)

KDL config managed in `src/zellij`, symlinked to `~/.config/zellij`. Edit files
under `src/zellij` — never the live config dir. Catppuccin Mocha throughout.

## Where things live

```
src/zellij/
├── config.kdl          # keybinds (locked default mode), plugins, ui, options
├── catppuccin.kdl      # `themes { ... }` block, imported by config.kdl
└── layouts/            # one KDL pane layout per file
    └── opencode-sidebar.kdl # Alt p — base layout: 30% stacked tool sidebar + nvim main pane

etc/scripts/src/zellij/   # launcher scripts the binds Run (see dotfiles-shell-scripts)
├── open_opencode_sidebar.sh # Alt p — pick tool → project → tool sidebar + nvim layout
├── open_project.sh          # Alt [ — pick tool (nvim/opencode/storecode/empty) → open in the right pane's dir as a stacked pane
├── open_project_last.sh     # Alt ] — open last tool in the right pane's dir as a new stacked pane (no prompt)
├── select_session.sh        # Alt u — fzf session switcher
└── update_tab_indexes.sh    # re-prefixes tab names with position (1.foo, 2.bar)
```

The `zellij` link is a *common* link (`src/zellij` → `~/.config/zellij`),
registered in both `sync_links.sh` and `doctor.sh` — see `add-tool-config` /
`sync-and-doctor`.

## The keybind model (config.kdl)

`keybinds clear-defaults=true` discards Zellij's defaults — every bind is
explicit. `default_mode "locked"` starts the session in **locked** mode, so
binds live in a `locked` block and a `shared_among "normal" "locked"` block.
The modifier is `Alt` (e.g. `bind "Alt p" { ... }`), and each Alt bind ends with
`SwitchToMode "locked"` to return to locked.

Two bind flavours:

- **Direct actions** — `NewTab`, `CloseTab`, `MoveTab "Left"`, `NewPane "down"`,
  `MoveFocus "left"`, `GoToTab 1`, `ToggleFocusFullscreen`, `CloseFocus`,
  `LaunchOrFocusPlugin "session-manager" { floating true; }`.
- **Shell-outs** — `Run "zsh" "-c" "$HOME/.../etc/scripts/src/zellij/<x>.sh" { close_on_exit true; in_place true; }`.
  Use `in_place true` to run over the focused pane (layout launchers) or
  `floating true` for a transient helper (the tab reindexer); always
  `close_on_exit true` so the launcher pane disappears when the script exits.

## Add / rebind a keybind

1. Pick a free `Alt <key>`. Taken: `; w r n q i o p ] [ u y d e Enter x`,
   arrows, and `1`-`9`. Free again: `\` and `'`. There is no collision guard —
   check `config.kdl` first.
2. Add it inside `shared_among "normal" "locked"`:
   ```kdl
   bind "Alt t" { NewPane "right"; SwitchToMode "locked"; }
   ```
   To launch a script/layout, follow the shell-out pattern and end with
   `SwitchToMode "locked"`:
   ```kdl
   bind "Alt t" { Run "zsh" "-c" "$HOME/Programming/JimmyTranDev/dotfiles/etc/scripts/src/zellij/my_launcher.sh" { close_on_exit true; in_place true; }; SwitchToMode "locked"; }
   ```
3. Reference scripts by their absolute `$HOME/Programming/JimmyTranDev/dotfiles/etc/scripts/src/zellij/<name>.sh`
   path, matching the existing binds — relative paths won't resolve from a
   pane's cwd.

## Add / edit a layout (src/zellij/layouts/<name>.kdl)

Layouts are KDL under a root `layout` node. Building blocks:

- `pane` — bare (default shell), `command="opencode"` (run a program), or a
  logical container with `split_direction="vertical"|"horizontal"` (default
  `horizontal`).
- Sizing: percentage `size="30%"` or fixed `size=1`. Put `focus=true` on the
  pane that should hold focus on start (only the first focused pane wins).
- Status bar: end with a 1-row borderless plugin pane:
  ```kdl
  pane size=1 borderless=true { plugin location="zellij:compact-bar" }
  ```

Launchers open a layout with
`zellij action new-tab --cwd "$dir" --layout ~/.config/zellij/layouts/<name>.kdl`.
To add a layout + keybind: drop the `.kdl` in `layouts/`, add or clone a launcher
script (use `dotfiles-shell-scripts`), then bind an `Alt <key>` to `Run` it.

## Theme

`config.kdl` does `import "catppuccin.kdl"` then `theme "catppuccin-mocha"`.
`catppuccin.kdl` defines all four Catppuccin flavours under `themes { ... }`.
Keep Mocha the active theme (repo-wide invariant).

## Red flags

- Editing `~/.config/zellij/*` directly instead of `src/zellij/*` (it's a symlink).
- A `Run` bind missing `close_on_exit true` (leaves a dead pane) or the trailing
  `SwitchToMode "locked"`.
- A relative script path in `Run` (won't resolve), or a new bind that collides
  with an existing `Alt` key.
- Switching the theme away from `catppuccin-mocha`.
- Writing the launcher script body here — that belongs to `dotfiles-shell-scripts`.

## Verify

- Config parses: `zellij setup --check` (reports config/layout errors).
- A new/edited layout loads: from inside a session,
  `zellij action new-tab --layout ~/.config/zellij/layouts/<name>.kdl` (then
  close the tab).
- After symlink-relevant changes, `etc/scripts/src/install/doctor.sh` passes.
- Theme is still `catppuccin-mocha`, and the new bind doesn't shadow an existing
  `Alt` key.
