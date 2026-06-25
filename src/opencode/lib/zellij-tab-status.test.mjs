import { test } from "node:test"
import assert from "node:assert/strict"
import {
  STATUS,
  STATE_DIR,
  aggregate,
  stripBadge,
  applyBadge,
  resolveTurnEnd,
  eventToTransition,
  activeTab,
  findTab,
  isTabActive,
  prunePids,
  parseStateEntries,
  desiredName,
} from "./zellij-tab-status.mjs"

test("STATUS maps the three tab states to their badge (idle is empty)", () => {
  assert.equal(STATUS.idle, "")
  assert.equal(STATUS.processing, "🤖")
  assert.equal(STATUS.done, "✅")
})

test("STATE_DIR is the shared /tmp base directory", () => {
  assert.equal(STATE_DIR, "/tmp/opencode-zellij")
})

test("aggregate prioritises processing over done over idle", () => {
  assert.equal(aggregate(["processing", "idle", "done"]), "processing")
  assert.equal(aggregate(["idle", "done"]), "done")
  assert.equal(aggregate(["idle", "idle"]), "idle")
  assert.equal(aggregate(["done"]), "done")
  assert.equal(aggregate(["processing"]), "processing")
})

test("aggregate treats an empty or unknown set as idle", () => {
  assert.equal(aggregate([]), "idle")
  assert.equal(aggregate(["idle", "bogus"]), "idle")
  assert.equal(aggregate(undefined), "idle")
})

test("aggregate ignores unknown values but still finds real states", () => {
  assert.equal(aggregate(["bogus", "done"]), "done")
  assert.equal(aggregate(["bogus", "processing"]), "processing")
})

test("stripBadge removes a single trailing status emoji", () => {
  assert.equal(stripBadge("3.dotf🤖"), "3.dotf")
  assert.equal(stripBadge("3.dotf✅"), "3.dotf")
})

test("stripBadge removes multiple/mixed trailing emoji", () => {
  assert.equal(stripBadge("3.dotf🤖🤖"), "3.dotf")
  assert.equal(stripBadge("3.dotf✅🤖"), "3.dotf")
})

test("stripBadge leaves a clean name and non-trailing emoji untouched", () => {
  assert.equal(stripBadge("3.dotf"), "3.dotf")
  assert.equal(stripBadge("3.🤖dotf"), "3.🤖dotf")
})

test("stripBadge coerces nullish input to an empty string", () => {
  assert.equal(stripBadge(""), "")
  assert.equal(stripBadge(null), "")
  assert.equal(stripBadge(undefined), "")
  assert.equal(stripBadge("🤖"), "")
})

test("applyBadge appends the badge for a status", () => {
  assert.equal(applyBadge("3.dotf", "processing"), "3.dotf🤖")
  assert.equal(applyBadge("3.dotf", "done"), "3.dotf✅")
})

test("applyBadge for idle clears any existing badge", () => {
  assert.equal(applyBadge("3.dotf", "idle"), "3.dotf")
  assert.equal(applyBadge("3.dotf✅", "idle"), "3.dotf")
  assert.equal(applyBadge("3.dotf🤖", "idle"), "3.dotf")
})

test("applyBadge replaces an existing badge rather than stacking", () => {
  assert.equal(applyBadge("3.dotf🤖", "done"), "3.dotf✅")
  assert.equal(applyBadge("3.dotf✅", "processing"), "3.dotf🤖")
})

test("applyBadge treats an unknown status as no badge", () => {
  assert.equal(applyBadge("3.dotf🤖", "bogus"), "3.dotf")
})

test("resolveTurnEnd: focused -> idle, unfocused -> done", () => {
  assert.equal(resolveTurnEnd(true), "idle")
  assert.equal(resolveTurnEnd(false), "done")
})

test("eventToTransition maps a busy session.status to processing", () => {
  assert.equal(
    eventToTransition({ type: "session.status", properties: { status: { type: "busy" } } }),
    "processing",
  )
})

test("eventToTransition ignores a non-busy session.status", () => {
  assert.equal(
    eventToTransition({ type: "session.status", properties: { status: { type: "idle" } } }),
    null,
  )
  assert.equal(eventToTransition({ type: "session.status" }), null)
})

test("eventToTransition maps idle/error/cancelled to turn-ended", () => {
  assert.equal(eventToTransition({ type: "session.idle" }), "turn-ended")
  assert.equal(eventToTransition({ type: "session.error" }), "turn-ended")
  assert.equal(eventToTransition({ type: "session.cancelled" }), "turn-ended")
})

test("eventToTransition returns null for irrelevant or malformed events", () => {
  assert.equal(eventToTransition({ type: "session.created" }), null)
  assert.equal(eventToTransition({ type: "tool.execute.after" }), null)
  assert.equal(eventToTransition({}), null)
  assert.equal(eventToTransition(undefined), null)
})

test("activeTab returns the focused tab or null", () => {
  assert.deepEqual(
    activeTab([{ tab_id: 1, active: false }, { tab_id: 2, active: true }]),
    { tab_id: 2, active: true },
  )
  assert.equal(activeTab([{ tab_id: 1, active: false }]), null)
  assert.equal(activeTab([]), null)
  assert.equal(activeTab(undefined), null)
})

test("findTab locates a tab by its stable id", () => {
  const tabs = [{ tab_id: 7, active: false }, { tab_id: 9, active: true }]
  assert.deepEqual(findTab(tabs, 9), { tab_id: 9, active: true })
  assert.equal(findTab(tabs, 42), null)
  assert.equal(findTab(undefined, 9), null)
})

test("isTabActive reports focus for a given tab id", () => {
  const tabs = [{ tab_id: 7, active: false }, { tab_id: 9, active: true }]
  assert.equal(isTabActive(tabs, 9), true)
  assert.equal(isTabActive(tabs, 7), false)
  assert.equal(isTabActive(tabs, 42), false)
})

test("prunePids keeps only entries whose pid is alive", () => {
  const entries = [
    { pid: 1, status: "done" },
    { pid: 2, status: "idle" },
    { pid: 3, status: "processing" },
  ]
  const isAlive = (pid) => pid !== 2
  assert.deepEqual(prunePids(entries, isAlive), [
    { pid: 1, status: "done" },
    { pid: 3, status: "processing" },
  ])
})

test("prunePids handles empty and non-array input", () => {
  assert.deepEqual(prunePids([], () => true), [])
  assert.deepEqual(prunePids(undefined, () => true), [])
})

test("parseStateEntries maps <pid>-named files to typed entries", () => {
  assert.deepEqual(
    parseStateEntries([
      { name: "123", content: "processing" },
      { name: "456", content: "done\n" },
    ]),
    [
      { pid: 123, status: "processing" },
      { pid: 456, status: "done" },
    ],
  )
})

test("parseStateEntries drops invalid pids and unknown statuses", () => {
  assert.deepEqual(
    parseStateEntries([
      { name: "abc", content: "processing" },
      { name: "0", content: "done" },
      { name: "-5", content: "idle" },
      { name: "789", content: "garbage" },
      { name: "12", content: "idle" },
    ]),
    [{ pid: 12, status: "idle" }],
  )
})

test("parseStateEntries handles empty / non-array input", () => {
  assert.deepEqual(parseStateEntries([]), [])
  assert.deepEqual(parseStateEntries(undefined), [])
})

test("desiredName badges the current name from live pane statuses", () => {
  assert.equal(desiredName("3.dotf", [{ pid: 1, status: "processing" }], () => true), "3.dotf🤖")
  assert.equal(
    desiredName("3.dotf", [{ pid: 1, status: "done" }, { pid: 2, status: "idle" }], () => true),
    "3.dotf✅",
  )
})

test("desiredName clears the badge when every live pane is idle", () => {
  assert.equal(desiredName("3.dotf🤖", [{ pid: 1, status: "idle" }], () => true), "3.dotf")
})

test("desiredName prunes dead panes before aggregating", () => {
  // The only entry is a dead 'done' pane -> pruned -> idle -> no badge.
  assert.equal(desiredName("3.dotf✅", [{ pid: 1, status: "done" }], () => false), "3.dotf")
})

test("desiredName replaces an existing badge with the live aggregate", () => {
  assert.equal(
    desiredName(
      "3.dotf✅",
      [{ pid: 1, status: "processing" }, { pid: 2, status: "done" }],
      () => true,
    ),
    "3.dotf🤖",
  )
})
