import { test } from "node:test"
import assert from "node:assert/strict"
import {
  STATES,
  truncateTitle,
  computeName,
  eventToState,
  extractTitle,
} from "./zellij-status.mjs"

test("STATES defines emoji and label for each known state", () => {
  assert.deepEqual(STATES.working, { emoji: "⚙", label: "working" })
  assert.deepEqual(STATES.idle, { emoji: "✓", label: "idle" })
  assert.deepEqual(STATES["needs-input"], { emoji: "⏸", label: "needs input" })
  assert.deepEqual(STATES.question, { emoji: "❓", label: "question" })
  assert.deepEqual(STATES.error, { emoji: "✗", label: "error" })
})

test("computeName renders '<emoji> <label> · <title>' for each state", () => {
  assert.equal(computeName("working", "proj"), "⚙ working · proj")
  assert.equal(computeName("idle", "proj"), "✓ idle · proj")
  assert.equal(computeName("needs-input", "proj"), "⏸ needs input · proj")
  assert.equal(computeName("question", "proj"), "❓ question · proj")
  assert.equal(computeName("error", "proj"), "✗ error · proj")
})

test("computeName omits the separator when the title is empty", () => {
  assert.equal(computeName("working", ""), "⚙ working")
  assert.equal(computeName("idle", "   "), "✓ idle")
})

test("computeName falls back to a neutral marker for an unknown state", () => {
  assert.equal(computeName("bogus", "proj"), "• bogus · proj")
})

test("truncateTitle leaves titles at or under the limit unchanged", () => {
  assert.equal(truncateTitle("short"), "short")
  assert.equal(truncateTitle("x".repeat(24)), "x".repeat(24))
})

test("truncateTitle clips long titles to the limit with an ellipsis", () => {
  const result = truncateTitle("x".repeat(40))
  assert.equal(result.length, 24)
  assert.equal(result, "x".repeat(23) + "…")
})

test("truncateTitle trims surrounding whitespace", () => {
  assert.equal(truncateTitle("  hello  "), "hello")
})

test("truncateTitle honours a custom max length", () => {
  assert.equal(truncateTitle("abcdef", 4), "abc…")
})

// --- eventToState: authoritative session-signal model --------------------
// State is driven only by session lifecycle signals, never by streaming
// activity events, so a finished pane can never be flipped back to working.

test("eventToState marks a busy session.status as working", () => {
  assert.equal(
    eventToState({ type: "session.status", properties: { status: { type: "busy" } } }),
    "working",
  )
})

test("eventToState ignores idle/retry session.status (session.idle drives idle)", () => {
  assert.equal(
    eventToState({ type: "session.status", properties: { status: { type: "idle" } } }),
    null,
  )
  assert.equal(
    eventToState({ type: "session.status", properties: { status: { type: "retry" } } }),
    null,
  )
  assert.equal(eventToState({ type: "session.status" }), null)
})

test("eventToState maps session.idle to idle (the finished/✓ state)", () => {
  assert.equal(eventToState({ type: "session.idle" }), "idle")
})

test("eventToState maps session.error to error", () => {
  assert.equal(eventToState({ type: "session.error" }), "error")
})

test("eventToState maps a permission request to needs-input (both event names)", () => {
  // opencode's v2 bus (>= 1.15) emits permission.asked; the pinned v1 SDK emits permission.updated.
  assert.equal(eventToState({ type: "permission.asked" }), "needs-input")
  assert.equal(eventToState({ type: "permission.updated" }), "needs-input")
})

test("eventToState returns to working once a permission is replied", () => {
  assert.equal(eventToState({ type: "permission.replied" }), "working")
})

// The question tool blocks the turn on the user just like a permission prompt:
// question.asked surfaces the ❓ "question" status; answering (replied) or
// dismissing (rejected) resumes work, after which session.idle settles it to ✓.
test("eventToState maps question.asked to question (the AI is asking the user)", () => {
  assert.equal(eventToState({ type: "question.asked" }), "question")
})

test("eventToState returns to working once a question is replied or rejected", () => {
  assert.equal(eventToState({ type: "question.replied" }), "working")
  assert.equal(eventToState({ type: "question.rejected" }), "working")
})

// Regression for the reported bug: opencode streams trailing activity events
// AFTER session.idle. These must NOT resurrect the working state.
test("eventToState ignores trailing activity events that used to stick on working", () => {
  assert.equal(eventToState({ type: "tool.execute.before" }), null)
  assert.equal(eventToState({ type: "tool.execute.after" }), null)
  assert.equal(eventToState({ type: "message.updated" }), null)
  assert.equal(eventToState({ type: "message.part.updated" }), null)
})

test("eventToState returns null for unrelated events", () => {
  assert.equal(eventToState({ type: "session.created" }), null)
  assert.equal(eventToState({ type: "session.updated" }), null)
  assert.equal(eventToState({ type: "file.edited" }), null)
  assert.equal(eventToState({ type: "nonsense" }), null)
})

test("eventToState tolerates a bare event-type string and bad input", () => {
  assert.equal(eventToState("session.idle"), "idle")
  assert.equal(eventToState("tool.execute.after"), null)
  assert.equal(eventToState(undefined), null)
  assert.equal(eventToState(null), null)
  assert.equal(eventToState({}), null)
})

// Integration of the fix: replays a full turn the way the plugin reduces it
// (apply() keeps the last NON-NULL state). A session.idle followed by a
// trailing activity flush must settle on idle, not working.
test("a turn that ends then flushes trailing activity settles on idle", () => {
  const sequence = [
    { type: "session.status", properties: { status: { type: "busy" } } },
    { type: "tool.execute.before" },
    { type: "message.part.updated" },
    { type: "tool.execute.after" },
    { type: "session.idle" },
    { type: "message.part.updated" }, // trailing flush after idle (the bug)
    { type: "tool.execute.after" },
  ]
  let state = null
  for (const event of sequence) {
    const next = eventToState(event)
    if (next) state = next
  }
  assert.equal(state, "idle")
})

// Integration: a question prompt drives the pane working -> question -> working
// -> idle. The reducer keeps the last NON-NULL state, so the ❓ shows while the
// AI waits and the turn still settles on idle once answered.
test("a question prompt drives working -> question -> working -> idle", () => {
  const sequence = [
    { type: "session.status", properties: { status: { type: "busy" } } },
    { type: "question.asked" },
    { type: "question.replied" },
    { type: "session.idle" },
  ]
  const states = []
  let state = null
  for (const event of sequence) {
    const next = eventToState(event)
    if (next) {
      state = next
      states.push(state)
    }
  }
  assert.deepEqual(states, ["working", "question", "working", "idle"])
})

test("extractTitle reads the nested session info title", () => {
  assert.equal(extractTitle({ properties: { info: { title: "Build feature" } } }), "Build feature")
})

test("extractTitle falls back to a flat properties title", () => {
  assert.equal(extractTitle({ properties: { title: "Flat title" } }), "Flat title")
})

test("extractTitle returns an empty string when no title is present", () => {
  assert.equal(extractTitle({}), "")
  assert.equal(extractTitle(undefined), "")
  assert.equal(extractTitle({ properties: { info: {} } }), "")
})
