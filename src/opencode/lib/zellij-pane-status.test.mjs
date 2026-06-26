import { test } from "node:test"
import assert from "node:assert/strict"

// End-to-end checks of the real pane-status plugin (plugins/zellij-pane-status.js),
// not just the pure helpers. A fake Bun-style `$` shell records the names the
// plugin would hand to `zellij action rename-pane`, so we can assert the pane
// settles on the right glyph through a realistic opencode event stream —
// including the trailing post-idle flush that used to leave it stuck on ⚙.

const importPlugin = () => import("../plugins/zellij-pane-status.js")

// Build a fake `$` tag that captures the pane name from each rename-pane call.
const makeShell = () => {
  const renames = []
  const $ = (strings, ...values) => {
    if (strings.join(" ").includes("rename-pane")) {
      renames.push(values[values.length - 1])
    }
    return Promise.resolve({ exitCode: 0 })
  }
  return { $, renames }
}

const startPlugin = async ({ paneId = "7" } = {}) => {
  process.env.ZELLIJ = "1"
  process.env.ZELLIJ_PANE_ID = paneId
  const { $, renames } = makeShell()
  const { ZellijPaneStatus } = await importPlugin()
  const hooks = await ZellijPaneStatus({ $ })
  return { hooks, renames }
}

test("plugin: a finished turn settles on '✓ idle' despite a post-idle activity flush", async () => {
  const { hooks, renames } = await startPlugin()

  await hooks.event({ event: { type: "session.created", properties: { info: { title: "fix bug" } } } })
  await hooks["chat.message"]() // user submits -> working
  await hooks.event({ event: { type: "session.status", properties: { status: { type: "busy" } } } })
  await hooks.event({ event: { type: "tool.execute.before" } })
  await hooks.event({ event: { type: "message.part.updated" } })
  await hooks.event({ event: { type: "tool.execute.after" } })
  await hooks.event({ event: { type: "session.idle" } }) // turn ends -> idle
  // opencode flushes trailing parts AFTER idle: this is the reported bug.
  await hooks.event({ event: { type: "message.part.updated" } })
  await hooks.event({ event: { type: "tool.execute.after" } })

  const last = renames[renames.length - 1]
  assert.equal(last, "✓ idle · fix bug")
  assert.ok(!last.startsWith("⚙"), "pane must not be stuck on working after the turn ends")
  assert.deepEqual(renames, ["⚙ working · fix bug", "✓ idle · fix bug"])
})

test("plugin: a permission prompt shows ⏸, resumes to ⚙, then ends on ✓", async () => {
  const { hooks, renames } = await startPlugin()

  await hooks.event({ event: { type: "session.created", properties: { info: { title: "deploy" } } } })
  await hooks["chat.message"]()
  await hooks.event({ event: { type: "permission.asked" } })
  await hooks.event({ event: { type: "permission.replied" } })
  await hooks.event({ event: { type: "session.idle" } })

  assert.deepEqual(renames, [
    "⚙ working · deploy",
    "⏸ needs input · deploy",
    "⚙ working · deploy",
    "✓ idle · deploy",
  ])
})

test("plugin: a busy session.status alone (no chat.message) still shows ⚙", async () => {
  const { hooks, renames } = await startPlugin()
  await hooks.event({ event: { type: "session.updated", properties: { info: { title: "auto" } } } })
  await hooks.event({ event: { type: "session.status", properties: { status: { type: "busy" } } } })
  await hooks.event({ event: { type: "session.idle" } })
  assert.deepEqual(renames, ["⚙ working · auto", "✓ idle · auto"])
})

test("plugin: an errored turn ends on ✗ error", async () => {
  const { hooks, renames } = await startPlugin()
  await hooks.event({ event: { type: "session.created", properties: { info: { title: "build" } } } })
  await hooks["chat.message"]()
  await hooks.event({ event: { type: "session.error" } })
  assert.equal(renames[renames.length - 1], "✗ error · build")
})

test("plugin: no-op outside zellij (ZELLIJ unset)", async () => {
  delete process.env.ZELLIJ
  delete process.env.ZELLIJ_PANE_ID
  const { ZellijPaneStatus } = await importPlugin()
  const hooks = await ZellijPaneStatus({ $: () => Promise.resolve({}) })
  assert.deepEqual(hooks, {})
})
