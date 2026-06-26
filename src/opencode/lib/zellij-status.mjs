// Pure, side-effect-free helpers for the zellij-pane-status plugin.
// Lives outside plugins/ (which opencode auto-loads) so it can be unit-tested
// with `node --test` without booting opencode or a live zellij session.

export const STATES = {
  working: { emoji: "⚙", label: "working" },
  idle: { emoji: "✓", label: "idle" },
  "needs-input": { emoji: "⏸", label: "needs input" },
  error: { emoji: "✗", label: "error" },
}

// opencode event-bus type -> status key for the events that need no payload
// inspection. Streaming activity events (tool.execute.*, message.*) are
// deliberately ABSENT: opencode emits them after session.idle, and treating
// them as "working" flipped a finished pane back to ⚙ forever and it never
// recovered (the bug this module's tests guard). State is driven only by
// authoritative session-lifecycle signals, mirroring zellij-tab-status.
const EVENT_STATE = {
  // A permission prompt blocks the turn on user input. Both spellings are
  // handled: opencode's v1 bus emits permission.updated, the v2 bus (>= 1.15)
  // emits permission.asked.
  "permission.asked": "needs-input",
  "permission.updated": "needs-input",
  // Replying to a prompt resumes work.
  "permission.replied": "working",
  "session.error": "error",
  // session.idle is the turn-end signal. session.cancelled is kept as a
  // defensive alias even though the current SDK folds cancellation into idle.
  "session.idle": "idle",
  "session.cancelled": "idle",
}

export const truncateTitle = (title, max = 24) => {
  const text = String(title ?? "").trim()
  if (text.length <= max) {
    return text
  }
  return text.slice(0, max - 1).trimEnd() + "…"
}

export const computeName = (stateKey, title) => {
  const state = STATES[stateKey] || { emoji: "•", label: String(stateKey) }
  const text = truncateTitle(title)
  return text
    ? `${state.emoji} ${state.label} · ${text}`
    : `${state.emoji} ${state.label}`
}

// Map an opencode event (or a bare event-type string) to a pane status key,
// or null when the event should leave the pane unchanged. The whole event is
// accepted so session.status can be split by its busy/idle/retry sub-type.
export const eventToState = (event) => {
  const type = typeof event === "string" ? event : event?.type
  if (type === "session.status") {
    // Only "busy" starts work. "idle"/"retry" are left to session.idle (idle)
    // or ignored, so a status event never races the turn-end signal.
    return event?.properties?.status?.type === "busy" ? "working" : null
  }
  return EVENT_STATE[type] || null
}

export const extractTitle = (event) => {
  const info = event?.properties?.info || event?.properties || {}
  return info.title || ""
}
