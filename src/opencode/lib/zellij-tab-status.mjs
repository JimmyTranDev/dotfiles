// Pure, side-effect-free helpers for the zellij-tab-status plugin.
// Lives outside plugins/ (which opencode auto-loads) so it can be unit-tested
// with `node --test` without booting opencode or a live zellij session.
//
// The plugin surfaces each opencode session's processing state as an emoji
// suffix on its zellij tab name. Several opencode panes can share one tab
// (e.g. the Alt-a / Alt-g grids), so a tab's badge is the aggregate of every
// live pane's status. Idle shows no badge so a quiet tab reads normally.

export const STATUS = { idle: "", processing: "🤖", done: "✅" }

// Base directory for per-pane status files: <STATE_DIR>/<tab_id>/<pid>.
export const STATE_DIR = "/tmp/opencode-zellij"

// Any trailing run of our status emoji, so a re-render replaces rather than
// stacks badges. Kept in sync with STATUS's non-empty values.
const TRAILING_BADGE = /[🤖✅]+$/u

// Collapse many panes' statuses into the single badge the tab should show.
// Priority: any processing wins, else any done, else idle. Unknown values and
// non-arrays are ignored (treated as idle).
export const aggregate = (statuses) => {
  const list = Array.isArray(statuses) ? statuses : []
  if (list.includes("processing")) {
    return "processing"
  }
  if (list.includes("done")) {
    return "done"
  }
  return "idle"
}

// Remove any trailing status badge from a tab name, leaving the base intact.
export const stripBadge = (name) => String(name ?? "").replace(TRAILING_BADGE, "")

// Replace any trailing badge on a tab name with the badge for `status`.
// idle (or an unknown status) yields no badge, clearing the name.
export const applyBadge = (name, status) => stripBadge(name) + (STATUS[status] ?? "")

// A finished turn resolves to idle when you are already looking at the tab
// (you saw it finish) or done when it finished on a tab you weren't viewing.
export const resolveTurnEnd = (focused) => (focused ? "idle" : "done")

// Map an opencode event to a state transition the plugin acts on:
//   "processing"  — the session started working
//   "turn-ended"  — the session finished (cleanly, with an error, or cancelled);
//                   error/cancelled fold in here so a crashed turn never leaves
//                   a stuck processing badge
//   null          — irrelevant event
export const eventToTransition = (event) => {
  const type = event?.type
  if (type === "session.status") {
    return event?.properties?.status?.type === "busy" ? "processing" : null
  }
  if (type === "session.idle" || type === "session.error" || type === "session.cancelled") {
    return "turn-ended"
  }
  return null
}

// Parsed `zellij action list-tabs --json` is an array of tab objects, each with
// at least { tab_id, name, position, active }.

export const findTab = (tabs, tabId) =>
  (Array.isArray(tabs) ? tabs.find((t) => t?.tab_id === tabId) : undefined) || null

export const activeTab = (tabs) =>
  (Array.isArray(tabs) ? tabs.find((t) => t?.active) : undefined) || null

export const isTabActive = (tabs, tabId) => Boolean(findTab(tabs, tabId)?.active)

// Drop status-file entries whose owning pid is gone, so a crashed or closed
// pane never leaves a stuck badge. `isAlive(pid) -> boolean` is injected so the
// real `process.kill(pid, 0)` probe can be stubbed in tests.
export const prunePids = (entries, isAlive) =>
  (Array.isArray(entries) ? entries : []).filter((entry) => isAlive(entry.pid))

// Parse raw <pid>-named status files into typed entries, dropping anything that
// isn't a positive integer pid with a known status. `files` is a list of
// { name, content }. Used by the plugin to read a tab's state directory.
export const parseStateEntries = (files) =>
  (Array.isArray(files) ? files : [])
    .map((file) => ({ pid: Number(file?.name), status: String(file?.content ?? "").trim() }))
    .filter((entry) => Number.isInteger(entry.pid) && entry.pid > 0 && entry.status in STATUS)

// The tab name a render should produce: prune dead panes, aggregate the rest,
// and apply the resulting badge to the current name. Pure given `isAlive`.
export const desiredName = (currentName, entries, isAlive) =>
  applyBadge(currentName, aggregate(prunePids(entries, isAlive).map((entry) => entry.status)))
