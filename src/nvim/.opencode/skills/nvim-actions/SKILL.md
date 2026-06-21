---
name: nvim-actions
description: Writes or edits the custom Lua feature modules in this Neovim config under lua/custom/actions/ (keymap-invoked features) and lua/custom/utils/ (shared helpers). Use ONLY when adding or changing a custom action/util module here — a new Todoist/Jira/GitHub/git/journal feature, an HTTP/JSON/input helper, or refactoring shared logic. Triggers on "new nvim action", "add a custom util", "edit lua/custom", "write a Neovim feature module", "reuse a util helper".
---

# Custom action & util modules (lua/custom/)

Two namespaces, same module pattern:

- `lua/custom/actions/<name>.lua` — user-facing features bound to keymaps
  (e.g. `todoist`, `jira`, `github`, `git`, `journal`, `notes`, `language`).
- `lua/custom/utils/<name>.lua` — shared, reusable helpers
  (e.g. `json`, `github`, `git`, `input`, `ui`, `async`, `url`, `validation`).

Actions orchestrate; utils do the low-level work. Keep API/IO helpers in `utils/`
so multiple actions can share them.

## Module pattern

```lua
local github_utils = require('custom.utils.github')   -- reuse utils, don't re-implement
local json_utils = require('custom.utils.json')

local M = {}

local function private_helper(x) ... end   -- file-local, not exported

function M.do_thing()
  -- ...
end

return M
```

Keymaps in `lua/core/keymaps.lua` call the exported `M.*` functions.

## Conventions to follow

- **Reuse existing utils.** Before writing new logic, check `lua/custom/utils/`
  for an existing helper:
  - `custom.utils.json` — `parse_json_from_file(path)` / `write_json_to_file(path, data)`
    (handles missing secrets gracefully, decodes via `vim.fn.json_decode` under `pcall`).
  - `custom.utils.github` / `custom.utils.git` — repo info, owners, PR/issue calls.
  - `custom.utils.input` / `custom.utils.ui` — prompts and UI helpers.
  - `custom.utils.async` — non-blocking command execution.
- **Modern Neovim API:**
  - Filesystem / stat: `vim.uv.fs_stat(...)` (libuv), not `vim.loop`.
  - Subprocess: `vim.system({ 'gh', 'pr', 'list' }, { text = true }, vim.schedule_wrap(cb))`
    for async; `vim.fn.system(...)` + `vim.v.shell_error` for quick synchronous
    calls (both patterns exist here — prefer async for anything slow).
  - Selection: `vim.ui.select(items, { prompt = '...' }, function(choice) ... end)`,
    or `require('snacks').picker{ ... }` for rich pickers (wrap the require in
    `pcall`).
  - User messages: `vim.notify(msg, vim.log.levels.INFO|WARN|ERROR)` — never
    `print`.
- **Secrets** come from `~/Programming/JimmyTranDev/secrets` via
  `custom.utils.json`; never hardcode secret values. The json util already
  prompts to run `storage-init` when the secrets dir/file is missing.
- **Guard third-party requires** with `pcall(require, '...')` and degrade
  gracefully (the config must still load if a plugin is absent).

## Wire it to a key

A new action is only reachable once bound. Add a `require` + a `maps(...)` entry
in `lua/core/keymaps.lua` (and a which-key group if it is a new prefix). See the
`nvim-keymaps` skill.

## Verify

- `selene lua` is clean. If you introduce a new global, add it to `custom.yml`
  (see `nvim-lua-style`) — do not disable the lint.
- `stylua --check .` passes.
- `nvim --headless +qa` shows no `Failed to load` notification, then exercise the
  feature interactively.
