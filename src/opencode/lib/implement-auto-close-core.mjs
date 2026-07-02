// Pure decision and path logic for the "auto-close pane after implement" feature.
//
// The implement commands "arm" a per-pane sentinel file as their final Done step.
// A server plugin watches for session.idle and, when a pane is armed (and the
// feature is enabled and we are inside zellij), closes the pane. Mid-run approval
// gates never arm the sentinel, so they cannot trigger an early close.

export const SENTINEL_DIR = "/tmp/opencode-implement-autoclose"

// The feature is default-OFF: the pane stays open after a command finishes. Only
// these explicit opt-in values turn it on; everything else (including an unset /
// empty value) leaves it disabled. Re-enable per-session with
// OPENCODE_IMPLEMENT_AUTOCLOSE=1.
const ENABLED_VALUES = new Set(["1", "true", "on", "yes"])

export function parseEnabled(value) {
  if (value === undefined || value === null) return false
  const normalized = String(value).trim().toLowerCase()
  return ENABLED_VALUES.has(normalized)
}

export function shouldClose({ eventType, inZellij, enabled, armed } = {}) {
  return (
    eventType === "session.idle" &&
    inZellij === true &&
    enabled === true &&
    armed === true
  )
}

// Map a zellij pane id to a filesystem-safe sentinel file name. Returns "" when
// there is no usable pane id so callers can treat it as a no-op.
export function sentinelFileName(paneId) {
  if (paneId === undefined || paneId === null) return ""
  const raw = String(paneId).trim()
  if (raw === "") return ""
  return raw.replace(/[^A-Za-z0-9._-]/g, "_")
}

export function sentinelPath(paneId) {
  const name = sentinelFileName(paneId)
  if (name === "") return null
  return `${SENTINEL_DIR}/${name}`
}
