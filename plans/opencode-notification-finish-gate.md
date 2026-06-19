---
todoist: https://app.todoist.com/app/task/make-it-so-that-opencode-only-sends-notificaiton-if-fully-finished-and-nothing-more-to-do-6gvmjmR9JjgrWG2F
---

# OpenCode Notification: Only Notify When Fully Finished

## TL;DR

- Gate the OpenCode notification plugin so the **"Task completed"** banner only fires on `session.idle` when (a) there is genuinely **nothing more to do** — no `pending`/`in_progress` todos remain for that session — **and** (b) the idle session is the **root session** (not a Task-tool subagent).
- Mechanism: subscribe to the existing **`todo.updated`** event, cache the latest todo list per `sessionID`; on `session.idle` suppress if any todo is outstanding, then suppress again if a `client.session.get` lookup shows the session has a `parentID` (subagent).
- Permission ("Waiting for input") and error ("Task failed") notifications are **kept as-is** — they need attention and are not gated.
- Single file touched: `src/opencode/plugins/notification.js`. 5 small edits, **complexity: small**, no new dependencies, no new env vars.
- One Todoist p1 task is in scope. The sibling p1 task ("make the opencode notifications last mac") was reported **already fixed by the user** and is intentionally excluded.

## Overview

The notification plugin (`src/opencode/plugins/notification.js`) currently sends a "Task completed" notification on **every** `session.idle` event. The user wants it to notify **only when the session is fully finished with nothing left to do**. OpenCode emits a `todo.updated` event carrying the live todo list per session; we use that to detect whether work is still outstanding when the session goes idle, and suppress the completion notification until all todos are `completed`/`cancelled` (or there are no todos at all).

Todoist task: https://app.todoist.com/app/task/make-it-so-that-opencode-only-sends-notificaiton-if-fully-finished-and-nothing-more-to-do-6gvmjmR9JjgrWG2F

## Layer Recommendation

**Tooling / local config (OpenCode plugin).** This is neither frontend nor backend — it is an event-driven Bun/Node plugin in the dotfiles OpenCode config. All logic belongs in the single plugin module; no service/UI split applies.

## Architecture

The plugin is a single exported async factory `Notification({ $, client })` returning one `event` hook. It keeps flat module-scoped mutable state (`taskStartTime`, `lastToolName`, `changedFiles`, etc.) and reacts to events in a long `if/else if` chain inside `event: async ({ event }) => { ... }`.

This change adds:

1. **One piece of state** — `todosBySession`, a `Map<string, Todo[]>` keyed by `sessionID` (decided: per-session Map, not a flat variable) so a subagent's `todo.updated` cannot clobber the root session's todo state, and vice versa.
2. **Two predicate helpers**:
   - `hasOutstandingTodos(sessionId)` — synchronous; whether any cached todo for that session is `pending` or `in_progress`.
   - `isRootSession(sessionId)` — async; calls `client.session.get` and returns `true` when the session has no `parentID`. **Fail-open**: returns `true` (treat as root → notify) on any error/missing client, so a real completion is never silently swallowed.
3. **One new event branch** — `todo.updated` populates the map.
4. **A two-stage guard in the existing `session.idle` branch** — early-return (suppress) when todos are outstanding; then early-return (suppress) when the session is a subagent (`parentID` present); otherwise notify exactly as today and evict the session's map entry.
5. **A `session.deleted` cleanup branch** — evicts the deleted session's cached todos.

Nothing else in the plugin changes. The notification body builder, sound playback, permission handling, and error handling are untouched.

### Authoritative event payloads (from `@opencode-ai/sdk` `dist/gen/types.gen.d.ts`)

```ts
type EventSessionIdle = {
  type: "session.idle";
  properties: { sessionID: string };
};

type Todo = {
  content: string;
  status: string;   // "pending" | "in_progress" | "completed" | "cancelled"
  priority: string; // "high" | "medium" | "low"
  id: string;
};

type EventTodoUpdated = {
  type: "todo.updated";
  properties: { sessionID: string; todos: Array<Todo> };
};

// Session has optional parentID (used by the root-session gate)
type Session = { id: string; parentID?: string; title: string; /* ... */ };
```

> Note: `session.idle` exposes `properties.sessionID` (capital `ID`). The current `session.idle` handler ignores the session id entirely; this change starts reading it.

## Data Flow

1. The agent calls the `todowrite` tool → OpenCode emits `todo.updated` with `{ sessionID, todos }`.
2. Plugin stores `todosBySession.set(sessionID, todos)` (latest snapshot replaces the previous one for that session).
3. The agent finishes its turn → OpenCode emits `session.idle` with `{ sessionID }`.
4. **Stage 1 — todo gate.** Plugin computes `hasOutstandingTodos(sessionID)`:
   - **Outstanding** (any `pending`/`in_progress`) → `return` early. No sound, no banner, no state reset. The session can resume and will emit `session.idle` again later.
   - **None outstanding** (all `completed`/`cancelled`, or no cached todos) → proceed to Stage 2.
5. **Stage 2 — root-session gate.** Plugin awaits `isRootSession(sessionID)`:
   - **Subagent** (`parentID` present) → `return` early. No notification for child sessions.
   - **Root** (no `parentID`, or lookup failed → fail-open) → play idle sound, build body, reset tracking state, evict the map entry, send the "Task completed" notification (current behavior).
6. `session.deleted` evicts the session's map entry to keep the map tidy.

## Tasks

All tasks are in the single file **`src/opencode/plugins/notification.js`** and are sequential (same module, same handler). Total complexity: **small**.

### Task 1 — Add todo state + predicate helpers (small)
- After the existing state declarations (around `let sessionTitle = ""`, line ~12), add:
  ```js
  const todosBySession = new Map()
  ```
- Add a synchronous predicate alongside the other helpers (e.g. near `resetTrackingState`):
  ```js
  const hasOutstandingTodos = (sessionId) => {
    const todos = todosBySession.get(sessionId) || []
    return todos.some((todo) => todo.status === "pending" || todo.status === "in_progress")
  }
  ```
- Add an async root-session predicate (mirrors the existing `client.session.get` usage in `updateSessionTitle`, fail-open):
  ```js
  const isRootSession = async (sessionId) => {
    if (!client?.session?.get || !sessionId) {
      return true
    }
    try {
      const result = await client.session.get({ path: { id: sessionId } })
      const session = result?.data || result
      return !session?.parentID
    } catch {
      return true
    }
  }
  ```
- Dependencies: none. Must land before Tasks 2–3.

### Task 2 — Cache todos on `todo.updated` (small)
- Add a new branch in the `event` hook's `if/else if` chain (place it just before the `session.idle` branch):
  ```js
  } else if (event.type === "todo.updated") {
    const sessionId = event?.properties?.sessionID || ""
    const todos = event?.properties?.todos || []
    if (sessionId) {
      todosBySession.set(sessionId, todos)
    }
  }
  ```
- Depends on Task 1 (the map).

### Task 3 — Gate the `session.idle` notification (small)
- Replace the current `session.idle` branch (lines ~158–164) with the two-stage guarded version:
  ```js
  } else if (event.type === "session.idle") {
    const sessionId = event?.properties?.sessionID || ""
    if (hasOutstandingTodos(sessionId)) {
      return
    }
    if (!(await isRootSession(sessionId))) {
      return
    }
    needsAttention = true
    await playSound(idleSound)
    const body = buildNotificationBody("idle")
    taskStartTime = null
    resetTrackingState()
    todosBySession.delete(sessionId)
    await sendNotification("Task completed", body)
  }
  ```
- Order matters: the cheap synchronous todo check runs first; the async `isRootSession` lookup only runs once todos are clear.
- Depends on Tasks 1 and 2. This is the core behavior change.

### Task 4 — Evict on `session.deleted` (small)
- Add cleanup so the map does not retain entries for deleted sessions:
  ```js
  } else if (event.type === "session.deleted") {
    const sessionId = event?.properties?.info?.id || ""
    if (sessionId) {
      todosBySession.delete(sessionId)
    }
  }
  ```
- `session.deleted` carries `properties.info` (a full `Session`), hence `info.id`.
- Depends on Task 1.

### Task 5 — Manual verification + cleanup (small)
- Optionally add temporary `client.app.log({ body: { service: "notification", level: "debug", message, extra } })` lines to confirm suppression decisions, then remove them.
- Verify the scenarios in **Testing approach**, then delete any debug logging.

## API Contracts

This is internal to one plugin; the "contracts" are the consumed event shapes and the new internal surface.

- **Consumed events** (read-only):
  - `todo.updated` → `event.properties.sessionID: string`, `event.properties.todos: Todo[]`.
  - `session.idle` → `event.properties.sessionID: string`.
  - `session.deleted` → `event.properties.info.id: string`.
- **SDK call**: `client.session.get({ path: { id: sessionId } })` → returns `{ data?: Session } | Session`; read `parentID` to distinguish root vs subagent.
- **Todo status domain**: `"pending" | "in_progress" | "completed" | "cancelled"`. "Outstanding" = `pending` or `in_progress`.
- **New internal state**: `todosBySession: Map<string, Todo[]>`.
- **New internal helpers**: `hasOutstandingTodos(sessionId: string): boolean`, `isRootSession(sessionId: string): Promise<boolean>` (fail-open → `true`).
- **Behavioral contract**: a "Task completed" notification fires **iff** `session.idle` fires, `hasOutstandingTodos(sessionID) === false`, **and** `isRootSession(sessionID) === true`. Permission and error notifications are unaffected.

## State Changes

- **No** new database tables, config keys, or environment variables.
- One new in-memory `Map` (process-lifetime, lost on restart — acceptable, todos are re-emitted on the next `todo.updated`).
- Existing env vars (`OPENCODE_SOUND_IDLE`, `OPENCODE_SOUND_PERMISSION`, `OPENCODE_SOUND_ERROR`, `OPENCODE_SOUND_VOLUME`) are unchanged.

## Edge Cases

- **No todos ever created** for the session → `hasOutstandingTodos` is `false`; if root session → notify. (Simple tasks still notify — correct.)
- **All todos completed/cancelled** on a root session → notify (the intended "fully finished" case).
- **Some pending/in_progress** → suppress at Stage 1; no sound, no banner, no state reset, no session lookup.
- **Stale completed todos from a prior turn** still cached → next idle notifies (acceptable; map entry is evicted after each successful notify).
- **Session stuck idle with pending todos, no error** → no notification by design (decided: no timeout fallback). Genuine failures still surface via the untouched `session.error` → "Task failed" notification.
- **Empty/missing `sessionID` on idle** → no cached todos (Stage 1 passes) and `isRootSession("")` returns `true` (fail-open) → notify. Never silently swallows a completion.
- **Subagent (child session) goes idle with all its todos done** → `isRootSession` finds a `parentID` → suppressed (decided: root-session-only). No "Task completed" banner for subagents.
- **`client.session.get` lookup fails or returns no session** → `isRootSession` fails open (`true`) → notify. Worst case is an occasional extra subagent notification, never a missed real completion.
- **Map growth** across many sessions → negligible (a handful of ids); Task 4 (`session.deleted` eviction) + post-notify eviction keep it bounded.

## Testing Approach

Plugins have no unit harness in this repo, so verification is manual/observational:

1. **Multi-todo task**: run a task that creates several todos. Confirm **no** "Task completed" notification while any todo is `pending`/`in_progress`, and **exactly one** notification once all are `completed`.
2. **No-todo task**: run a trivial task that never calls `todowrite`. Confirm a single "Task completed" notification still fires on idle.
3. **Subagent task**: run a task that delegates to a Task-tool subagent. Confirm the subagent finishing does **not** fire a banner, and only the root session's final idle notifies.
4. **Error path**: trigger a `session.error`. Confirm "Task failed" still notifies (unchanged).
5. **Permission path**: trigger a `permission.asked`. Confirm "Waiting for input" still notifies (unchanged).
6. Use temporary `client.app.log()` to print `{ sessionID, outstanding, parentID }` at each idle, then remove once verified.

## Decisions

All pre-analysis and post-specification questions have been resolved with the user:

### Requirements
- **Decision: No timeout fallback.** If a session goes idle with outstanding todos and never resumes (silent stall, no error), stay silent — matches "only notify if fully finished". Genuine failures still notify via `session.error`.

### Architecture
- **Decision: Gate on root session too.** Completion notifications are additionally restricted to the root session — `session.idle` for a session with a `parentID` (subagent) is suppressed. Implemented via the fail-open `isRootSession` lookup (`client.session.get` → `parentID`).
- **Decision: Per-session `Map`.** Use `todosBySession: Map<string, Todo[]>` rather than a single flat `currentTodos` variable — correct under subagents.

### Scope
- **Decision: OpenCode-only.** The Claude Code `hooks/notify.sh` generated by `opencode-to-claude.sh` is **out of scope**; this todo+root gating applies to the OpenCode plugin only.

### Conventions
- **Decision:** Place the `todo.updated` branch immediately before the `session.idle` branch in the `if/else if` chain for readability.

### Risks (pre-existing, out of scope — noted for the implementer)
- The `session.created`/`session.updated` branch reads `event.properties.title` / `event.properties.id`, but the real payload nests these under `event.properties.info` (`info.title` / `info.id`). Session titles in notifications likely fall back to the cwd basename today. Unrelated to this task.
- The plugin listens for `permission.asked`; the installed v1 SDK types expose `permission.updated`/`permission.replied` (v2 has `permission.asked`). If permission notifications ever stop working, this version mismatch is the likely cause. Out of scope here (user chose to keep permission notifications unchanged).

## References

- Todoist task (in scope): https://app.todoist.com/app/task/make-it-so-that-opencode-only-sends-notificaiton-if-fully-finished-and-nothing-more-to-do-6gvmjmR9JjgrWG2F
- OpenCode plugin events: https://opencode.ai/docs/plugins/
- Excluded sibling task ("make the opencode notifications last mac") — reported already fixed by the user: https://app.todoist.com/app/task/make-the-opencode-notifications-last-mac-6gvmx4PF5CMjRWgm
