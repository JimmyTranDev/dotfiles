---
name: nvim-plugins
description: Adds, configures, or removes plugins in this Neovim config. Each plugin is one file in lua/plugins/ returning a lazy.nvim spec, auto-imported by core.plugins. Use ONLY when changing this repo's plugin set — adding a plugin, tuning its opts/keys/events, lazy-loading it, retiring it, or updating lazy-lock.json. Triggers on "add an nvim plugin", "configure <plugin>", "lazy-load this plugin", "remove a plugin", "update lazy-lock".
---

# Plugins (lua/plugins/ + lazy.nvim)

`core.plugins` runs `lazy.setup{ spec = { { import = 'plugins' } }, ... }`, so
**every `.lua` file directly under `lua/plugins/` is auto-imported** as a spec.
There is no central list to edit — adding a file is enough.

Global defaults (from `lua/core/plugins.lua`):
`defaults.lazy = true` (everything lazy-loaded), `version = false` (track latest
commits, pinned by `lazy-lock.json`), install colorscheme `catppuccin`, and a
list of disabled built-in plugins (`netrwPlugin`, `syntax`, `tarPlugin`, ...).

## Add a plugin

Create `lua/plugins/<name>.lua` returning a spec (a table, or a list of tables):

```lua
return {
  'owner/plugin',
  event = 'VeryLazy',          -- lazy-load trigger (see below)
  dependencies = { 'owner/dep' },
  opts = {                      -- passed to require('plugin').setup(opts)
    -- ...
  },
}
```

Use `config = function() ... end` instead of `opts` when setup needs logic
(custom highlights, palette lookups, conditional wiring) — see
`lua/plugins/which-key.lua` and `lua/plugins/conform.lua` for the established
pattern.

### Lazy-load it (don't load at startup)

Pick the narrowest trigger that still works:

| Trigger | Use when |
|---------|----------|
| `event = 'VeryLazy'` | general UI/feature plugin, fine to load just after startup |
| `event = 'BufReadPre'` / `'BufWritePre'` | needs a buffer (LSP-ish, formatters) |
| `keys = { ... }` | only needed when a key is pressed |
| `cmd = 'SomeCmd'` | only needed when a command runs |
| `ft = { 'go', 'rust' }` | filetype-specific |

Only set `lazy = false` for things that genuinely must load eagerly (e.g.
`mason-lspconfig.lua` uses `lazy = false` so servers register on startup).

## Configure / tune an existing plugin

Edit its file under `lua/plugins/`. Keep the spec shape; change `opts`/`keys`/
`event`/`config`. Preserve Catppuccin theming and any palette fallbacks.

## Remove or retire a plugin

- To **retire with history**, move the spec file into
  `lua/plugins/_depreciated/` (existing spelling) — that subfolder is **not**
  imported by `{ import = 'plugins' }`, so the plugin stops loading but the code
  is kept.
- To **delete outright**, remove the file.
- Either way, run a sync so the lockfile drops the plugin.

## Update the lockfile (required)

After any add/remove/update, sync and commit `lazy-lock.json` in the same change:

```bash
nvim --headless "+Lazy! sync" +qa     # or :Lazy sync inside Neovim (network needed)
```

Never hand-edit `lazy-lock.json`.

## Verify

- `nvim --headless "+Lazy! sync" +qa` completes (installs/removes as expected).
- `nvim --headless +qa` loads clean (no `Failed to load core.plugins`).
- `:Lazy` shows the plugin with the intended lazy-load reason; `:checkhealth`
  for the plugin if it ships a health check.
- `selene lua` and `stylua --check .` pass for the new spec file.
