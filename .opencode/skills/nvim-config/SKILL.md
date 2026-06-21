---
name: nvim-config
description: Edits the Neovim configuration under src/nvim in this dotfiles repo (lazy.nvim plugin specs, keymaps, custom action/util modules, LSP servers, selene lint). Use ONLY when changing this repo's Neovim Lua config — adding a keymap, writing a custom action, adding/configuring a plugin, or fixing lint. Triggers on "add an nvim keymap", "new nvim action", "add an nvim plugin", "edit src/nvim", "fix the nvim lua lint". Distinct from reading terminal output inside nvim.
---

# Neovim config (src/nvim)

Lua config managed with **lazy.nvim**, symlinked to `~/.config/nvim`. Edit files
under `src/nvim` — never the live config dir.

## Load order

`init.lua` → `core.lazy` (bootstraps lazy.nvim from `lua/core/lazy.lua`) → then
`require`s `core.options`, `core.plugins`, `core.commands`, `core.keymaps`.
`core.plugins` calls `lazy.setup{ spec = { { import = 'plugins' } } }`, so every
file in `lua/plugins/` is auto-imported. Default colorscheme is `catppuccin`;
`version = false` (plugins track latest commits, pinned by `lazy-lock.json`).

## Where things live

```
src/nvim/
├── init.lua
├── lua/core/        # options, keymaps, lazy, plugins, commands, statusline, constants
├── lua/plugins/     # one file per plugin = a lazy.nvim spec  (_depreciated/ is ignored)
├── lua/custom/
│   ├── actions/     # feature modules invoked by keymaps (module pattern: local M = {} ... return M)
│   ├── utils/       # shared helpers (git, github, json, input, ui, async, ...)
│   └── constants/
├── lua/lsp/servers.lua
├── selene.toml      # lint config (std = "vim+custom")
├── vim.yml / custom.yml   # selene std-lib globals (vim API + project globals)
└── lazy-lock.json   # pinned plugin commit lockfile
```

## Add a keymap (`lua/core/keymaps.lua`)

1. Ensure the action module is required at the top (e.g.
   `local github_actions = require('custom.actions.github')`).
2. Add an entry to the relevant `maps('n', { ... })` group:
   ```lua
   { '<Leader>ugC', github_actions.select_owner_repo_and_clone, '󰊢 Clone repo' },
   ```
   Format is `{ lhs, rhs, desc }`. Keep a leading nerd-font icon in `desc`, and
   respect the existing which-key prefix grouping (`<Leader>ug*` = GitHub, etc.).
   Use `map(mode, lhs, rhs, opts)` for one-offs; both default to
   `silent = true, noremap = true`.

## Add a custom action (`lua/custom/actions/<name>.lua`)

- Module pattern: `local M = {}` ... define `function M.do_thing() end` ...
  `return M`. Keymaps call `M.*` functions.
- Reuse `custom.utils.*` (e.g. `custom.utils.github`, `custom.utils.input`,
  `custom.utils.json`) instead of re-implementing helpers.
- Prefer the modern Neovim API already used here: `vim.uv` (libuv),
  `vim.system({...}, { text = true }, vim.schedule_wrap(cb))` for async
  subprocess, `vim.ui.select`, `vim.notify(msg, vim.log.levels.*)`, and
  `require('snacks').picker{...}` for rich pickers (guard with `pcall`).

## Add / configure a plugin (`lua/plugins/<name>.lua`)

- Create one file returning a lazy spec (a table or list of tables):
  ```lua
  return {
    'owner/plugin',
    event = 'VeryLazy',
    opts = { ... },
  }
  ```
- It is imported automatically — no central registry to edit.
- After adding, run `:Lazy sync` (updates `lazy-lock.json`); commit the updated
  lockfile. Move retired specs to `lua/plugins/_depreciated/` (excluded from
  import) rather than deleting outright when you want history.

## Lint

Lint Lua with **selene** (config `src/nvim/selene.toml`, `std = "vim+custom"`):
```bash
selene src/nvim/lua        # or: cd src/nvim && selene lua
```
If you introduce a new global that selene flags, add it to `custom.yml` rather
than disabling the lint.

## Verify

- `selene src/nvim/lua` is clean.
- Sanity-load: `nvim --headless "+Lazy! sync" +qa` (network needed) or
  `nvim --headless +qa` to catch load-time Lua errors via `init.lua`'s `pcall`
  notifications.
- `:checkhealth` for plugin/runtime issues when relevant.
- Keep Catppuccin Mocha theming intact (`lua/plugins/catppuccin.lua`).
