# AGENTS.md — Neovim config (project scope)

Project rules for working **on this Neovim configuration**. Loaded via
`.opencode/opencode.json` (`instructions: ["AGENTS.md"]`).

This repo is a self-contained Lua config managed with **lazy.nvim**. It lives at
`src/nvim/` inside the dotfiles repo and is symlinked to `~/.config/nvim`, so the
**repo root is the Neovim runtime root**: `init.lua`, `lua/`, `selene.toml`, and
`lazy-lock.json` sit at the top level. Paths in this file are relative to that
root (when working from the dotfiles repo, prefix them with `src/nvim/`).

## Project skills

These skills live in `.opencode/skills/<name>/SKILL.md` and are auto-discovered.
Invoke the matching one with the `skill` tool **before** acting.

| Intent | Skill |
|--------|-------|
| Add/edit a keybinding, fix a which-key group or label | `nvim-keymaps` |
| Write/edit a custom action or util module under `lua/custom/` | `nvim-actions` |
| Add/configure/remove a plugin (a lazy.nvim spec in `lua/plugins/`) | `nvim-plugins` |
| Add/configure a language server, Mason install, or formatter | `nvim-lsp` |
| Fix lint/format, add a selene global, run stylua | `nvim-lua-style` |

Global lifecycle skills (`commit`, `git-workflow-and-versioning`,
`code-review-and-quality`, `debugging-and-error-recovery`, ...) still apply. When
a global skill and a project skill both fit, run the project skill for the
repo-specific mechanics.

## Load order

`init.lua` →
1. `require('core.lazy')` — bootstraps lazy.nvim into `stdpath('data')/lazy`
   (`M.bootstrap()` runs on require; clones the `stable` branch if missing).
2. then `pcall`-requires, in order: `core.options`, `core.plugins`,
   `core.commands`, `core.keymaps`. Each is wrapped so a failure is reported via
   `vim.notify(... ERROR)` instead of aborting startup.

`core.plugins` calls `lazy.setup{ spec = { { import = 'plugins' } }, ... }`, so
**every file directly under `lua/plugins/` is auto-imported** as a spec. Defaults:
`lazy = true` (everything lazy-loaded) and `version = false` (track latest
commits, pinned by `lazy-lock.json`). Default colorscheme is `catppuccin`.

## Where things live

```
.
├── init.lua
├── lua/core/        # options, lazy, plugins, commands, keymaps, statusline, constants
├── lua/plugins/     # one file per plugin = a lazy.nvim spec  (_depreciated/ is NOT imported)
├── lua/custom/
│   ├── actions/     # feature modules invoked by keymaps (local M = {} ... return M)
│   ├── utils/       # shared helpers (git, github, json, input, ui, async, ...)
│   └── constants/
├── lua/lsp/servers.lua   # M.servers table — the source of truth for LSP + Mason
├── selene.toml      # lint config (std = "vim+custom")
├── vim.yml / custom.yml  # selene std-lib globals (vim API + project globals)
├── .stylua.toml     # Lua formatter config (160 cols, 2-space, single quotes)
├── .luarc.json / .luacheckrc   # lua_ls + luacheck globals
└── lazy-lock.json   # pinned plugin commit lockfile
```

## Invariants (do not break these)

- **Symlinked source.** Within the dotfiles repo, edit files under `src/nvim/` —
  never the live `~/.config/nvim` target (it is the same inode; editing the
  target edits the repo, which is confusing). Always go through the repo file.
- **`lazy-lock.json` is committed.** After adding/updating a plugin, run
  `:Lazy sync` (or `nvim --headless "+Lazy! sync" +qa`) and commit the changed
  lockfile in the same change. Never hand-edit it.
- **Retire, do not delete (when you want history).** Move a dead plugin spec to
  `lua/plugins/_depreciated/` (note the existing spelling) — that folder is
  excluded from `{ import = 'plugins' }`.
- **Modern Neovim API only.** Prefer `vim.uv` (libuv), `vim.system{}` for async
  subprocess, `vim.ui.select`, `vim.notify(msg, vim.log.levels.*)`, and
  `require('snacks').picker{...}` (guard third-party requires with `pcall`).
  Don't reintroduce deprecated `vim.loop`/`vim.lsp.buf_get_clients`-style calls.
- **Secrets live outside the repo** at `~/Programming/JimmyTranDev/secrets`.
  Read them through `custom.utils.json`; never hardcode secret values or paths
  into committed Lua.
- **Catppuccin Mocha** is the theme. Keep `lua/plugins/catppuccin.lua` and any
  hard-coded palette fallbacks (e.g. in `which-key.lua`) consistent with it.
- **Never create documentation files** (README/markdown/docs) unless explicitly
  asked. Editing the existing `README.md` plugin/feature tables after a real
  change is allowed.

## Conventions (summary — see the matching skill for detail)

- **Keymaps** (`lua/core/keymaps.lua`): use the local `map(mode, lhs, rhs, opts)`
  and `maps(mode, { { lhs, rhs, desc }, ... })` helpers (both default to
  `silent = true, noremap = true`). Every `desc` starts with a nerd-font glyph.
  Register group/label names in `lua/plugins/which-key.lua`.
- **Modules** (`lua/custom/**`): `local M = {}` … `function M.x() end` …
  `return M`. Actions call util helpers via `require('custom.utils.<name>')`
  instead of re-implementing them.
- **Plugins** (`lua/plugins/<name>.lua`): return a lazy spec; lazy-load with
  `event` / `keys` / `cmd` / `ft`. No central registry to edit.
- **LSP** (`lua/lsp/servers.lua`): add a key to `M.servers`; Mason auto-installs
  it and `mason-lspconfig.lua` wires capabilities + flags automatically.

## Verify before done

- **Lint:** `selene lua` is clean (run from the repo root; from the dotfiles repo
  use `selene src/nvim/lua`). New global → add it to `custom.yml`, don't disable
  the lint.
- **Format:** `stylua --check .` passes (config in `.stylua.toml`).
- **Loads:** `nvim --headless +qa` catches load-time Lua errors surfaced by
  `init.lua`'s `pcall` notifications; `nvim --headless "+Lazy! sync" +qa`
  (network needed) after plugin changes. Use `:checkhealth` for runtime issues.
