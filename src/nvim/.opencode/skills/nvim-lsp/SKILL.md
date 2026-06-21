---
name: nvim-lsp
description: Adds or configures language servers and formatters in this Neovim config. LSP servers are declared in lua/lsp/servers.lua (M.servers), auto-installed by Mason and wired by lua/plugins/mason-lspconfig.lua; formatters live in lua/plugins/conform.lua. Use ONLY when changing this repo's LSP/formatting setup — adding a server, tuning server settings, ensuring a Mason install, or mapping a formatter to a filetype. Triggers on "add an LSP server", "configure lua_ls/ts_ls/gopls", "Mason install", "add a formatter", "format on save".
---

# LSP & formatting

## Adding / configuring a language server

The **source of truth is `lua/lsp/servers.lua`** — a single `M.servers` table
keyed by lspconfig server name. `lua/plugins/mason-lspconfig.lua` reads it and
does the rest automatically:

- `ensure_installed = vim.tbl_keys(servers)` + `automatic_installation = true`
  → Mason installs every server you list.
- merges blink.cmp capabilities (`require('blink.cmp').get_lsp_capabilities(...)`)
  and shared `default_flags` (debounce, incremental sync, exit timeout).
- calls `vim.lsp.config(server, config)` then `vim.lsp.enable(server)` per server.

So **adding a server = adding one key** to `M.servers`:

```lua
M.servers = {
  -- defaults are fine: empty table
  bashls = {},

  -- with settings / filetypes / root markers / init_options:
  lua_ls = {
    filetypes = { 'lua' },
    root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
    settings = {
      Lua = {
        diagnostics = { globals = { 'vim' } },
        workspace = { checkThirdParty = false, library = vim.api.nvim_get_runtime_file('', true) },
      },
    },
  },
}
```

Use the **lspconfig server name** as the key (`ts_ls`, `gopls`, `pyright`,
`rust_analyzer`, `cssls`, `jsonls`, `eslint`, `marksman`, `harper_ls`, ...). Do
not edit `mason-lspconfig.lua` for a normal add — it is generic.

## Adding / mapping a formatter (conform.nvim)

Formatting is handled by `lua/plugins/conform.nvim` config in
`lua/plugins/conform.lua`:

- `format_after_save` runs async with `lsp_format = 'fallback'`.
- `formatters_by_ft` maps filetype → ordered formatter list, e.g.
  `lua = { 'stylua' }`, `typescript = { 'oxfmt', 'eslint' }`,
  `python = { 'black', 'isort' }`, `bash = { 'shfmt' }`.

To add a formatter:
1. Add (or extend) the filetype entry in `formatters_by_ft`.
2. If the binary needs custom invocation, define it under `formatters = { ... }`
   (see the local `oxfmt` definition using `--stdin-filepath $FILENAME`).
3. Ensure the binary is installable via Mason or present on PATH.

Lua is formatted by **stylua** here (config `.stylua.toml`) — keep that mapping;
see the `nvim-lua-style` skill for the style rules.

## Verify

- `nvim --headless +qa` loads clean.
- Open a file of the target filetype: `:LspInfo` shows the server attached;
  `:Mason` shows it installed; `:checkhealth lsp` / `:checkhealth mason`.
- For formatters: `:ConformInfo`, then save the file and confirm it formats.
- `selene lua` and `stylua --check .` pass for any edited Lua.
