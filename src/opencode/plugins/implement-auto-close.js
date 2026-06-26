import { access, rm } from "node:fs/promises"
import { parseEnabled, sentinelPath, shouldClose } from "../lib/implement-auto-close-core.mjs"

// Close this opencode pane once it goes idle — but only when an implement command
// has "armed" it by dropping a per-pane sentinel file as its final step. Mid-run
// spec/plan confirm gates also emit session.idle, but no sentinel exists yet then,
// so they never trigger a close. No-op outside zellij.
//
// Pairs with lib/implement-auto-close-arm.mjs (writes the sentinel) and the pure,
// unit-tested lib/implement-auto-close-core.mjs (path + decision logic).
export const ImplementAutoClose = async ({ $ }) => {
  const paneId = process.env.ZELLIJ_PANE_ID
  if (!process.env.ZELLIJ || !paneId) {
    return {}
  }

  const path = sentinelPath(paneId)
  if (!path) {
    return {}
  }

  // Env is fixed for this process; the arm script (a child of the same process)
  // sees the identical value, so the two stay in agreement.
  const enabled = parseEnabled(process.env.OPENCODE_IMPLEMENT_AUTOCLOSE)

  const isArmed = () =>
    access(path).then(
      () => true,
      () => false,
    )

  return {
    event: async ({ event }) => {
      if (event?.type !== "session.idle") {
        return
      }

      const armed = await isArmed()
      if (!armed) {
        return
      }

      // Always clear our own sentinel once a turn ends armed, so a disabled pane
      // gets disarmed and an enabled one never double-fires.
      try {
        await rm(path, { force: true })
      } catch {
        // best-effort cleanup — ignore.
      }

      if (!shouldClose({ eventType: event.type, inZellij: true, enabled, armed })) {
        return
      }

      // Target this pane by id (not the focused pane) so a refocus elsewhere can
      // never close the wrong pane. .nothrow() + try/catch: closing must never
      // surface an error.
      try {
        await $`zellij action close-pane --pane-id ${paneId}`.nothrow()
      } catch {
        // zellij unreachable (e.g. detached session) — ignore.
      }
    },
  }
}
