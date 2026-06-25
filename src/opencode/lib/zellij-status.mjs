// Pure, side-effect-free helpers for the zellij-pane-status plugin.
// Lives outside plugins/ (which opencode auto-loads) so it can be unit-tested
// with `node --test` without booting opencode or a live zellij session.

export const STATES = {
  working: { emoji: "⚙", label: "working" },
  idle: { emoji: "✓", label: "idle" },
  "needs-input": { emoji: "⏸", label: "needs input" },
  error: { emoji: "✗", label: "error" },
}

// opencode event-bus type -> status key (null when the event is irrelevant).
const EVENT_STATE = {
  "permission.asked": "needs-input",
  "permission.replied": "working",
  "session.error": "error",
  "session.idle": "idle",
  "session.cancelled": "idle",
  "tool.execute.before": "working",
  "tool.execute.after": "working",
  "message.updated": "working",
  "message.part.updated": "working",
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

export const eventToState = (eventType) => EVENT_STATE[eventType] || null

export const extractTitle = (event) => {
  const info = event?.properties?.info || event?.properties || {}
  return info.title || ""
}
