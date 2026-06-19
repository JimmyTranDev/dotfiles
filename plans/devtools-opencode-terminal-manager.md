# Devtools: OpenCode Terminal Manager (status list + float toggle)

## TL;DR
- **What**: A dedicated nvim feature to manage multiple opencode terminals — spawn each as a toggleterm float (via `terminal_registry`) and a Snacks picker that **lists every open opencode terminal with a live status (processing / done / needs-input)**. Selecting an item floats that opencode terminal, handled like the existing opencode floating terminal.
- **Scope**: New `custom/utils/opencode_terminals.lua` (an opencode layer over the existing `terminal_registry`), new `custom/actions/opencode.lua` (new-terminal + status-picker actions), keymaps in `core/keymaps.lua`, and a small extension to `terminal_registry.lua`. Does **not** touch the CI/PR pickers in `status.lua`.
- **Tasks**: 6 tasks — mostly small/medium. The only large/risky piece is **status detection** (processing vs done vs needs-input per terminal).
- **Most critical / risky**: the status classifier (Task 2). **Decided: terminal-buffer scraping** of the opencode TUI — self-contained, yields all three states, isolated behind one function for a later upgrade. Risk is now fragility to TUI changes (mitigated by defaulting to `unknown`).
- **Estimated effort**: ~half a day; ~2 hours of that is the buffer-scraping status classifier.

## Overview
Today there is a single opencode terminal toggled with `<C-.>` (`src/nvim/lua/plugins/opencode.lua:20`, via `snacks.terminal`). This spec adds a manager for **many** opencode terminals: each runs in a toggleterm float registered through the existing `custom/utils/terminal_registry.lua`, and a Snacks picker lists them all with a per-terminal status (processing / done / needs user input). Confirming a picker item floats that terminal. The design mirrors the existing toggleterm terminal picker (`custom/actions/toggleterm.lua:5` `open_terminal_picker`) but is opencode-specific and adds live status.

## Architecture
How this fits the existing nvim config:

- **`custom/utils/terminal_registry.lua`** (existing) — toggleterm-backed registry keyed by display name; `create`/`get_or_create`/`toggle`/`kill`/`kill_all`/`list`/`get`. `TerminalOpts` already supports `direction = "float"` (`terminal_registry.lua:7`). `list()` already returns `{ id, name, cmd, is_open, is_alive }` and prunes dead terminals (`terminal_registry.lua:167`). This is the foundation the user chose ("New dedicated terminal_registry term").
- **`custom/utils/opencode_terminals.lua`** (NEW) — a thin opencode-specific layer on top of `terminal_registry`:
  - `create(opts)` → spawns an opencode terminal (`cmd = 'opencode'`, `direction = 'float'`, name prefixed `opencode-`).
  - `list()` → returns only opencode terminals (filter registry by name prefix / tag) annotated with a computed `status`.
  - `float(name)` / `toggle(name)` → opens the chosen terminal as a float.
  - `detect_status(term)` → `'processing' | 'done' | 'needs_input' | 'unknown'`. **Decided: terminal-buffer scraping** — read the float's buffer lines and match opencode TUI markers; kept as a single swappable function.
- **`custom/actions/opencode.lua`** (NEW) — user-facing actions: `new_opencode_terminal()` and `open_opencode_picker()`. The picker mirrors `custom/actions/toggleterm.lua:5` (Snacks picker, kill actions on `<C-x>`/`<C-a>`) but renders a status icon per item and confirms into `opencode_terminals.float`.
- **`core/keymaps.lua`** — new keymaps to open the picker and spawn a terminal. **Decided: `<leader>to`** (picker) / **`<leader>tO`** (new terminal), under the existing `<leader>t` terminal group near `<leader>tf`/`<leader>tt`.
- **`plugins/toggleterm.lua`** (existing) — already has opencode-aware `<Esc>` handling that keys off `bufname:find('opencode')` (`toggleterm.lua:21`). Because the new terminals run `opencode` with an `opencode-*` display name, their buffer names contain `opencode`, so the existing Esc passthrough applies automatically. **Reused, not modified.**
- **`plugins/opencode.lua`** (existing) — keeps `<C-a>` ask and `<C-.>` toggle (the opencode.nvim server terminal). **Decided: keep `<C-.>` separate** — it stays the dedicated opencode.nvim server toggle and is not folded into the new multi-terminal system. This file needs no changes.

## Data flow
1. **Spawn**: keymap → `actions.opencode.new_opencode_terminal()` → `opencode_terminals.create({ direction = 'float' })` → `terminal_registry.create({ cmd = 'opencode', direction = 'float', name = 'opencode-N' })` → `term:toggle()` floats it open.
2. **List**: picker keymap → `actions.opencode.open_opencode_picker()` → `opencode_terminals.list()` → for each opencode terminal in the registry, compute `status = detect_status(term)` → build Snacks items `{ text = <icon> .. name, status, terminal_name }`.
3. **Render**: Snacks picker shows one row per terminal with a status icon (processing/done/needs-input) using the highlight conventions already in `status.lua` (`DiagnosticOk`/`DiagnosticWarn`/`DiagnosticError`/`Comment`).
4. **Select**: `confirm` → `picker:close()` → `opencode_terminals.float(item.terminal_name)` → `terminal_registry.toggle(name)` floats that terminal.
5. **Status source**: `detect_status(term)` reads the terminal **buffer contents** (`nvim_buf_get_lines`) and matches opencode TUI markers (decided mechanism).

## Tasks
| # | File | Change | Complexity | Deps | Parallel? |
|---|------|--------|------------|------|-----------|
| 1 | `src/nvim/lua/custom/utils/terminal_registry.lua` | Extend to support the opencode layer: (a) confirm/standardize a float window config for `direction='float'`; (b) add an optional `tag` field on `create`/`get_or_create` and surface it in `list()` (or document the `opencode-` name-prefix convention as the filter key); (c) expose a buffer-lines accessor (`nvim_buf_get_lines` wrapper) per terminal so the status classifier can scrape it. | Small–Medium | None | Yes |
| 2 | `src/nvim/lua/custom/utils/opencode_terminals.lua` (new) | Opencode layer over the registry: `create(opts)` (`cmd = 'opencode'`, `direction = 'float'`, auto-named `opencode-N`), `list()`, `float(name)`/`toggle(name)`, `kill(name)`, and the core `detect_status(term)` **buffer-scraping** classifier returning `processing`/`done`/`needs_input`/`unknown`. Isolate `detect_status` behind a single function so the mechanism is swappable. | Medium–Large | 1 | Sequential after 1 |
| 3 | `src/nvim/lua/custom/actions/opencode.lua` (new) | `new_opencode_terminal()` and `open_opencode_picker()` — Snacks picker mirroring `custom/actions/toggleterm.lua` (kill on `<C-x>`, kill-all on `<C-a>`) with a status icon per row; confirm floats the selected terminal. Empty-state notify when no opencode terminals are running. | Medium | 2 | Sequential after 2 |
| 4 | `src/nvim/lua/core/keymaps.lua` | Add keymaps: `<leader>to` (open opencode picker) + `<leader>tO` (new opencode terminal), near the existing `<leader>tf`/`<leader>tt`. Add the `require('custom.actions.opencode')` local at the top with the other action requires. | Small | 3 | Sequential after 3 |
| 5 | `src/nvim/lua/plugins/opencode.lua` | **No change** — decided to keep `<C-.>` as the separate opencode.nvim server toggle, not folded into the new system. (Row kept for traceability.) | — | — | — |
| 6 | `src/nvim/README.md` (opencode section) | Optional: document the new opencode terminal picker + keymaps. | Small | 4 | Yes |

## API contracts
New module `custom/utils/opencode_terminals.lua`:

```lua
---@class OpencodeTerminalInfo
---@field name string            -- registry display name (e.g. "opencode-2")
---@field is_open boolean        -- window currently visible
---@field is_alive boolean       -- process still running
---@field status "processing"|"done"|"needs_input"|"unknown"

---@param opts? { dir?: string, cmd?: string }  -- defaults: cmd='opencode', direction='float'
---@return table term            -- the toggleterm Terminal
function M.create(opts) end

---@return OpencodeTerminalInfo[]
function M.list() end

---@param name string
function M.float(name) end        -- toggles the named opencode terminal as a float

---@param name string
function M.kill(name) end

---@param term table
---@return "processing"|"done"|"needs_input"|"unknown"
function M.detect_status(term) end
```

Status → icon/highlight mapping (reuse the `status.lua` palette):
| status | icon (suggested) | highlight |
|--------|------------------|-----------|
| processing | `` (or spinner frame) | `DiagnosticWarn` |
| done | `` | `DiagnosticOk` |
| needs_input | `` | `DiagnosticError` |
| unknown | `?` | `Comment` |

`custom/actions/opencode.lua`:
```lua
function M.new_opencode_terminal() end   -- spawn + float a fresh opencode terminal
function M.open_opencode_picker() end    -- Snacks picker over M.list(); confirm → float
```

## State changes
- New Lua modules: `custom/utils/opencode_terminals.lua`, `custom/actions/opencode.lua`.
- In-memory only — terminals live in the existing `terminal_registry` `_terminals` table; no persisted/disk state, no new env vars.
- Possible new constant set for status icons (either inline or in `custom/constants/`).
- New keymaps registered in `core/keymaps.lua`.

## Edge cases
- **No opencode terminals running** → picker shows a notify ("No opencode terminals", `vim.log.levels.INFO`), mirroring `toggleterm.lua:7`.
- **Process exited / terminal dead** → `terminal_registry.list()` already prunes dead terminals; a recently-finished terminal should classify as `done` (or be pruned). Decide whether to keep exited terminals visible as `done`.
- **Status false positives** → buffer scraping can misread a transient TUI frame; `detect_status` must fall back to `unknown` rather than guess wrong.
- **Esc passthrough** → confirm the existing `bufname:find('opencode')` Esc handling (`toggleterm.lua:21`) triggers for these floats (display name contains `opencode`).
- **Name collisions** → handled by `terminal_registry._unique_name` (`terminal_registry.lua:53`).
- **Shared server terminal** → killing the new terminals must not kill the opencode.nvim server terminal started by `<C-.>` / `vim.g.opencode_opts.server.start` (`plugins/opencode.lua:28`).
- **Many instances** → each terminal runs plain `opencode` (decided), so no extra `--port` servers/port conflicts; still watch memory when spawning many TUIs.
- **Float window focus** → `terminal_registry` was primarily used with `horizontal`; verify float windows toggle/focus cleanly and the picker can reopen after closing a float.

## Testing approach
- **Pure classifier**: if `detect_status` is implemented as a pure function over sample buffer text (recommended), add a small spec under the nvim test setup (check whether one exists; if not, keep manual). Feed captured opencode TUI frames representing each state and assert the classification.
- **Manual checklist** (primary):
  1. Spawn 2–3 opencode terminals; confirm each opens as a float and the buffer name contains `opencode`.
  2. Open the picker; confirm all are listed with a status icon.
  3. Start a long task in one terminal → it shows `processing`; let it finish → `done`; trigger a permission/confirm prompt → `needs_input`.
  4. Select an item → that terminal floats; Esc returns to normal correctly.
  5. Kill one via `<C-x>` and all via `<C-a>`; confirm registry state matches.
  6. Confirm `<C-.>` opencode.nvim server terminal is unaffected.

## Open questions

### Requirements
- **Definition of "needs user input"**: which states count — a permission/tool-approval prompt, an idle prompt awaiting the first message, an error awaiting acknowledgement, or all of these? *(Still open — refine while building the buffer matcher; treat permission/confirm prompts as the primary `needs_input` signal.)*
- **"Done" lifecycle**: should a finished terminal stay listed as `done` until the user opens it, or auto-prune after completion? *(Still open.)*
- **Refresh model**: **Decision — compute status once when the picker opens** (no live timer/autocmd). Simpler and lighter; re-open the picker to refresh.

### Architecture
- **Status-detection mechanism (CENTRAL — gates Task 2)**: **Decision — (B) terminal-buffer scraping.** `detect_status` reads `nvim_buf_get_lines(term.bufnr, …)` and matches opencode TUI markers (spinner = processing, idle input box = done, confirm/permission prompt = needs_input), defaulting to `unknown` on no match. Kept behind a single function so it can later be upgraded to (A) the opencode server API if needed. Rejected: (A) server API (extra plumbing now), (C) activity heuristic (cannot detect `needs_input`), (D) no auto-status (does not meet the requirement).
- **Server model**: **Decision — each terminal runs plain `opencode`** (TUI, no extra `--port` server per terminal). One TUI per terminal, matching the terminal-centric design.
- **`<C-.>` integration**: **Decision — keep `<C-.>` separate.** It remains the dedicated opencode.nvim server toggle in `plugins/opencode.lua` and is not folded into the new multi-terminal system.

### Scope
- **How many / how named**: **Decision — arbitrary user-spawned terminals**, auto-named `opencode-1`, `opencode-2`, … (not one-per-worktree).
- **Confirmed out of scope**: the CI/PR pickers in `custom/actions/status.lua` (`show_ci_checks`/`show_pr_status`/`show_pipeline_overview`) are **not** modified — this is a separate opencode-terminal feature. (User reframed the request in clarification.)

### Conventions
- **Keymap group**: **Decision — `<leader>to`** (open picker) / **`<leader>tO`** (new terminal), under the existing `<leader>t` terminal group near `<leader>tf`/`<leader>tt`.
- **Module placement**: `utils/opencode_terminals.lua` + `actions/opencode.lua` follows the existing utils/actions split (matches `terminal_registry.lua` + `actions/toggleterm.lua`). Confirm naming (`opencode_terminals` vs `opencode_registry`). *(Default: `opencode_terminals`.)*

### Risks
- **Fragility**: buffer-scraping status (option B) can break when the opencode TUI layout changes — keep the matcher small and default to `unknown`.
- **Resource use**: spawning many `opencode` instances (especially with `--port`) consumes memory and may cause port conflicts.
- **Server interference**: the new terminals must not disturb the opencode.nvim server terminal that `<C-a>`/`<C-.>` depend on.
