---
name: nvim-keymaps
description: Adds or edits keybindings in this Neovim config (lua/core/keymaps.lua) and their which-key group/label names (lua/plugins/which-key.lua). Use ONLY when changing this repo's Neovim keymaps — adding a binding, re-grouping under a <leader> prefix, fixing a which-key label or icon, or wiring a custom action to a key. Triggers on "add an nvim keymap", "bind a key", "new leader mapping", "fix the which-key group", "map this action to a key".
---

# Neovim keymaps

All keybindings live in `lua/core/keymaps.lua`. Group/label names shown in the
which-key popup live in `lua/plugins/which-key.lua`. Edit both when adding a new
prefix.

## The two helpers (defined at the top of keymaps.lua)

```lua
local function map(mode, lhs, rhs, opts)
  opts = vim.tbl_extend('force', { silent = true, noremap = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

local function maps(mode, mappings)        -- mappings = { { lhs, rhs, desc }, ... }
  for _, m in ipairs(mappings) do
    map(mode, m[1], m[2], { desc = m[3] })
  end
end
```

- Use `maps(mode, { ... })` for a group of related bindings (the common case).
- Use `map(mode, lhs, rhs, opts)` for a one-off or when you need extra `opts`
  (e.g. an `expr` mapping, or a non-default mode).
- Both default to `silent = true, noremap = true` — do not repeat those.

## Add a binding

1. **Require the action module at the top** of `keymaps.lua` if it is not
   already there (the file requires each action module once, e.g.
   `local github_actions = require('custom.actions.github')`).
2. **Add the entry to the matching `maps('n', { ... })` group**, keeping it under
   the right `<leader>` prefix. Format is `{ lhs, rhs, desc }`:
   ```lua
   { '<Leader>ugC', github_actions.select_owner_repo_and_clone, '󰊢 Clone repo' },
   ```
3. **`desc` starts with a nerd-font glyph** then a short imperative label. Match
   the icon family already used in that group.
4. `rhs` is either a function reference (`module.fn`) or a command string
   (`':SomeCmd<CR>'`). Some action factories are **called** to return the handler
   (note the trailing `()`), e.g. `todoist_actions.refresh_todoist_cache()` —
   follow the existing call style for that module.

## Leader-prefix map (register the group in which-key)

Bindings are organised by `<leader>` prefix. Current top-level groups include:

| Prefix | Group |
|--------|-------|
| `<leader>;` | Secondary / dev tools |
| `<leader>c` | Copy & quick access |
| `<leader>v` | Actions / code quality |
| `<leader>r` | Capture & log (`rt` Todoist, `rj` Jira, `rl` Journal, `rn` Notes, `rc` Cache) |
| `<leader>g` | Git (`gb` branch, `gc` commit, `gw` worktree, ...) |
| `<leader>u` | URL / open (`ug` GitHub, `uj` Jira, `ul` Links) |
| `<leader>f` | Find |
| `<leader>J` | Java |
| `<leader>t` | Terminal |
| `<leader>a` | AI |

When you introduce a **new prefix**, add it to the `groups` table in
`lua/plugins/which-key.lua` so the popup shows a named group:

```lua
{ '<leader>x', '󰀫 My New Group' },
```

Entries in `groups` render as `{ key, group = name, mode = { 'n', 'v' } }`; the
`descs` table is for single-key labels. Keep a leading glyph for consistency.

## Verify

- `selene lua` is clean.
- `stylua --check .` passes.
- `nvim --headless +qa` loads without the `Failed to load core.keymaps`
  notification.
- Open Neovim, press `<leader>`, and confirm the new binding shows under the
  expected group with the right label.
