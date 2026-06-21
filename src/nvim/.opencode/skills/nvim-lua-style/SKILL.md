---
name: nvim-lua-style
description: Keeps Lua in this Neovim config clean — formats with stylua (.stylua.toml) and lints with selene (selene.toml, std "vim+custom"), with globals declared in vim.yml/custom.yml (and .luacheckrc/.luarc.json for luacheck/lua_ls). Use ONLY when fixing formatting/lint here, running stylua/selene, or registering a new global so the linter stops flagging it. Triggers on "fix the nvim lua lint", "run stylua", "selene is complaining", "add a selene global", "format the lua".
---

# Lua style: stylua + selene

Two quality gates for every Lua change in this repo. Run both before finishing.

## Format — stylua (`.stylua.toml`)

```bash
stylua .            # format in place
stylua --check .    # CI-style check, no writes
```

Style rules (already in `.stylua.toml`, don't fight them):

- `column_width = 160`
- `indent_type = "Spaces"`, `indent_width = 2`
- `quote_style = "AutoPreferSingle"` (single quotes)
- `collapse_simple_statement = "Always"` (e.g. `if x then return end` on one line)
- `[sort_requires] enabled = false` — **never reorder `require`s**; order matters
  in Neovim configs.

## Lint — selene (`selene.toml`)

```bash
selene lua          # from the repo root
# from the dotfiles repo: selene src/nvim/lua
```

`selene.toml` sets `std = "vim+custom"`, which loads two std-lib definition files
at the repo root:

- `vim.yml` — the `vim` global (`vim: { any: true }`), base `lua51`, luajit.
- `custom.yml` — project globals; currently `Snacks: { any: true }`.

Enabled lint relaxations (in `selene.toml` `[lints]`): `bad_string_escape`,
`global_usage`, `mixed_table`, `multiple_statements`, `unscoped_variables` are
all `"allow"`.

### Add a new global (the right fix)

If selene flags an undefined global you intentionally introduced (e.g. a new
`_G.something` or a plugin-injected global), **add it to `custom.yml`** rather
than disabling the lint or sprinkling ignores:

```yaml
---
name: custom
globals:
  Snacks:
    any: true
  MyGlobal:
    any: true
```

Keep `vim.yml` for the editor API only; project/plugin globals go in
`custom.yml`. If you also rely on luacheck or lua_ls picking it up, mirror the
name into `.luacheckrc` (`globals = { ... }`) and `.luarc.json`
(`diagnostics.globals`) — those lists already include `vim`, `Snacks`,
`engage`, `create_buffer_local_mappings`.

## Verify

- `stylua --check .` is clean.
- `selene lua` reports `Results: 0 errors`.
- `nvim --headless +qa` still loads without `Failed to load` notifications.
