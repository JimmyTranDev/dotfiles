#!/usr/bin/env node
// "Arm" pane auto-close for the current opencode pane.
//
// The implement commands run this as their *final* Done step. It drops an empty
// per-pane sentinel file; the implement-auto-close plugin (same opencode process,
// same env) sees that sentinel on the next session.idle and closes the pane.
// Arming last is what keeps the mid-run spec/plan confirm gates — which also go
// idle — from closing the pane early.
//
// Invoked as `node implement-auto-close-arm.mjs`. It must never break the
// command flow, so every path exits 0; the worst case is "pane just won't
// auto-close". No-op outside zellij and unless OPENCODE_IMPLEMENT_AUTOCLOSE is
// enabled (the feature is opt-in / default-off), so no stale sentinel is ever
// left behind.

import { mkdir, writeFile } from "node:fs/promises"
import { SENTINEL_DIR, parseEnabled, sentinelPath } from "./implement-auto-close-core.mjs"

async function arm() {
  if (!process.env.ZELLIJ) {
    return "skip: not running inside zellij"
  }
  if (!parseEnabled(process.env.OPENCODE_IMPLEMENT_AUTOCLOSE)) {
    return "skip: not enabled via OPENCODE_IMPLEMENT_AUTOCLOSE"
  }
  const path = sentinelPath(process.env.ZELLIJ_PANE_ID)
  if (!path) {
    return "skip: no ZELLIJ_PANE_ID"
  }
  await mkdir(SENTINEL_DIR, { recursive: true })
  await writeFile(path, "")
  return `armed: ${path}`
}

try {
  const result = await arm()
  // A short, quiet status line — handy in the command's bash output, harmless
  // if the pane is about to close anyway.
  process.stdout.write(`implement-auto-close ${result}\n`)
} catch (error) {
  // Arming is best-effort: never fail the implement run over it.
  process.stderr.write(`implement-auto-close arm failed (ignored): ${error?.message ?? error}\n`)
}
process.exit(0)
