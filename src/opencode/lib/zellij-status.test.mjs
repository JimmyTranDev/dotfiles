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
  assert.deepEqual(STATES.error, { emoji: "✗", label: "error" })
})

test("computeName renders '<emoji> <label> · <title>' for each state", () => {
  assert.equal(computeName("working", "proj"), "⚙ working · proj")
  assert.equal(computeName("idle", "proj"), "✓ idle · proj")
  assert.equal(computeName("needs-input", "proj"), "⏸ needs input · proj")
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

test("eventToState maps terminal states", () => {
  assert.equal(eventToState("permission.asked"), "needs-input")
  assert.equal(eventToState("session.error"), "error")
  assert.equal(eventToState("session.idle"), "idle")
  assert.equal(eventToState("session.cancelled"), "idle")
})

test("eventToState maps activity events to working", () => {
  assert.equal(eventToState("tool.execute.before"), "working")
  assert.equal(eventToState("tool.execute.after"), "working")
  assert.equal(eventToState("message.updated"), "working")
  assert.equal(eventToState("message.part.updated"), "working")
  assert.equal(eventToState("permission.replied"), "working")
})

test("eventToState returns null for unmapped events", () => {
  assert.equal(eventToState("session.created"), null)
  assert.equal(eventToState("file.edited"), null)
  assert.equal(eventToState("nonsense"), null)
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
