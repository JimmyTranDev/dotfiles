import { computeName, eventToState } from "../lib/zellij-status.mjs"

// Reflect opencode's live status in the title of the zellij pane it runs in by
// shelling out to `zellij action rename-pane --pane-id <id>`. Each opencode
// process renames only its own pane (via $ZELLIJ_PANE_ID), so this stays correct
// even in layouts with several opencode panes. No-op when not running in zellij.
export const ZellijPaneStatus = async ({ $ }) => {
  const paneId = process.env.ZELLIJ_PANE_ID
  if (!process.env.ZELLIJ || !paneId) {
    return {}
  }

  let lastName = ""

  // Basename of the current working directory — the text half of the pane name.
  // The session title is deliberately ignored: a pane should show WHERE you are
  // (the dir), not what the AI named the chat, so panes stay scannable at a glance.
  const cwdBase = () => {
    try {
      return process.cwd().split("/").filter(Boolean).pop() || ""
    } catch {
      return ""
    }
  }

  // Compute the desired pane name and only call zellij when it actually changed
  // (status events stream rapidly; renaming on every one would be wasteful).
  // The name is a function of state + cwd only, so dedup collapses to the
  // status transitions that matter.
  const render = async (stateKey) => {
    if (!stateKey) {
      return
    }
    const name = computeName(stateKey, cwdBase())
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

  return {
    // Flip to "working" the instant a prompt is submitted, before the first token.
    "chat.message": async () => {
      await render("working")
    },
    // Drive state purely from authoritative lifecycle signals; eventToState
    // returns null for everything else (incl. session.created/updated, whose
    // title we no longer read), and render(null) is a no-op.
    event: async ({ event }) => {
      await render(eventToState(event))
    },
  }
}
