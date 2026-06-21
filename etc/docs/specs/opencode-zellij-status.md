# Spec: OpenCode Processing Status in Zellij Tab Names

Status: **DRAFT — awaiting review** (Phase 1: Specify)

## Objective

Surface each OpenCode session's processing state as an emoji in its Zellij tab
name, so you can glance at the tab bar and know whether OpenCode is working,
finished, or quiet — without switching to the tab.

Three states:

| State        | Emoji      | Meaning                                                        |
|--------------|------------|----------------------------------------------------------------|
| `idle`       | *(none)*   | OpenCode is not processing. Tab name unchanged.                |
| `processing` | `🤖`       | OpenCode is actively working on a turn.                        |
| `done`       | `✅`       | OpenCode finished a turn **while you were on another tab**.    |

Reset rule: a `done` (`✅`) badge means "finished while you weren't looking." It
clears back to `idle` (no emoji) the moment you switch to that tab. If OpenCode
finishes while you are *already viewing* its tab, it goes straight to `idle` and
never shows `✅`.

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
  is Bun (provides `$` shell + `client` SDK).
- **Zellij** — tab renaming via `zellij action rename-tab-by-id <id> <name>`
  (renames a background tab) and tab/focus introspection via
  `zellij action list-tabs --json` / `zellij action dump-layout`.
- **zsh** — existing `zellij_tab_name_update` (chpwd hook) builds base tab names.
- **State store** — plain files under `/tmp/opencode-zellij/` for grid
  aggregation (no daemon, no DB).
- **Tests** — Node's built-in `node --test` runner (no new dependencies) for the
  pure helper functions.

### Authoritative status signal (verified against installed SDK)

```ts
// node_modules/@opencode-ai/sdk/dist/gen/types.gen.d.ts
type SessionStatus = { type: "idle" } | { type: "busy" } | { type: "retry"; ... }
type EventSessionStatus = { type: "session.status"; properties: { sessionID: string; status: SessionStatus } }
type EventSessionIdle   = { type: "session.idle";   properties: { sessionID: string } }
```

- `session.status` with `status.type === "busy"` ⇒ **processing**
- `session.idle` ⇒ **turn finished** ⇒ resolve to `done` or `idle` per the reset rule
- These events fire regardless of how OpenCode was launched (`o`, bare
  `opencode`, or the grid layouts), so a plugin covers every launch path.

## Proposed Architecture

A **single OpenCode plugin** (`src/opencode/plugins/zellij-status.js`) owns the
feature. No background daemon (chosen for seamless install + zero idle cost).

```
session.status busy ──▶ set my status = processing ──▶ render tab
session.idle ──┬─ my tab focused now?  yes ─▶ status = idle  ─▶ render tab
               └─ no ─▶ status = done ─▶ render tab ─▶ arm focus-watch poll
focus-watch poll (≈250ms, only while a `done` badge is pending):
   my tab became focused? ─▶ status = idle ─▶ render tab ─▶ stop poll
```

### Tab identity

- On the **first** `session.status` `busy` event (which always happens while the
  tab is focused, because the user just submitted a prompt there), resolve the
  focused tab's `tab_id` from `zellij action list-tabs --json` and **cache it for
  the session's lifetime**. `tab_id` is stable across tab moves/reindexing
  (the reindexer already renames by id), so the cache stays valid even if the
  user reorders tabs.

### Grid aggregation (multiple OpenCode in one tab — `Alt a` / `Alt g`)

- Each pane writes its own status to `/tmp/opencode-zellij/<tab_id>/<pid>`
  containing `processing` | `done` | `idle`.
- The renderer computes the tab's aggregate before renaming:
  - any pane `processing` ⇒ tab shows `🤖`
  - else any pane `done` ⇒ tab shows `✅`
  - else ⇒ no emoji
- **Self-healing:** files are named by PID; during aggregation, entries whose PID
  is no longer alive (`kill -0`) are pruned, so a crashed/closed pane never
  leaves a stuck badge.
- Single-pane tabs are the degenerate case (one file).

### Name merge (survive reindex, avoid clobber)

- Emoji is a **suffix** on the existing `<index>.<base>` name, e.g.
  `3.dotf` → `3.dotf🤖`.
- The reindexer (`update_tab_indexes.sh`) strips a leading `N.` then re-prefixes,
  so a suffix emoji **survives reindexing** untouched.
- Before renaming, the renderer reads the tab's current name, strips any existing
  trailing `🤖`/`✅`, then appends the new emoji (or nothing). Renames via
  `rename-tab-by-id` (works on background tabs; never steals focus).
- `zellij_tab_name_update` (zsh `chpwd`) rebuilds names from scratch and would
  drop the emoji on `cd`. Mitigation: teach `zellij_tab_name_update` to preserve
  a trailing status emoji. (Small, optional-but-recommended zsh change for
  seamlessness; during processing the plugin also re-applies on every event.)

### Concurrency

- A per-tab lock (`flock` on `/tmp/opencode-zellij/<tab_id>.lock`) serializes
  rename operations so grid panes don't flicker by racing each other.

## Commands

This repo has no build system. Relevant commands:

```bash
# Symlinks are already in place (src/opencode -> ~/.config/opencode). After
# editing the plugin, restart the OpenCode session to reload it.

# Run the pure-helper unit tests (no deps, Node built-in runner):
node --test src/opencode/plugins/

# Manual end-to-end verification (must be inside a Zellij session):
#   1. `o` (or bare `opencode`) in a tab, send a prompt  -> tab shows 🤖
#   2. switch to another tab; let it finish              -> origin tab shows ✅
#   3. switch back                                        -> ✅ clears
#   4. `Alt a` grid, prompt one pane, switch away/back    -> aggregate 🤖/✅

# Re-sync symlinks if needed:
bash etc/scripts/src/install/sync_links.sh   # (confirm exact path during PLAN)
```

## Project Structure

```
src/opencode/plugins/zellij-status.js     # NEW — the feature (status -> tab emoji)
src/opencode/plugins/zellij-status.test.js# NEW — node --test unit tests (pure helpers)
etc/scripts/src/zshrc/zellij.sh           # EDIT — preserve trailing emoji in chpwd rename
etc/scripts/src/zshrc/opencode.sh         # EDIT — remove dead /tmp/opencode-status-$$ writer
/tmp/opencode-zellij/<tab_id>/<pid>       # RUNTIME — per-pane status files
```

`src/opencode/plugins/notification.js` is left as-is (separate concern: sounds +
desktop notifications). The new plugin is independent.

## Code Style

Match the existing plugin: ES modules, named export factory, `async` event
handler, defensive `try/catch`, no external deps. Pure logic extracted into
testable, side-effect-free helpers.

```js
// Pure, unit-testable core — no Zellij, no I/O.
export const STATUS = { idle: "", processing: "🤖", done: "✅" }

/** Aggregate many panes' statuses into one tab badge. */
export const aggregate = (statuses) => {
  if (statuses.includes("processing")) return "processing"
  if (statuses.includes("done")) return "done"
  return "idle"
}

/** Replace any trailing status emoji on a tab name with the new one. */
export const applyEmoji = (name, status) => {
  const base = name.replace(/[🤖✅]+$/u, "")
  return base + STATUS[status]
}
```

Shell edits follow repo conventions: `set -e`, source `common/logging.sh`, use
`log_info`/`log_error`, function-based structure.

## Testing Strategy

- **Unit (automated):** `node --test` on the pure helpers — `aggregate()`,
  `applyEmoji()`, the status state machine (busy→processing,
  idle+focused→idle, idle+unfocused→done, focus→idle), and PID-pruning logic
  (with `kill -0` stubbed). No Zellij required. This is the TDD surface.
- **Integration (manual checklist):** the 4 numbered scenarios under Commands,
  plus grid (`Alt a`/`Alt g`) aggregation and a reindex (`Alt i`/`Alt o`)
  preserving the emoji. Documented as a checklist in the PR.
- **Regression:** confirm OpenCode launched **outside** Zellij produces no errors
  and no `zellij` calls.

## Boundaries

- **Always:**
  - Use `rename-tab-by-id` (never `rename-tab`) so background tabs are renamed
    without stealing focus.
  - Place the emoji as a suffix so the reindexer preserves it.
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

1. OpenCode processing in a Zellij tab shows `🤖` within ~500ms of starting.
2. OpenCode finishing **while you're on a different tab** makes that tab show `✅`.
3. Switching to a `✅` tab clears it to no-emoji within ~300ms (keyboard *and*
   mouse tab-click).
4. OpenCode finishing **while you're already on its tab** shows no `✅` (straight
   to `idle`).
5. Tab reindex (`Alt n/q/i/o`, new/close/move) preserves the status emoji.
6. `cd` inside the tab does not permanently lose the emoji during processing.
7. Grid tabs (`Alt a` = 4 panes, `Alt g` = 8 panes) show `🤖` if **any** pane is
   processing, `✅` when **all** are done (until viewed), nothing when all idle.
8. OpenCode run **outside** Zellij behaves exactly as before (no errors, no
   `zellij` invocations).
9. No persistent background process; ~0 CPU when nothing is processing (polling
   runs only while a `done` badge is pending).
10. A crashed/closed OpenCode pane self-heals (no stuck badge) via PID pruning.

## Open Questions (resolve before/at PLAN)

1. **Focus detection field:** does `zellij action list-tabs --json` expose an
   `active`/`is_focused` flag? If yes, one call gives both `tab_id` and focus.
   If not, correlate the focused position from `dump-layout` to `tab_id` from
   `list-tabs` (the approach `zellij_tab_name_update` already uses). → First PLAN
   task: capture real `list-tabs --json` + `dump-layout` output to confirm.
2. **Poll interval:** default `250ms` while a `done` badge is pending — acceptable?
   Make it tunable via `OPENCODE_ZELLIJ_POLL_MS`.
3. **Big-grid poll cost:** with an 8-pane grid all `done` and unfocused, 8 plugins
   each poll until you switch. Acceptable for v1? Optional optimization: a single
   per-tab poller via lock. (If undesirable, the alternative is one lightweight
   per-Zellij-session daemon — explicitly *not* chosen here to keep install
   trivial and idle cost zero.)
4. **chpwd preservation:** confirm we may edit `zellij_tab_name_update` to keep a
   trailing emoji (recommended for seamlessness).
5. **Spec location:** keep specs at `etc/docs/specs/`? (New convention.)

## Decisions (locked)

- Scope: **all** launch paths, including `Alt a` / `Alt g` grids (aggregated).
- Emoji: idle = *(none)*, processing = `🤖`, done = `✅`.
