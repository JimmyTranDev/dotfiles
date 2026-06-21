# Implementation Plan: Neovim Config Refactor & Improve

Status: **DRAFT — awaiting approval** · Companion to `specs/refactor-and-improve.md`

## Overview

Introduce 5 canonical helpers, route all duplicated callers through them,
collapse duplicate function pairs, harden `docker.lua`, unify JSON, and split the
4 oversized action files — all behavior-preserving. Work is sliced **per
abstraction** (add helper + migrate its callers = one shippable, working slice),
ordered so foundations land first and the riskiest change (file splitting) lands
last.

## Architecture Decisions (defaults for the spec's Open Questions)

These are the assumptions this plan runs on. Flagged so you can override at the
first checkpoint; each is low-risk/reversible.

| # | Question | Decision (default) | Why |
|---|----------|--------------------|-----|
| Q1 | MRU cache migration | **Reset** recents on cutover (no JSON migration) | Single user; recents rebuild in a few uses; lowest risk. Migration is a 30-min add-on if wanted. |
| Q2 | Test harness | **Smoke checks only** (no new dep); Tier-3 tests deferred to optional Phase 9 | "Add dependency" is Ask-First; keeps `lazy-lock.json` untouched. |
| Q3 | `github.lua`/`jira.lua`/`git.lua` split shape | **Subfolder + `init.lua` re-export shim** | `keymaps.lua` `require` paths stay identical → minimal churn, lowest regression risk. |
| Q4 | UX improvements (target I) | **Defer all** to a follow-up | Keeps this effort strictly behavior-preserving + safety only. |
| Q5 | Spec/plan location | **`src/nvim/specs/`** | Parallels `updates/`; self-documenting. |

## Global Verification (applies to every task — "Tier-1")

Every task is **done** only when all pass, run from `src/nvim/`:

```bash
selene lua            # clean (new global → add to custom.yml, never disable)
stylua --check .      # clean
nvim --headless +qa   # no ERROR notification from init.lua pcall
```

Plus the task's own **smoke** check (trigger the real keymap) where listed.

## Dependency Graph

```
P0 baseline
   │
   ├─ P1  ui.show_panel ───────────────┐
   ├─ P2  async (vim.system) ──┐       │
   ├─ P3  files.scan           │       │
   ├─ P4  usage_cache          │       │
   │                           │       │
   ▼                           ▼       ▼
P5 ui.pick (needs P1 float style + P2 for status pickers)
   │
   ▼
P6 collapse duplicate pairs (cleaner before splitting)
   │
   ▼
P7 safety/quality (docker, json, dead code)   ← P7 json depends on P2 patterns
   │
   ▼
P8 split github/jira/git/snacks  (depends on P6+P7 to split less, cleaner code)
   │
   ▼
P9 optional (UX + tests) — only if approved
```

P1, P3, P4 are mutually independent and **parallelizable**. P2 should land and
soak first (most files depend on its patterns).

---

## Phase 0: Baseline

### Task 0: Confirm green baseline + capture behavior notes
**Description:** Establish that lint/format/load are clean *before* any change, so
later breakage is unambiguous. Note the current visible behavior of the surfaces
about to change (3 panels, status pickers, switch-project, links/notes recents,
docker start/stop).
**Acceptance:**
- [ ] `selene lua`, `stylua --check .`, `nvim --headless +qa` all clean on `HEAD`
- [ ] Short notes captured for the surfaces above (screenshots optional)
**Verification:** the three commands; manual trigger of each surface once.
**Dependencies:** None · **Files:** none · **Scope:** XS

---

## Phase 1: `ui.show_panel` (target A)

### Task 1: Add `ui.show_panel(opts)`
**Description:** Implement the read-only centered float helper per spec §A in
`utils/ui.lua`, returning the window id. Standardize width on `strdisplaywidth`.
**Acceptance:**
- [ ] Signature `M.show_panel({ title, lines })` → `win`
- [ ] Sets `modifiable=false`, `bufhidden=wipe`, `buftype=nofile`; `q`/`<Esc>` close
- [ ] Applies per-line highlights
**Verification:** Tier-1; headless `require` + open with sample `{text,hl}` lines.
**Dependencies:** Task 0 · **Files:** `lua/custom/utils/ui.lua` · **Scope:** S

### Task 2: Migrate `env_check.show_env_status`
**Acceptance:** env-health panel visually identical; close keys work.
**Verification:** Tier-1; trigger env-status keymap, compare to baseline notes.
**Dependencies:** Task 1 · **Files:** `lua/custom/utils/env_check.lua` · **Scope:** S

### Task 3: Migrate `health.workspace_health` (keep `health_win`)
**Acceptance:** health panel identical incl. async git/knip rows; `health_win`
still tracked for re-open/close.
**Verification:** Tier-1; trigger health keymap.
**Dependencies:** Task 1 · **Files:** `lua/custom/actions/health.lua` · **Scope:** S

### Task 4: Migrate `git_dashboard.show_dashboard`
**Acceptance:** dashboard identical.
**Verification:** Tier-1; trigger dashboard keymap.
**Dependencies:** Task 1 · **Files:** `lua/custom/actions/git_dashboard.lua` · **Scope:** S

### ✅ Checkpoint 1 (after Tasks 1–4)
- [ ] All three panels render identically to baseline
- [ ] Zero remaining inline float blocks (`rg 'nvim_open_win' lua/custom` → only `ui.lua`)
- [ ] Tier-1 clean · **Review with human**

---

## Phase 2: `async` on `vim.system` (target B) — HIGH RISK

### Task 5: Rewrite `async.lua` + add `run_cmd`/`json`
**Description:** Reimplement `execute`/`run` on `vim.system` (preserve trim +
`code==1`-as-success semantics) and add `run_cmd`/`json` per spec §B. No
`jobstart`.
**Acceptance:**
- [ ] `execute(cmd, cb)` and `run(cmd, ok, err)` keep current contracts
- [ ] `run_cmd(cmd, on_done)` and `json(cmd, on_ok, on_err)` added
- [ ] No `vim.fn.jobstart` remains in `async.lua`
**Verification:** Tier-1; **smoke the two dependents**: Todoist picker (uses
`execute`) and GitHub notifications (uses `run`).
**Dependencies:** Task 0 · **Files:** `lua/custom/utils/async.lua` · **Scope:** S

### Task 6: Migrate `status.lua` (3 pickers) to `async.json`
**Acceptance:** CI-checks + PR pickers identical; the friendly "No PR found"
message preserved via `on_err`.
**Verification:** Tier-1; trigger CI-checks keymap on a branch with **and**
without a PR.
**Dependencies:** Task 5 · **Files:** `lua/custom/actions/status.lua` · **Scope:** S

### Task 7: Migrate `git_dashboard.lua` + `branch.lua`
**Acceptance:** dashboard data + branch picker identical; local `run_gh`/`run_git`
removed.
**Verification:** Tier-1; trigger dashboard + branch keymaps.
**Dependencies:** Task 5 (Task 4 already moved the panel) · **Files:**
`lua/custom/actions/git_dashboard.lua`, `branch.lua` · **Scope:** M

### Task 8: Migrate `health.lua` + `editor.lua` + `files.lua` + `project.lua` subprocess calls
**Acceptance:** each affected command identical; no ad-hoc `run_gh`/`run_git`
remain.
**Verification:** Tier-1; trigger health, editor, files, switch-project surfaces.
**Dependencies:** Task 5 · **Files:** those 4 modules (≤5) · **Scope:** M

### ✅ Checkpoint 2 (after Tasks 5–8)
- [ ] `rg 'jobstart|local function run_gh|local function run_git' lua/custom` → none
- [ ] Todoist + GH-notifications still work (the async dependents)
- [ ] Tier-1 clean · **Review — this is the riskiest util; soak before continuing**

---

## Phase 3: `files.scan` (target C)

### Task 9: Add `files.scan` + `files.scan_programming`
**Acceptance:** helpers match spec §C; default exclude =
`{Worktrees, wcreated, wcheckout}`; hidden filtered unless `hidden=true`.
**Verification:** Tier-1; headless assert against a temp dir tree.
**Dependencies:** Task 0 · **Files:** `lua/custom/utils/files.lua` · **Scope:** S

### Task 10: Migrate `project.lua` + `pnpm.lua` + `editor.lua` scans
**Acceptance:** switch-project list, pnpm org/repo lists, editor scan identical.
**Verification:** Tier-1; trigger switch-project + pnpm + editor pickers.
**Dependencies:** Task 9 · **Files:** `project.lua`, `pnpm.lua`, `editor.lua` · **Scope:** M

### Task 11: Migrate `files.lua` + `notes.lua` + `github.lua` scans
**Acceptance:** copy-frontend-paths, notes md/subdir lists, github programming
scan identical.
**Verification:** Tier-1; trigger those surfaces.
**Dependencies:** Task 9 · **Files:** `files.lua`, `notes.lua`, `github.lua` · **Scope:** M

### ✅ Checkpoint 3 (after Tasks 9–11)
- [ ] `rg 'fs_scandir' lua/custom` → only `files.lua`
- [ ] Tier-1 clean

---

## Phase 4: `usage_cache` (target D)

### Task 12: Generalize `frequency_cache` → `usage_cache`
**Description:** Store `{ count, last_used }` per key; add `sort_by_recency` and
`recent(ns, n)`; keep `record`/`get_count`/`sort_by_frequency`/`clear`. Update
existing `frequency_cache` callers (grep first) or leave a thin
`frequency_cache.lua` alias.
**Acceptance:**
- [ ] Frequency ordering unchanged; recency ordering + `recent` added
- [ ] No caller of the old module breaks
**Verification:** Tier-1; headless assert both orderings.
**Dependencies:** Task 0 · **Files:** `lua/custom/utils/usage_cache.lua` (+ alias)
· **Scope:** S

### Task 13: Migrate `links.lua` + `notes.lua` recents (reset on cutover)
**Acceptance:** recents behave the same after rebuild; private MRU JSON files no
longer written; old files ignored.
**Verification:** Tier-1; open links + notes pickers, use a few, confirm MRU order.
**Dependencies:** Task 12 · **Files:** `links.lua`, `notes.lua` · **Scope:** M

### Task 14: Migrate `todoist.lua` project/section caches
**Acceptance:** recent projects/sections ordering identical.
**Verification:** Tier-1; open Todoist project + section pickers.
**Dependencies:** Task 12 · **Files:** `lua/custom/utils/todoist.lua` · **Scope:** S

### ✅ Checkpoint 4 (after Tasks 12–14)
- [ ] One usage cache file on disk; no bespoke MRU JSON written
- [ ] Tier-1 clean

---

## Phase 5: `ui.pick` (target E)

### Task 15: Add `ui.pick(opts)`
**Acceptance:** guards Snacks via `pcall`, notifies if unavailable/empty,
standard confirm = close-then-act, passes `opts.extra` through.
**Verification:** Tier-1; headless smoke with a stub items list.
**Dependencies:** Task 1 · **Files:** `lua/custom/utils/ui.lua` · **Scope:** S

### Task 16a: Migrate `project.lua` + `branch.lua` + `text_search.lua` pickers
**Acceptance:** open/confirm/close identical; custom keys (if any) via `opts.extra`.
**Verification:** Tier-1; trigger each.
**Dependencies:** Task 15 (+ Task 7/10 already touched these) · **Files:** those 3 · **Scope:** M

### Task 16b: Migrate `toggleterm.lua` + `session.lua` + `files.lua` + `status.lua` pickers
**Acceptance:** identical behavior; `safe_select` retained for back/left-right cases.
**Verification:** Tier-1; trigger each.
**Dependencies:** Task 15 · **Files:** those 4 · **Scope:** M

### ✅ Checkpoint 5 (after Tasks 15–16b)
- [ ] `rg "pcall\(require, 'snacks'\)" lua/custom` count drops to the few
      intentional `safe_select`/special cases
- [ ] Tier-1 clean · **Review**

---

## Phase 6: Collapse duplicate function pairs (target F)

### Task 17: `links.lua` pairs (3) → parameterized
**Acceptance:** `open_useful_link`/private, technical/current-repo, repo/prs all
keep their keymaps + `desc`; one implementation each.
**Verification:** Tier-1; trigger both keymaps of each pair.
**Dependencies:** Task 13 · **Files:** `links.lua` (+ verify `keymaps.lua` lhs) · **Scope:** S

### Task 18: `files.lua` byte-identical pair + `git.lua` `diff_vs(ref)`
**Acceptance:** `copy_opencode_link`/`copy_ai_file_reference` collapse to one;
`diff_vs_main`/`diff_vs_develop` → `diff_vs(ref)`; both keymaps work.
**Verification:** Tier-1; trigger all four keymaps.
**Dependencies:** Checkpoint 5 · **Files:** `files.lua`, `git.lua` · **Scope:** S

### Task 19: `jira.lua` + `todoist.lua` pairs
**Acceptance:** browse-my/recently-updated, recent projects/sections,
edit/delete-recent collapse with a param; keymaps intact.
**Verification:** Tier-1; trigger each keymap.
**Dependencies:** Task 14 · **Files:** `jira.lua`, `todoist.lua` · **Scope:** S

### ✅ Checkpoint 6 (after Tasks 17–19)
- [ ] Every listed pair is one function; all original keymaps verified
- [ ] Tier-1 clean

---

## Phase 7: Safety / quality (target H)

### Task 20: Harden `docker.lua` to list-form `vim.system`
**Description:** Replace string concatenation + `vim.fn.system(string)` in
`start_db`/`stop_db`/`cleanup_all`/`status` with argv lists; split `&&` chains
into sequential calls; keep all notifications.
**Acceptance:**
- [ ] No shell-string interpolation of `password`/`port`/`image`/`container`
- [ ] start → status → stop round-trip works
**Verification:** Tier-1; manual `start_db` then `stop_db` on a real branch.
**Dependencies:** Task 5 · **Files:** `lua/custom/actions/docker.lua` · **Scope:** S

### Task 21: Unify JSON decode across `lua/custom`
**Acceptance:** standardize on `vim.json.decode`/`encode` (or `custom.utils.json`);
remove `vim.fn.json_decode`.
**Verification:** Tier-1; `rg 'vim\.fn\.json_decode' lua/custom` → none.
**Dependencies:** Task 6 · **Files:** `status.lua` + other decode sites (≤5/commit) · **Scope:** M

### Task 22: Remove dead code + redundant requires
**Acceptance:** commented dead keymap blocks gone from `snacks.lua`; unused
`title` removed in `github.lua`; in-function `require` of `async`/`terminal_registry`
removed where top-level require exists (`todoist.lua`, `language.lua`).
**Verification:** Tier-1; `nvim --headless +qa` clean; spot-trigger affected features.
**Dependencies:** Checkpoint 6 · **Files:** `snacks.lua`, `github.lua`, `todoist.lua`, `language.lua` · **Scope:** S

### ✅ Checkpoint 7 (after Tasks 20–22)
- [ ] docker round-trip safe; no `vim.fn.json_decode`; no dead blocks
- [ ] Tier-1 clean · **Review**

---

## Phase 8: Split oversized files (target G) — HIGH RISK, LAST

Pattern for each: create `actions/<area>/` with focused modules + an `init.lua`
that re-exports the same public `M.*` surface, so `require('custom.actions.<area>')`
in `keymaps.lua` is **unchanged**. Move functions concern-by-concern; old file
deleted only when empty.

### Task 23a–d: Split `github.lua` (1641 → `actions/github/`)
- **23a:** scaffold `github/init.lua` re-export + move **repos** funcs
- **23b:** move **prs** funcs
- **23c:** move **notifications** funcs (drop dead `title`)
- **23d:** move **orgs** funcs; delete old `github.lua`
**Acceptance (each):** moved funcs reachable; `keymaps.lua` unchanged; sampled
keymaps work; no file > ~400 lines.
**Verification:** Tier-1; trigger a keymap from each concern as it moves.
**Dependencies:** Checkpoint 7 · **Files:** `actions/github/*`, (final) old file · **Scope:** M each

### Task 24: Split `jira.lua` (759 → `actions/jira/{create,browse,link}.lua` + init)
**Acceptance/Verification:** as above for Jira surfaces.
**Dependencies:** Task 19 · **Files:** `actions/jira/*` · **Scope:** M

### Task 25: Split `git.lua` (661 → `actions/git/{diff,worktree,branch-ops}.lua` + init)
**Description:** mind the existing separate `branch.lua` (don't collide).
**Acceptance/Verification:** as above for git surfaces.
**Dependencies:** Task 18 · **Files:** `actions/git/*` · **Scope:** M

### Task 26: Slim `plugins/snacks.lua` (765)
**Acceptance:** dead commented keymap blocks removed; any `custom/`-belonging
picker logic moved out; lean lazy spec remains; startup unaffected.
**Verification:** Tier-1; `nvim --headless +qa`; Snacks picker/dashboard/terminal smoke.
**Dependencies:** Task 22 · **Files:** `lua/plugins/snacks.lua` (+ target custom module) · **Scope:** M

### ✅ Checkpoint 8 (after Tasks 23–26)
- [ ] No action file > ~400 lines; `keymaps.lua` requires resolve; all sampled
      keymaps fire; `snacks.lua` lean
- [ ] Tier-1 clean · **Review — full manual smoke pass of major surfaces**

---

## Phase 9: Optional (approval-gated)

### Task 27: UX improvements from spec §I (only approved items)
### Task 28: Tier-3 test harness (`mini.test` or headless asserts) for pure utils
**Dependencies:** Checkpoint 8 + explicit approval · **Scope:** TBD

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `async.lua` rewrite breaks Todoist/GH-notifications (shared internals) | High | Land Task 5 alone; smoke both dependents at Checkpoint 2 before migrating more; keep `execute`/`run` contracts identical |
| File split misroutes a function → dead keymap | High | `init.lua` re-export keeps require paths stable; move concern-by-concern; trigger a keymap per concern; split is last (Phase 8) |
| `ui.pick` too rigid for pickers with custom keys/multi-actions | Med | `opts.extra` passthrough; keep `safe_select` for back/left-right cases; migrate simple pickers first |
| MRU reset surprises (Q1) | Low | Documented one-time reset; recents rebuild quickly; migration available if you prefer |
| Hidden caller of `frequency_cache` | Low | Grep callers in Task 12; ship alias shim |
| `stylua` reflows large moved blocks oddly | Low | `stylua .` then re-read diff; 160-col/collapse settings already match |
| Scope creep into UX | Med | Target I deferred to Phase 9 behind approval |

## Parallelization

- **Parallel-safe:** Phases 1, 3, 4 (independent utils + their callers).
- **Sequential:** Phase 2 first-to-soak; Phase 5 after 1+2; Phase 8 last.
- **Coordinate:** files touched by multiple phases (`editor.lua`, `files.lua`,
  `project.lua`, `status.lua`) — land one phase's commit before the next touches
  the same file to keep diffs reviewable.

## Open Questions (carried; defaults assumed above)

1. Override any of the Q1–Q5 defaults in Architecture Decisions?
2. Commit granularity — one commit per task (recommended), or per phase?
3. Should Phase 8 (file splits) ship as its own PR separate from Phases 1–7?
