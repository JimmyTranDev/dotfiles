import { test } from "node:test"
import assert from "node:assert/strict"
import {
  SENTINEL_DIR,
  parseEnabled,
  shouldClose,
  sentinelFileName,
  sentinelPath,
} from "./implement-auto-close-core.mjs"

test("SENTINEL_DIR is the dedicated /tmp directory", () => {
  assert.equal(SENTINEL_DIR, "/tmp/opencode-implement-autoclose")
})

test("parseEnabled defaults to false when unset or empty", () => {
  assert.equal(parseEnabled(undefined), false)
  assert.equal(parseEnabled(null), false)
  assert.equal(parseEnabled(""), false)
  assert.equal(parseEnabled("   "), false)
})

test("parseEnabled enables only for explicit opt-in values", () => {
  assert.equal(parseEnabled("1"), true)
  assert.equal(parseEnabled("true"), true)
  assert.equal(parseEnabled("yes"), true)
  assert.equal(parseEnabled("on"), true)
})

test("parseEnabled stays disabled for 0/false/off/no and any other value, case- and space-insensitive", () => {
  assert.equal(parseEnabled("0"), false)
  assert.equal(parseEnabled("false"), false)
  assert.equal(parseEnabled("off"), false)
  assert.equal(parseEnabled("no"), false)
  assert.equal(parseEnabled("anything-else"), false)
  assert.equal(parseEnabled("TRUE"), true)
  assert.equal(parseEnabled(" On "), true)
})

test("shouldClose is true only when idle, in zellij, enabled, and armed", () => {
  assert.equal(
    shouldClose({ eventType: "session.idle", inZellij: true, enabled: true, armed: true }),
    true,
  )
})

test("shouldClose is false when any precondition is missing", () => {
  assert.equal(
    shouldClose({ eventType: "session.error", inZellij: true, enabled: true, armed: true }),
    false,
  )
  assert.equal(
    shouldClose({ eventType: "session.idle", inZellij: false, enabled: true, armed: true }),
    false,
  )
  assert.equal(
    shouldClose({ eventType: "session.idle", inZellij: true, enabled: false, armed: true }),
    false,
  )
  assert.equal(
    shouldClose({ eventType: "session.idle", inZellij: true, enabled: true, armed: false }),
    false,
  )
})

test("shouldClose does not throw when called with no argument", () => {
  assert.equal(shouldClose(), false)
})

test("sentinelFileName returns the id unchanged when already safe", () => {
  assert.equal(sentinelFileName("1"), "1")
  assert.equal(sentinelFileName("terminal_12"), "terminal_12")
  assert.equal(sentinelFileName("pane-3.4"), "pane-3.4")
})

test("sentinelFileName sanitizes unsafe characters to underscores", () => {
  assert.equal(sentinelFileName("a/b c:d"), "a_b_c_d")
  assert.equal(sentinelFileName("../escape"), ".._escape")
})

test("sentinelFileName returns empty string for missing/blank ids", () => {
  assert.equal(sentinelFileName(undefined), "")
  assert.equal(sentinelFileName(null), "")
  assert.equal(sentinelFileName(""), "")
  assert.equal(sentinelFileName("   "), "")
})

test("sentinelPath joins the dir and sanitized name", () => {
  assert.equal(sentinelPath("12"), "/tmp/opencode-implement-autoclose/12")
  assert.equal(sentinelPath("a/b"), "/tmp/opencode-implement-autoclose/a_b")
})

test("sentinelPath returns null when there is no pane id", () => {
  assert.equal(sentinelPath(undefined), null)
  assert.equal(sentinelPath(""), null)
})
