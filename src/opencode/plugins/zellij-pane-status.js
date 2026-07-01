import { computeName, eventToState, extractTitle } from "../lib/zellij-status.mjs"

// Reflect opencode's live status in the title of the zellij pane it runs in by
// shelling out to `zellij action rename-pane --pane-id <id>`. Each opencode
// process renames only its own pane (via $ZELLIJ_PANE_ID), so this stays correct
// even in layouts with several opencode panes. No-op when not running in zellij.
export const ZellijPaneStatus = async ({ $ }) => {
  const paneId = process.env.ZELLIJ_PANE_ID
  if (!process.env.ZELLIJ || !paneId) {
    return {}
  }

  let title = ""
  let currentState = null
  let lastName = ""

  const cwdBase = () => {
    try {
      return process.cwd().split("/").filter(Boolean).pop() || ""
    } catch {
      return ""
    }
  }

  // Compute the desired pane name and only call zellij when it actually changed
  // (status events stream rapidly; renaming on every one would be wasteful).
  const render = async (stateKey) => {
    if (!stateKey) {
      return
    }
    const name = computeName(stateKey, title || cwdBase())
    if (name === lastName) {
      return
    }
    lastName = name
    try {
      await $`zellij action rename-pane --pane-id ${paneId} ${name}`
    } catch {
      // zellij unreachable (e.g. detached session) — ignore.
    }
  }

  const apply = async (stateKey) => {
    if (!stateKey) {
      return
    }
    currentState = stateKey
    await render(stateKey)
  }

  return {
    // Flip to "working" the instant a prompt is submitted, before the first token.
    "chat.message": async () => {
      await apply("working")
    },
    event: async ({ event }) => {
      const type = event?.type
      if (type === "session.created" || type === "session.updated") {
        const next = extractTitle(event)
        if (next && next !== title) {
          title = next
          await render(currentState)
        }
        return
      }
      await apply(eventToState(event))
    },
  }
}
