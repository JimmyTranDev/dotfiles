# Spec: OpenCode Processing Status in Zellij Tab Names

Status: **Implemented** — Phases 1–5 complete. Pure helpers + DI orchestration
core are unit-tested (57 `node --test` cases green across `src/opencode/lib/`);
the thin real-I/O plugin adapter is validated end-to-end against a faithful
`$`/filesystem fake.

## Objective

Surface each OpenCode session's processing state as a glyph in its Zellij tab
name, so you can glance at the tab bar and know whether OpenCode is working,
finished, or quiet — without switching to the tab.

Three states:

| State        | Glyph      | Meaning                                                        |
|--------------|------------|----------------------------------------------------------------|
| `idle`       | *(none)*   | OpenCode is not processing. Tab name unchanged.                |
| `processing` | `⚙`       | OpenCode is actively working on a turn.                        |
| `done`       | `✓`       | OpenCode finished a turn **while you were on another tab**.    |

Reset rule: a `done` (`✓`) badge means "finished while you weren't looking." It
clears back to `idle` (no glyph) the moment you switch to that tab. If OpenCode
finishes while you are *already viewing* its tab, it goes straight to `idle` and
never shows `✓`.

Primary requirement from the user: **fast and seamless** — near-instant badge
updates, no perceptible lag, no heavy background cost when nothing is running.

### Who / why

Single user (this dotfiles owner). Runs OpenCode inside Zellij constantly, often
several sessions across tabs (including 4-pane `Alt a` and 8-pane `Alt g`
grids). Needs an at-a-glance signal of which background session needs attention.

## Tech Stack

- **OpenCode plugin** — JavaScript, auto-loaded from
  `~/.config/opencode/plugins/*.js` (symlinked from `src/opencode/plugins/`).
  SDK `@opencode-ai/plugin@1.14.40`, `@opencode-ai/sdk@1.14.40`. Plugin runtime
  is Bun (provides the `$` shell — `BunShell` with `.nothrow()`/`.quiet()`/
  `.json()` — and the `client` SDK).
- **Zellij** — tab renaming via `zellij action rename-tab-by-id <id> <name>`
  (renames a background tab without stealing focus) and tab/focus introspection
  via `zellij action list-tabs --json` (a single pretty-printed JSON array; each
  tab object carries both `tab_id` and an `active` boolean) and
  `zellij action dump-layout`.
- **zsh** — existing `zellij_tab_name_update` (chpwd hook) builds base tab names.
- **State store** — plain files under `/tmp/opencode-zellij/<tab_id>/<pid>` for
  grid aggregation (no daemon, no DB).
- **Tests** — Node's built-in `node --test` runner (no new dependencies). All
  logic lives in `src/opencode/lib/` so it is testable without booting OpenCode
  or a live Zellij; `plugins/` is auto-loaded by OpenCode and so holds no tests.

### Authoritative status signal (verified against installed SDK)

```ts
// node_modules/@opencode-ai/sdk/dist/gen/types.gen.d.ts
type SessionStatus = { type: "idle" } | { type: "busy" } | { type: "retry"; ... }
type EventSessionStatus = { type: "session.status"; properties: { sessionID: string; status: SessionStatus } }
type EventSessionIdle   = { type: "session.idle";   properties: { sessionID: string } }
```

- `session.status` with `status.type === "busy"` ⇒ **processing**
- The `chat.message` hook also marks **processing** the instant a prompt is
  submitted (before the first token), which is when the tab is guaranteed focused.
- `session.idle` ⇒ **turn finished** ⇒ resolve to `done` or `idle` per the reset rule.
- `session.error` / `session.cancelled` also fold into **turn finished**, so a
  crashed or cancelled turn never leaves a stuck `⚙`.
- These events fire regardless of how OpenCode was launched (`o`, bare
  `opencode`, or the grid layouts), so a plugin covers every launch path.

## Architecture (as built)

The feature is the **tab-level companion** to the existing
`src/opencode/plugins/zellij-pane-status.js` (which renames the *pane*). It is
split for testability into three files — two pure/DI modules in `lib/` and one
thin real-I/O adapter in `plugins/`. No background daemon (chosen for seamless
install + zero idle cost).

- `src/opencode/lib/zellij-tab-status.mjs` — **pure, side-effect-free helpers**:
  `STATUS`, `STATE_DIR`, `aggregate`, `stripBadge`, `applyBadge`,
  `resolveTurnEnd`, `eventToTransition`, `findTab`, `activeTab`, `isTabActive`,
  `prunePids`, `parseStateEntries`, `desiredName`.
- `src/opencode/lib/zellij-tab-status-core.mjs` — **dependency-injected
  orchestration core** `createTabStatus(io)`. All side effects are injected via
  `io`, so the full transition state machine runs in memory under `node --test`.
- `src/opencode/plugins/zellij-tab-status.js` — **thin adapter** that supplies a
  real `io` (fs state files, mkdir render lock, `zellij action` calls via `$`,
  a `setInterval` focus poll, exit cleanup) and exports `ZellijTabStatus`. No-op
  when `process.env.ZELLIJ` is unset.

```
chat.message / session.status busy ─▶ status = processing ─▶ render tab
session.idle / error / cancelled ──┬─ my tab focused now?  yes ─▶ status = idle ─▶ render tab
                                   └─ no ─▶ status = done ─▶ render tab ─▶ arm focus-watch poll
focus-watch poll (≈250ms, only while a `done` badge is pending):
   my tab became focused? ─▶ status = idle ─▶ render tab ─▶ stop poll
```

`render` runs under the per-tab lock: list tabs, find our tab, compute
`desiredName(currentName, liveEntries, isAlive)`, and rename **only when the
badge actually changed** (so a tab held `⚙` by a sibling pane is never
needlessly renamed).

### Tab identity

- On the **first** processing transition (`chat.message` or the first
  `session.status` `busy`, which always happens while the tab is focused because
  the user just submitted a prompt there), resolve the focused tab's `tab_id`
  from `zellij action list-tabs --json` (the tab whose `active` is `true`) and
  **cache it for the session's lifetime**. `tab_id` is stable across tab
  moves/reindexing (the reindexer renames by id), so the cache stays valid even
  if the user reorders tabs.

### Grid aggregation (multiple OpenCode in one tab — `Alt a` / `Alt g`)

- Each pane writes its own status to `/tmp/opencode-zellij/<tab_id>/<pid>`
  containing `processing` | `done` | `idle` (atomic temp-write + rename).
- The renderer computes the tab's aggregate before renaming:
  - any pane `processing` ⇒ tab shows `⚙`
  - else any pane `done` ⇒ tab shows `✓`
  - else ⇒ no glyph
- **Self-healing:** files are named by PID; during aggregation, entries whose PID
  is no longer alive (`process.kill(pid, 0)`) are pruned, so a crashed/closed
  pane never leaves a stuck badge.
- Single-pane tabs are the degenerate case (one file).

### Name merge (survive reindex, avoid clobber)

- Glyph is a **suffix** on the existing `<index>.<base>` name, e.g.
  `3.dotf` → `3.dotf⚙`.
- The reindexer (`update_tab_indexes.sh`) strips a leading `N.` then re-prefixes,
  so a suffix glyph **survives reindexing** untouched.
- Before renaming, the renderer reads the tab's current name, strips any existing
  trailing `⚙`/`✓`, then appends the new glyph (or nothing). Renames via
  `rename-tab-by-id` (works on background tabs; never steals focus).
- `zellij_tab_name_update` (zsh `chpwd`) rebuilds names from scratch and would
  drop the glyph on `cd`. **Done:** `zellij_tab_name_update` now reads the
  focused tab's current name from `dump-layout` and re-appends any trailing
  `⚙`/`✓` badge after rebuilding `<index>.<base>`.

### Concurrency

- A per-tab **mkdir lock** (`/tmp/opencode-zellij/<tab_id>/.lock`) serializes
  rename operations so grid panes don't flicker by racing each other. `mkdir`
  is atomic and portable; `flock(1)` is **not** available on macOS, so it was
  deliberately not used. A lock older than ~2s is treated as orphaned by a
  crashed renderer and stolen; after ~1s of contention the renderer proceeds
  unlocked rather than deadlock.

## Commands

This repo has no build system. Relevant commands:

```bash
# Symlinks are already in place (src/opencode -> ~/.config/opencode). After
# editing the plugin, restart the OpenCode session to reload it.

# Run the automated unit tests (no deps, Node built-in runner). Use the glob —
# the bare directory form `node --test src/opencode/lib/` is broken on the
# installed Node v24.3.0 (spurious MODULE_NOT_FOUND):
node --test src/opencode/lib/*.test.mjs

# Syntax-check the zsh edits:
zsh -n etc/scripts/src/zshrc/zellij.sh etc/scripts/src/zshrc/opencode.sh

# Manual end-to-end verification (must be inside a Zellij session):
#   1. `o` (or bare `opencode`) in a tab, send a prompt  -> tab shows ⚙
#   2. switch to another tab; let it finish              -> origin tab shows ✓
#   3. switch back                                        -> ✓ clears
#   4. `Alt a` grid, prompt one pane, switch away/back    -> aggregate ⚙/✓

# Re-sync symlinks if needed:
bash etc/scripts/sync_links.sh
```

## Project Structure

```
src/opencode/lib/zellij-tab-status.mjs           # pure helpers (aggregate/badge/desiredName/…)
src/opencode/lib/zellij-tab-status.test.mjs      # node --test: 30 helper cases
src/opencode/lib/zellij-tab-status-core.mjs      # DI orchestration core: createTabStatus(io)
src/opencode/lib/zellij-tab-status-core.test.mjs # node --test: 13 core cases (in-memory io fake)
src/opencode/plugins/zellij-tab-status.js        # thin real-I/O adapter; exports ZellijTabStatus
etc/scripts/src/zshrc/zellij.sh                  # EDIT — chpwd rename now preserves trailing glyph
etc/scripts/src/zshrc/opencode.sh                # EDIT — removed dead /tmp/opencode-status-$$ writer
/tmp/opencode-zellij/<tab_id>/<pid>              # RUNTIME — per-pane status files
/tmp/opencode-zellij/<tab_id>/.lock              # RUNTIME — per-tab render mkdir lock
```

`src/opencode/plugins/notification.js` (sounds + desktop notifications) and
`src/opencode/plugins/zellij-pane-status.js` (pane names) are left as-is; the new
plugin is independent and targets the **tab** name.

## Code Style

Matches the existing plugins: ES modules, named-export factory, `async` event
handler, defensive `try/catch`, no external deps, double quotes, no semicolons.
Pure logic is extracted into testable, side-effect-free helpers; orchestration is
dependency-injected so it can be exercised without Zellij.

```js
// Pure, unit-testable core — no Zellij, no I/O.
export const STATUS = { idle: "", processing: "⚙", done: "✓" }

// Aggregate many panes' statuses into one tab badge.
export const aggregate = (statuses) => {
  const list = Array.isArray(statuses) ? statuses : []
  if (list.includes("processing")) return "processing"
  if (list.includes("done")) return "done"
  return "idle"
}

// Replace any trailing status glyph on a tab name with the badge for `status`.
export const applyBadge = (name, status) => stripBadge(name) + (STATUS[status] ?? "")
```

The zsh edits are `.zshrc` fragments (sourced into the interactive shell), not
standalone scripts, so they follow that style (no `set -e`, no `logging.sh`)
rather than the `etc/scripts/install` script conventions.

## Testing Strategy

- **Unit (automated, 57 cases):** `node --test src/opencode/lib/*.test.mjs`.
  - 30 helper cases: `aggregate`, `stripBadge`/`applyBadge`, `resolveTurnEnd`,
    `eventToTransition` (incl. error/cancelled folding), `findTab`/`activeTab`/
    `isTabActive`, `prunePids`, `parseStateEntries`, `desiredName`.
  - 13 core cases: the full state machine over an in-memory `io` fake —
    busy→processing, idle+focused→idle, idle+unfocused→done, focus→idle, new
    turn after done, grid aggregation, PID self-heal, exit cleanup, no-ops.
  - 14 pre-existing `zellij-pane-status` helper cases stay green (no regression).
- **Adapter (manual smoke):** the real `io` was exercised end-to-end against a
  faithful `$`/filesystem fake (state-file write, mkdir lock, `list-tabs` via
  `.json()`, glyph `rename-tab-by-id`) producing the `⚙`→`✓`→`⚙` sequence.
- **Integration (manual checklist):** the 4 numbered scenarios under Commands,
  plus grid (`Alt a`/`Alt g`) aggregation and a reindex (`Alt i`/`Alt o`)
  preserving the glyph. Documented as a checklist in the PR.
- **Regression:** OpenCode launched **outside** Zellij returns empty hooks (no
  `zellij` calls) — covered by the adapter guard test.

## Boundaries

- **Always:**
  - Use `rename-tab-by-id` (never `rename-tab`) in the plugin so background tabs
    are renamed without stealing focus.
  - Place the glyph as a suffix so the reindexer preserves it.
  - No-op cleanly when `process.env.ZELLIJ` is unset.
  - Run the unit tests before committing; verify the manual checklist in a real
    Zellij session.
- **Ask first:**
  - Introducing any long-lived background process/daemon (current design avoids
    it).
  - Adding npm dependencies.
  - Changing Zellij keybindings.
- **Never:**
  - Break the existing `<index>.<base>` reindexing (`update_tab_indexes.sh`).
  - Steal focus or change which tab is active as a side effect.
  - Commit secrets; leave stuck badges from dead processes.

## Success Criteria

1. OpenCode processing in a Zellij tab shows `⚙` within ~500ms of starting.
2. OpenCode finishing **while you're on a different tab** makes that tab show `✓`.
3. Switching to a `✓` tab clears it to no-glyph within ~300ms (keyboard *and*
   mouse tab-click).
4. OpenCode finishing **while you're already on its tab** shows no `✓` (straight
   to `idle`).
5. Tab reindex (`Alt n/q/i/o`, new/close/move) preserves the status glyph.
6. `cd` inside the tab does not permanently lose the glyph during processing.
7. Grid tabs (`Alt a` = 4 panes, `Alt g` = 8 panes) show `⚙` if **any** pane is
   processing, `✓` when **all** are done (until viewed), nothing when all idle.
8. OpenCode run **outside** Zellij behaves exactly as before (no errors, no
   `zellij` invocations).
9. No persistent background process; ~0 CPU when nothing is processing (the poll
   is `unref`'d and runs only while a `done` badge is pending).
10. A crashed/closed OpenCode pane self-heals (no stuck badge) via PID pruning
    plus an on-exit `finalize` that removes the pane's file and re-renders.

## Resolved Questions

1. **Focus detection field:** `zellij action list-tabs --json` exposes both
   `tab_id` and an `active` boolean per tab, so one call yields tab id *and*
   focus. (`dump-layout` correlation is unnecessary for the plugin; the zsh
   `chpwd` path still uses `dump-layout` because that is where it already is.)
2. **Poll interval:** `250ms` default while a `done` badge is pending, tunable
   via `OPENCODE_ZELLIJ_POLL_MS`.
3. **Big-grid poll cost:** accepted for v1 — each pane runs its own `unref`'d
   poll only while it personally has a pending `done`. A single per-tab poller is
   a possible future optimization; explicitly **not** a daemon.
4. **chpwd preservation:** yes — `zellij_tab_name_update` now preserves a trailing
   `⚙`/`✓` badge (verified the focused-tab name round-trips through
   `dump-layout`, and that the awk anchor selects the focused *tab*, not a
   focused *pane*).
5. **Spec location:** keep specs at `etc/docs/specs/`.

## Decisions (locked)

- Scope: **all** launch paths, including `Alt a` / `Alt g` grids (aggregated).
- Glyph: idle = *(none)*, processing = `⚙`, done = `✓`.
- File naming: `zellij-tab-status` (the pane-level sibling already owns
  `zellij-status`/`zellij-pane-status`).
- Lock: portable `mkdir` (macOS has no `flock(1)`).
