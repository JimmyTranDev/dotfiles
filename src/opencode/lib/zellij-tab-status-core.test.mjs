import { test } from "node:test"
import assert from "node:assert/strict"
import { createTabStatus } from "./zellij-tab-status-core.mjs"

// In-memory fake `io` modelling one tab's shared state dir, the zellij tab
// list, pid liveness, and a manually-tickable focus poll.
const makeIo = ({ pid = 100, tabId = 10, name = "3.dotf" } = {}) => {
  const entries = new Map() // pid -> status (the tab's state directory)
  const aliveSet = new Set([pid])
  let tabs = [{ tab_id: tabId, name, position: 0, active: true }]
  let pollFn = null
  const calls = { renames: [], finalized: false }

  const io = {
    pid,
    pollMs: 250,
    isAlive: (p) => aliveSet.has(p),
    readEntries: () => [...entries].map(([p, status]) => ({ pid: p, status })),
    writeStatus: (_id, status) => entries.set(pid, status),
    finalize: (_id) => {
      entries.delete(pid)
      calls.finalized = true
    },
    listTabs: async () => tabs,
    renameTab: async (id, newName) => {
      calls.renames.push(newName)
      const me = tabs.find((t) => t.tab_id === id)
      if (me) me.name = newName
    },
    withLock: async (_id, fn) => fn(),
    startPoll: (fn) => {
      pollFn = fn
      return 1
    },
    stopPoll: () => {
      pollFn = null
    },
    onExit: (fn) => {
      io._exit = fn
    },

    // test controls
    _entries: entries,
    _aliveSet: aliveSet,
    _calls: calls,
    _setActive: (id) => tabs.forEach((t) => (t.active = t.tab_id === id)),
    _setTabs: (t) => (tabs = t),
    _tick: async () => pollFn && pollFn(),
    _hasPoll: () => pollFn !== null,
    _exitNow: () => io._exit && io._exit(),
  }
  return io
}

test("chat.message marks the tab processing (⚙)", async () => {
  const io = makeIo()
  const hooks = createTabStatus(io)
  await hooks["chat.message"]()
  assert.deepEqual(io._calls.renames, ["3.dotf⚙"])
  assert.equal(io._entries.get(100), "processing")
})

test("a busy session.status event also marks processing", async () => {
  const io = makeIo()
  const hooks = createTabStatus(io)
  await hooks.event({ event: { type: "session.status", properties: { status: { type: "busy" } } } })
  assert.deepEqual(io._calls.renames, ["3.dotf⚙"])
})

test("finishing while focused clears straight to idle (no ✓, no poll)", async () => {
  const io = makeIo()
  const hooks = createTabStatus(io)
  await hooks["chat.message"]()
  io._calls.renames.length = 0
  await hooks.event({ event: { type: "session.idle" } })
  assert.deepEqual(io._calls.renames, ["3.dotf"])
  assert.equal(io._entries.get(100), "idle")
  assert.equal(io._hasPoll(), false)
})

test("finishing while on another tab shows ✓ and arms the focus poll", async () => {
  const io = makeIo()
  const hooks = createTabStatus(io)
  await hooks["chat.message"]() // caches tab id while focused
  io._setActive(999) // user switched away
  io._calls.renames.length = 0
  await hooks.event({ event: { type: "session.idle" } })
  assert.deepEqual(io._calls.renames, ["3.dotf✓"])
  assert.equal(io._hasPoll(), true)
})

test("a poll tick while still unfocused does nothing and keeps polling", async () => {
  const io = makeIo()
  const hooks = createTabStatus(io)
  await hooks["chat.message"]()
  io._setActive(999)
  await hooks.event({ event: { type: "session.idle" } })
  io._calls.renames.length = 0
  await io._tick()
  assert.deepEqual(io._calls.renames, [])
  assert.equal(io._hasPoll(), true)
})

test("switching to a ✓ tab clears it to idle and stops the poll", async () => {
  const io = makeIo()
  const hooks = createTabStatus(io)
  await hooks["chat.message"]()
  io._setActive(999)
  await hooks.event({ event: { type: "session.idle" } })
  io._calls.renames.length = 0
  io._setActive(10) // user returns to our tab
  await io._tick()
  assert.deepEqual(io._calls.renames, ["3.dotf"])
  assert.equal(io._entries.get(100), "idle")
  assert.equal(io._hasPoll(), false)
})

test("starting a new turn after done flips ✓ back to ⚙ and stops the poll", async () => {
  const io = makeIo()
  const hooks = createTabStatus(io)
  await hooks["chat.message"]()
  io._setActive(999)
  await hooks.event({ event: { type: "session.idle" } }) // done, polling
  io._setActive(10)
  io._calls.renames.length = 0
  await hooks["chat.message"]() // new prompt
  assert.deepEqual(io._calls.renames, ["3.dotf⚙"])
  assert.equal(io._hasPoll(), false)
})

test("grid: a tab stays ⚙ while any other pane is still processing", async () => {
  const io = makeIo()
  io._entries.set(200, "processing") // a sibling pane is busy
  io._aliveSet.add(200)
  const hooks = createTabStatus(io)
  await hooks["chat.message"]() // tab -> ⚙
  io._calls.renames.length = 0
  await hooks.event({ event: { type: "session.idle" } }) // our pane done, focused
  // aggregate(processing + idle) = processing -> name already ⚙ -> no rename
  assert.deepEqual(io._calls.renames, [])
  assert.equal(io._entries.get(100), "idle")
})

test("self-heal: a crashed pane's stale 'done' is pruned by pid", async () => {
  const io = makeIo()
  io._entries.set(900, "done") // crashed pane left a stuck badge; pid 900 is dead
  const hooks = createTabStatus(io)
  await hooks["chat.message"]() // processing (dead done pruned)
  io._calls.renames.length = 0
  await hooks.event({ event: { type: "session.idle" } }) // focused -> idle, 900 pruned
  assert.deepEqual(io._calls.renames, ["3.dotf"])
})

test("exit cleanup finalizes our state file and stops the poll", async () => {
  const io = makeIo()
  const hooks = createTabStatus(io)
  await hooks["chat.message"]()
  io._setActive(999)
  await hooks.event({ event: { type: "session.idle" } })
  assert.equal(io._hasPoll(), true)
  io._exitNow()
  assert.equal(io._calls.finalized, true)
  assert.equal(io._hasPoll(), false)
})

test("a finish before any processing (no tab cached) is a no-op", async () => {
  const io = makeIo()
  const hooks = createTabStatus(io)
  await hooks.event({ event: { type: "session.idle" } })
  assert.deepEqual(io._calls.renames, [])
})

test("irrelevant events never touch the tab", async () => {
  const io = makeIo()
  const hooks = createTabStatus(io)
  await hooks.event({ event: { type: "tool.execute.after" } })
  await hooks.event({ event: { type: "session.created" } })
  assert.deepEqual(io._calls.renames, [])
})

test("when zellij is unreachable, no tab id is cached and nothing renders", async () => {
  const io = makeIo()
  io._setTabs(null)
  const hooks = createTabStatus(io)
  await hooks["chat.message"]()
  assert.deepEqual(io._calls.renames, [])
  assert.equal(io._entries.size, 0)
})
