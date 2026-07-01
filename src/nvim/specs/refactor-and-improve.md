# Spec: Neovim Config Refactor & Improve

Status: **DRAFT — awaiting review** · Scope: `src/nvim/` (symlinked to `~/.config/nvim`)

> Execution plan (task cards, dependencies, estimates, checkpoints):
> [`specs/refactor-plan.md`](./refactor-plan.md)

## Objective

Reduce cross-cutting duplication and harden the custom layer of this Neovim
config **without regressing any user-facing behavior** (same keymaps, commands,
pickers, and output), then ship a small set of opt-in quality/UX improvements.

The architecture (`core / actions / utils`) is already sound. The problem is
**missing or bypassed shared abstractions**: the same floating panel, subprocess
call, directory scan, recency cache, and Snacks-picker guard are re-implemented
dozens of times across ~90 files (13.5k lines). This concentrates risk (e.g.
unescaped shell strings in `docker.lua`) and inflates four action files to
600–1641 lines.

### Who / why

Single maintainer (Jimmy). Goal: make the config easier to extend and safer to
change, and shrink the four giant action files so a single feature lives in one
readable place.

### What success looks like

- The 5 duplicated patterns each have **one** canonical helper, and all callers
  route through it.
- The four 600–1641-line action files drop substantially in size.
- `selene`, `stylua --check`, and a headless load all stay green.
- No keymap, command, or visible behavior changes (except deliberate, listed
  improvements).

## Tech Stack

- **Neovim** 0.10+ · **Lua** 5.1 (LuaJIT)
- **lazy.nvim** plugin manager (`stable` branch, `lazy-lock.json` pinned)
- **Snacks.nvim** (picker/UI), **Catppuccin Mocha** theme
- Lint **selene** (`std = vim+custom`), format **stylua**, types **lua_ls**
- External CLIs the custom layer shells out to: `gh`, `acli`, `td`, `jq`,
  `docker`, `diff-cover`, `git`, `zellij`

## Commands

Run from the Neovim runtime root (`src/nvim/` in the dotfiles repo):

```bash
# Lint (must be clean; add new globals to custom.yml, never disable the lint)
selene lua                       # from src/nvim/
selene src/nvim/lua              # from dotfiles repo root

# Format check / apply (config: .stylua.toml)
stylua --check .
stylua .

# Load check — surfaces init.lua pcall ERROR notifications
nvim --headless +qa

# Plugin sync (network) — only if plugin specs change; commit lazy-lock.json
nvim --headless "+Lazy! sync" +qa

# Runtime health
nvim  # then :checkhealth
```

## Project Structure

No structural change to the top-level layout. New code lands in **existing**
util files; split files land in **new subfolders** under `actions/`.

```
src/nvim/
├── init.lua
├── lua/core/         # options, lazy, plugins, commands, keymaps, statusline, constants
├── lua/plugins/      # one file per lazy.nvim spec (_depreciated/ NOT imported)
├── lua/custom/
│   ├── actions/      # feature modules (local M = {} ... return M), wired in keymaps.lua
│   │   ├── github/   # NEW: github.lua (1641) split here
│   │   ├── jira/     # NEW: jira.lua (759) split here
│   │   └── git/      # NEW: git.lua (661) split here
│   ├── utils/        # shared helpers — NEW canonical helpers land here
│   └── constants/
├── lua/lsp/servers.lua
└── specs/refactor-and-improve.md   # this document
```

## Code Style

Existing conventions are non-negotiable (see `.opencode/CLAUDE.md`):

- 160 columns, 2-space indent, single quotes, `collapse_simple_statement = Always`
  (one-line `function M.x() ... end` bodies are idiomatic here).
- Module pattern: `local M = {}` … `function M.x() end` … `return M`.
- Actions call util helpers via `require('custom.utils.<name>')` — never
  re-implement them.
- Modern API only: `vim.uv`, `vim.system{}` for async subprocess, `vim.ui.select`,
  `vim.notify(msg, vim.log.levels.*)`, `require('snacks').picker{}` guarded by
  `pcall`. No `vim.loop` / `vim.fn.jobstart` / deprecated calls.
- Keymap `desc` strings start with a nerd-font glyph; groups registered in
  `lua/plugins/which-key.lua`.

Reference style for a new helper:

```lua
local M = {}

--- Show read-only lines in a centered floating panel.
---@param opts { title: string, lines: ({ [1]: string, [2]?: string })[] }
---@return integer win
function M.show_panel(opts)
  -- ...
end

return M
```

## Testing Strategy

There is **no test suite today**. Verification is tooling + manual smoke tests.

**Tier 1 — automated (gate every task):**
- `selene lua` clean
- `stylua --check .` clean
- `nvim --headless +qa` produces no ERROR notification

**Tier 2 — manual smoke (per refactored surface):** trigger the affected keymap
in a real `nvim` session and confirm identical behavior. Each task lists its
smoke check.

**Tier 3 — optional new harness (Ask first, see Open Questions):** add
`mini.test` (or plain headless Lua asserts) for the *pure-logic* utils that this
refactor introduces — `files.scan` parsing, `usage_cache` ordering, `async`
result parsing. These are deterministic and worth locking down. This is the one
piece that adds a dev dependency, so it is gated.

## The Refactor Targets

Each target lists the canonical helper, where it lives, and the callers to
migrate. Line numbers are anchors at spec-writing time.

### A. `ui.show_panel(opts)` — read-only floating panel

One ~45-line scratch-buffer float is copy-pasted in **3** places:
`actions/git_dashboard.lua:161`, `actions/health.lua:156`,
`utils/env_check.lua:117`.

**Add to `lua/custom/utils/ui.lua`:**

```lua
--- Read-only centered float. `lines` is a list of { text, highlight? }.
---@param opts { title: string, lines: ({ [1]: string, [2]?: string })[] }
---@return integer win
function M.show_panel(opts)
  local content, highlights = {}, {}
  for i, line in ipairs(opts.lines) do
    content[i] = line[1]
    if line[2] then highlights[#highlights + 1] = { i - 1, line[2] } end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buftype = 'nofile'

  local width = 60
  for _, l in ipairs(content) do width = math.max(width, vim.fn.strdisplaywidth(l) + 4) end
  width = math.min(width, math.floor(vim.o.columns * 0.8))
  local height = math.min(#content, math.floor(vim.o.lines * 0.6))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor', width = width, height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal', border = 'rounded',
    title = ' ' .. opts.title .. ' ', title_pos = 'center',
  })
  for _, hl in ipairs(highlights) do vim.api.nvim_buf_add_highlight(buf, -1, hl[2], hl[1], 0, -1) end

  local function close() if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end end
  vim.keymap.set('n', 'q', close, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf, nowait = true })
  return win
end
```

**Migrate:** all three call sites build the `lines` table already (`{ text, hl }`
pairs) — they keep that and replace the buffer/window/keymap block with
`ui.show_panel{ title = ..., lines = lines }`. `health.lua` keeps the returned
`win` in its `health_win` local.

**Note:** `health.lua:172` measures width with `#line` (bytes); `env_check`/`git_dashboard`
use `strdisplaywidth`. The helper standardizes on `strdisplaywidth` (correct for
nerd-font glyphs) — a minor, desirable fix.

### B. Canonical async subprocess helper

Four subprocess styles coexist: `vim.fn.system`/`systemlist` (+`shell_error`),
`vim.system` (+`schedule_wrap`), `vim.fn.jobstart`, and `utils/async.lua` (which
itself exposes two APIs, `execute` and `run`). Several files hand-roll a local
`run_gh`/`run_git` (`status.lua:5`, `git_dashboard.lua:5`, `health.lua`,
`branch.lua`).

**Rewrite `lua/custom/utils/async.lua` on `vim.system`** (per the "modern API
only" invariant) and add convenience wrappers, keeping the existing
`execute`/`run` signatures so current callers (`todoist.lua`, `gh_notifications.lua`)
don't break:

```lua
--- Run argv async; on_done(result) is schedule-wrapped. result = vim.SystemCompleted.
---@param cmd string[]
---@param on_done fun(res: vim.SystemCompleted)
function M.run_cmd(cmd, on_done)
  vim.system(cmd, { text = true }, vim.schedule_wrap(on_done))
end

--- Run argv and decode stdout as JSON. Standard error notify on failure.
---@param cmd string[]
---@param on_ok fun(data: any)
---@param on_err? fun(err: string, code: integer)
function M.json(cmd, on_ok, on_err)
  M.run_cmd(cmd, function(res)
    if res.code ~= 0 then
      local err = (res.stderr or ''):gsub('%s+$', '')
      if on_err then return on_err(err, res.code) end
      return vim.notify(cmd[1] .. ' error: ' .. err, vim.log.levels.ERROR)
    end
    local ok, data = pcall(vim.json.decode, res.stdout)
    if not ok then return vim.notify('Failed to parse ' .. cmd[1] .. ' output', vim.log.levels.ERROR) end
    on_ok(data)
  end)
end
```

`execute`/`run` are reimplemented on top of `run_cmd` (preserving their
trim/`code == 1`-as-success semantics) instead of `jobstart`.

**Migrate:** delete the duplicated `run_gh`/`run_git` locals and route
`status.lua`, `git_dashboard.lua`, `health.lua`, `branch.lua`, `project.lua`,
`editor.lua`, `files.lua` through `async.run_cmd`/`async.json`. The bespoke
"no PR found" friendly messages in `status.lua:9` become an `on_err` callback.

**Risk:** highest-touch util. Migrate one caller at a time; smoke-test
`todoist.lua` and `gh_notifications.lua` first since they depend on the changed
internals.

### C. `files.scan` — directory scan helper

The `vim.uv.fs_scandir` org/repo walk is rewritten ~6×: `project.lua:25`,
`pnpm.lua:5,21`, `editor.lua:9`, `files.lua:192`, `notes.lua:53,68`,
`github.lua` (programming-dir scan).

**Add to `lua/custom/utils/files.lua`:**

```lua
local PROGRAMMING_DIR = vim.fn.expand('$HOME/Programming')

--- One-level scan. exclude may be a set { name = true } or predicate(name).
---@param dir string
---@param opts? { type?: 'directory'|'file', exclude?: table|fun(name:string):boolean, hidden?: boolean }
---@return { name: string, path: string, type: string }[]
function M.scan(dir, opts)
  opts = opts or {}
  local out, handle = {}, vim.uv.fs_scandir(dir)
  if not handle then return out end
  while true do
    local name, t = vim.uv.fs_scandir_next(handle)
    if not name then break end
    local excluded = type(opts.exclude) == 'function' and opts.exclude(name)
      or (type(opts.exclude) == 'table' and opts.exclude[name])
    local hidden = not opts.hidden and name:match('^%.')
    if (not opts.type or opts.type == t) and not excluded and not hidden then
      out[#out + 1] = { name = name, path = dir .. '/' .. name, type = t }
    end
  end
  return out
end

--- Two-level org/repo walk of ~/Programming → { org, name, path, text }, sorted.
---@param exclude? table  org dirs to skip (default { Worktrees, wcreated, wcheckout })
function M.scan_programming(exclude) ... end
```

**Migrate:** the 6 call sites; `project.lua`'s `EXCLUDED_DIRS` becomes the
default `exclude` set for `scan_programming`.

### D. `usage_cache` — one recency/frequency store

`utils/frequency_cache.lua` (count-based, namespaced, single JSON file) is the
intended abstraction but is bypassed by `links.lua:15-40` (timestamp MRU, own
JSON), `notes.lua:16-51` (ordered MRU, own JSON), and the project/section caches
in `utils/todoist.lua`.

links/notes need **recency** (MRU), not **frequency** (count). Generalize
`frequency_cache.lua` into `usage_cache.lua` storing `{ count, last_used }` per
key, exposing both orderings:

```lua
function M.record(namespace, key)        -- count + 1, last_used = os.time()
function M.sort_by_frequency(ns, items, key_fn)
function M.sort_by_recency(ns, items, key_fn)   -- NEW
function M.recent(namespace, n)                  -- NEW: top-n keys by last_used
```

**Migrate:** `links.lua` and `notes.lua` drop their private JSON files and
route through `usage_cache` (`sort_by_recency`/`recent`); `todoist.lua` caches
follow. Keep `frequency_cache` as a thin alias `require`-ing `usage_cache` for
one release, or update callers directly (preferred — small caller count).

**Decision needed:** migrate existing on-disk MRU JSON, or accept a one-time
reset of recents? (See Open Questions.)

### E. `ui.pick(opts)` — Snacks picker wrapper

The `pcall(require, 'snacks')` guard + `snacks.picker{ title, items, format,
confirm = close + act }` shape repeats 15+ times (`status.lua` ×3,
`project.lua` ×3, `branch.lua`, `text_search.lua`, `toggleterm.lua`,
`session.lua`, `files.lua`).

**Add to `lua/custom/utils/ui.lua`:**

```lua
--- Guarded Snacks picker. confirm(item) runs after the picker closes.
--- Extra Snacks opts pass through via opts.extra (win/actions/layout/etc).
---@param opts { title: string, items: table[], format: fun(item), confirm: fun(item), extra?: table }
function M.pick(opts)
  local ok, snacks = pcall(require, 'snacks')
  if not ok then return vim.notify('Snacks not available', vim.log.levels.WARN) end
  if #opts.items == 0 then return vim.notify('No items', vim.log.levels.WARN) end
  snacks.picker(vim.tbl_extend('force', {
    title = opts.title, items = opts.items, format = opts.format,
    confirm = function(picker, item)
      picker:close()
      if item then vim.schedule(function() opts.confirm(item) end) end
    end,
  }, opts.extra or {}))
end
```

**Migrate:** the simple single-action pickers first. Pickers with custom keys /
multiple actions (those using `safe_select`'s `snacks.actions`) pass them via
`opts.extra` — keep `safe_select` for the back/left-right navigation cases.

### F. Collapse duplicate function pairs (parameterize)

Behavior-preserving merges (keymaps call the merged fn with an argument):

- `links.lua`: `open_useful_link`/`open_private_useful_link` (`:71`/`:93`);
  `open_technical_link`/`open_technical_link_current_repo` (`:175`/`:207`);
  `open_current_github_repo`/`open_current_github_prs` (`:51`/`:60`)
- `files.lua`: `copy_opencode_link`/`copy_ai_file_reference` (byte-identical,
  `:105`/`:116`) — collapse to one, keep both keymaps pointing at it
- `git.lua`: `diff_vs_main`/`diff_vs_develop` → `diff_vs(ref)`
- `jira.lua`: `browse_my_tasks`/`browse_recently_updated_tasks`
- `todoist.lua`: recent-projects/recent-sections; `edit_recent_task`/`delete_recent_task`

Each keymap keeps its current `lhs`/`desc`; only the implementation merges.

### G. Split the oversized files

Highest risk (touches `keymaps.lua` wiring) — do **last**, one file per task.
Pattern: split by concern into a subfolder; update `require`s in
`core/keymaps.lua`. No behavior change.

- `actions/github.lua` (1641) → `actions/github/{repos,prs,notifications,orgs}.lua`
  (+ optional thin `actions/github/init.lua` re-export). Also delete the dead
  unused `title` in `show_notifications_picker`.
- `actions/jira.lua` (759) → `actions/jira/{create,browse,link}.lua`
- `actions/git.lua` (661) → `actions/git/{diff,worktree,branch-ops}.lua`
  (mind the existing separate `branch.lua`)
- `plugins/snacks.lua` (765) → remove large commented-out dead keymap blocks;
  move any picker logic that belongs in `custom/` out; leave a lean lazy spec.

### H. Safety / quality fixes (small behavior-affecting)

- **`docker.lua` shell injection.** `start_db`/`stop_db`/`cleanup_all` build
  shell strings from env-derived `password`/`port`/`image` and run
  `vim.fn.system(string)` (`:71-80`, `:99`, `:135`). Switch to **list-form**
  `vim.system({...})` so values are passed as argv, not shell-interpolated. The
  `&&`/`2>/dev/null` chains become sequential calls.
- **Unify JSON.** Standardize on `vim.json.decode`/`vim.json.encode` (or the
  `custom.utils.json` wrapper) everywhere; drop `vim.fn.json_decode`
  (`status.lua:16`, others) and the `vim.json` vs `vim.fn.json_decode` split.
- **Dead code.** Remove commented keymap blocks in `snacks.lua`, unused `title`
  in `github.lua`, and other noted dead locals.
- **Redundant requires.** Remove in-function `require` of `async` /
  `terminal_registry` where already required at module top (`todoist.lua`,
  `language.lua`).

### I. Optional UX improvements (user is open; confirm before building)

Candidates — none implemented without sign-off:

- Standardize all read-only panels (A) to also map `q`/`<Esc>` consistently and
  add a footer hint (`q close`).
- Unify picker confirm semantics via `ui.pick` (E) so every picker closes then
  acts (some currently differ subtly).
- `:checkhealth`-style entry that reuses `env_check.show_env_status` (A) +
  workspace health (currently two separate panels) into one tabbed view.

## Boundaries

**Always:**
- Run `selene lua`, `stylua --check .`, and `nvim --headless +qa` before
  considering any task done.
- Keep keymaps, `desc` strings, commands, and visible output identical unless a
  change is explicitly listed in H or approved from I.
- Edit files under `src/nvim/` (never the `~/.config/nvim` symlink target).
- Route new code through the canonical helpers introduced here.

**Ask first:**
- Adding any dependency (e.g. `mini.test` for Tier-3 tests).
- Migrating vs resetting the on-disk MRU caches (D).
- Any change in target I (UX).
- Creating new top-level directories beyond `specs/` and the `actions/{github,jira,git}/` splits.

**Never:**
- Hand-edit `lazy-lock.json`, or change plugin versions as a side effect.
- Hardcode secrets or secret paths (they live at
  `~/Programming/JimmyTranDev/secrets`, read via `custom.utils.json`).
- Delete a plugin spec outright — move to `lua/plugins/_depreciated/`.
- Disable a selene lint to make code pass (add the global to `custom.yml`).
- Change the Catppuccin Mocha theme or palette fallbacks.

## Implementation Plan

Dependency-ordered phases. Utils land before their callers; the risky file split
is last. Each phase is independently shippable and leaves the config green.

| Phase | Target | Risk | Depends on |
|-------|--------|------|-----------|
| 0 | Baseline: confirm selene/stylua/headless all green; record current behavior notes | none | — |
| 1 | A — `ui.show_panel` + migrate 3 panels | low | 0 |
| 2 | B — `async` on `vim.system` + `run_cmd`/`json`; migrate `run_gh`/`run_git` callers | **high** | 0 |
| 3 | C — `files.scan`/`scan_programming` + migrate 6 callers | low | 0 |
| 4 | D — `usage_cache` + migrate 3 caches | med | 0 |
| 5 | E — `ui.pick` + migrate simple pickers | med | 1 |
| 6 | F — collapse duplicate function pairs | low | 1–5 |
| 7 | H — docker hardening, JSON unify, dead code, requires | med | 2 |
| 8 | G — split github/jira/git/snacks (one file per task) | **high** | 1–7 |
| 9 | I — optional UX (only approved items) + Tier-3 tests (if approved) | med | 1–8 |

Phases 1, 3, 4 are parallelizable (independent utils). Phase 2 should land and
soak first because the most files depend on it.

## Task Breakdown

Each task: ≤5 files, with acceptance + verify. `[ui]`/`[async]` etc. name the
helper. Verify always includes Tier-1 (`selene` + `stylua --check` + headless).

```markdown
- [ ] P1.1 Add ui.show_panel to utils/ui.lua
  - Acceptance: helper exists, returns win, matches spec signature
  - Verify: Tier-1; require in headless and open a panel with sample lines
  - Files: lua/custom/utils/ui.lua

- [ ] P1.2 Migrate env_check.show_env_status to ui.show_panel
  - Acceptance: env health panel visually identical; q/<Esc> close
  - Verify: Tier-1; trigger env-status keymap, compare before/after
  - Files: lua/custom/utils/env_check.lua

- [ ] P1.3 Migrate health.workspace_health to ui.show_panel (keep health_win)
  - Acceptance: health panel identical incl. async git/knip rows
  - Verify: Tier-1; trigger health keymap
  - Files: lua/custom/actions/health.lua

- [ ] P1.4 Migrate git_dashboard.show_dashboard to ui.show_panel
  - Acceptance: dashboard identical
  - Verify: Tier-1; trigger dashboard keymap
  - Files: lua/custom/actions/git_dashboard.lua

- [ ] P2.1 Rewrite async.lua on vim.system; add run_cmd + json; keep execute/run
  - Acceptance: execute/run keep trim + code==1 semantics; no jobstart
  - Verify: Tier-1; smoke todoist picker + gh notifications (depend on execute/run)
  - Files: lua/custom/utils/async.lua

- [ ] P2.2 Migrate status.lua run_gh → async.json (keep friendly no-PR message)
  - Acceptance: CI checks + PR pickers behave identically incl. no-PR notify
  - Verify: Tier-1; trigger CI-checks keymap on a branch with/without PR
  - Files: lua/custom/actions/status.lua

- [ ] P2.3 Migrate git_dashboard/health/branch/project/editor/files subprocess calls
  - Acceptance: each affected command behaves identically (split across sub-tasks if >5 files)
  - Verify: Tier-1; trigger each affected keymap
  - Files: those action modules (batched ≤5 per commit)

- [ ] P3.1 Add files.scan + files.scan_programming
  - Acceptance: helpers match spec; default exclude = Worktrees/wcreated/wcheckout
  - Verify: Tier-1; headless assert scan of a temp dir
  - Files: lua/custom/utils/files.lua

- [ ] P3.2 Migrate project/pnpm/editor/files/notes/github scans to helpers
  - Acceptance: same project/repo/file lists in each picker
  - Verify: Tier-1; trigger switch-project, pnpm, notes pickers
  - Files: those action modules (batched ≤5 per commit)

- [ ] P4.1 Generalize frequency_cache → usage_cache ({count,last_used}); add recency APIs
  - Acceptance: sort_by_frequency unchanged; sort_by_recency/recent added
  - Verify: Tier-1; headless assert ordering
  - Files: lua/custom/utils/usage_cache.lua (+ alias or caller updates)

- [ ] P4.2 Migrate links/notes/todoist caches to usage_cache (per D decision)
  - Acceptance: recents behave the same (or documented one-time reset)
  - Verify: Tier-1; open links/notes pickers, confirm MRU order
  - Files: lua/custom/actions/links.lua, notes.lua, lua/custom/utils/todoist.lua

- [ ] P5.1 Add ui.pick; migrate single-action pickers
  - Acceptance: pickers open/confirm/close identically
  - Verify: Tier-1; trigger each migrated picker
  - Files: lua/custom/utils/ui.lua + simple-picker actions (batched ≤5)

- [ ] P6.x Collapse each duplicate function pair (one commit per module)
  - Acceptance: both original keymaps work; one implementation remains
  - Verify: Tier-1; trigger both keymaps of each pair
  - Files: links.lua / files.lua / git.lua / jira.lua / todoist.lua

- [ ] P7.1 Harden docker.lua to list-form vim.system
  - Acceptance: start/stop/status/cleanup work; no shell-string interpolation
  - Verify: Tier-1; manual docker start_db/stop_db round-trip
  - Files: lua/custom/actions/docker.lua

- [ ] P7.2 Unify JSON decode + remove dead code + redundant requires
  - Acceptance: no vim.fn.json_decode; no commented dead keymaps; no double requires
  - Verify: Tier-1; rg confirms zero vim.fn.json_decode in lua/custom
  - Files: status.lua, snacks.lua, github.lua, todoist.lua, language.lua, ...

- [ ] P8.x Split github/jira/git (one file per task) + slim snacks.lua
  - Acceptance: every moved function reachable; keymaps.lua requires updated; no behavior change
  - Verify: Tier-1; trigger a sample keymap from each moved concern
  - Files: actions/<area>/*.lua + lua/core/keymaps.lua

- [ ] P9.x (Optional, approval-gated) UX items from I; Tier-3 test harness
  - Acceptance: per approved item
  - Verify: Tier-1 + new tests green
  - Files: TBD on approval
```

## Success Criteria

- [ ] 5 canonical helpers exist (`ui.show_panel`, `async.run_cmd`/`async.json`,
      `files.scan`/`scan_programming`, `usage_cache`, `ui.pick`) and the listed
      callers route through them (zero remaining copies of each pattern).
- [ ] `rg` shows **0** ad-hoc `run_gh`/`run_git` locals, **0**
      `vim.fn.json_decode` in `lua/custom`, **0** `vim.fn.jobstart`.
- [ ] `docker.lua` uses list-form `vim.system` (no shell-string concatenation).
- [ ] `github.lua`, `jira.lua`, `git.lua` each split; no single action file > ~400
      lines; `snacks.lua` free of commented dead keymaps.
- [ ] `selene lua`, `stylua --check .`, and `nvim --headless +qa` all clean.
- [ ] Manual smoke checklist passes: every refactored keymap behaves as before.
- [ ] No change to `lazy-lock.json` (no plugin churn) unless a test dep is
      approved.

## Open Questions

1. **MRU cache migration (D):** migrate existing on-disk `links`/`notes` MRU
   JSON into `usage_cache`, or accept a one-time recents reset? (Reset is
   simpler; recents rebuild after a few uses.)
2. **Tier-3 tests (Testing Strategy):** add `mini.test` as a dev dependency for
   the pure-logic utils, or stick to headless smoke checks only?
3. **github.lua split shape (G):** subfolder `actions/github/*` with a thin
   `init.lua` re-export (keymaps unchanged) vs. flat `actions/github_*.lua`
   (keymaps re-pointed)? Re-export keeps `keymaps.lua` churn minimal.
4. **UX scope (I):** which, if any, of the optional improvements do you want in
   this effort vs. deferred?
5. **Spec location:** is `src/nvim/specs/refactor-and-improve.md` the right home,
   or do you prefer `updates/` or repo root?
