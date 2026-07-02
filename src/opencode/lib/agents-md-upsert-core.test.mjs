import { test } from "node:test"
import assert from "node:assert/strict"
import {
  MANAGED_START,
  MANAGED_END,
  wrapManaged,
  hasManagedBlock,
  upsertAgentsMd,
  defaultManagedInner,
} from "./agents-md-upsert-core.mjs"

test("sentinels are the documented opencode:managed comments", () => {
  assert.equal(MANAGED_START, "<!-- opencode:managed:start -->")
  assert.equal(MANAGED_END, "<!-- opencode:managed:end -->")
})

test("wrapManaged surrounds trimmed body with the sentinels", () => {
  const out = wrapManaged("hello")
  assert.equal(out, `${MANAGED_START}\n\nhello\n\n${MANAGED_END}`)
})

test("wrapManaged normalizes incidental whitespace so it is stable", () => {
  assert.equal(wrapManaged("  hello  "), wrapManaged("hello"))
  assert.equal(wrapManaged("\n\nhello\n\n"), wrapManaged("hello"))
})

test("hasManagedBlock detects a well-formed block and rejects partial/absent", () => {
  assert.equal(hasManagedBlock(wrapManaged("x")), true)
  assert.equal(hasManagedBlock("no sentinels here"), false)
  assert.equal(hasManagedBlock(MANAGED_START + "\nonly start"), false)
  assert.equal(hasManagedBlock(""), false)
  assert.equal(hasManagedBlock(null), false)
})

// --- upsert: create (absent / blank) ---

test("upsert on absent file makes the wrapped block the whole file", () => {
  const out = upsertAgentsMd(null, "starter body")
  assert.equal(out, `${wrapManaged("starter body")}\n`)
  assert.equal(hasManagedBlock(out), true)
})

test("upsert on empty/whitespace file also creates the block", () => {
  assert.equal(upsertAgentsMd("", "b"), `${wrapManaged("b")}\n`)
  assert.equal(upsertAgentsMd("   \n\t\n", "b"), `${wrapManaged("b")}\n`)
})

// --- upsert: replace (sentinels present) ---

test("upsert replaces only the managed block and preserves surrounding prose", () => {
  const existing = [
    "# My Project",
    "",
    "Hand-written intro that must survive.",
    "",
    wrapManaged("OLD managed content"),
    "",
    "## Footer",
    "More user prose after the block.",
    "",
  ].join("\n")

  const out = upsertAgentsMd(existing, "NEW managed content")

  // The new managed body is present, the old one is gone.
  assert.ok(out.includes("NEW managed content"))
  assert.ok(!out.includes("OLD managed content"))
  // Surrounding user prose (before AND after) is preserved verbatim.
  assert.ok(out.includes("# My Project"))
  assert.ok(out.includes("Hand-written intro that must survive."))
  assert.ok(out.includes("## Footer"))
  assert.ok(out.includes("More user prose after the block."))
  // Exactly one managed block remains.
  assert.equal(out.split(MANAGED_START).length - 1, 1)
  assert.equal(out.split(MANAGED_END).length - 1, 1)
})

test("upsert replace keeps the exact prefix and suffix bytes", () => {
  const prefix = "PREFIX-BYTES\n\n"
  const suffix = "\n\nSUFFIX-BYTES"
  const existing = `${prefix}${wrapManaged("old")}${suffix}`
  const out = upsertAgentsMd(existing, "new")
  assert.equal(out, `${prefix}${wrapManaged("new")}${suffix}`)
})

// --- upsert: append (no sentinels) ---

test("upsert appends a managed block to a file that has none", () => {
  const existing = "# Existing\n\nSome prose with no managed block."
  const out = upsertAgentsMd(existing, "appended body")
  assert.ok(out.startsWith("# Existing\n\nSome prose with no managed block."))
  assert.ok(hasManagedBlock(out))
  // Appended after exactly one blank line, single trailing newline.
  assert.equal(out, `# Existing\n\nSome prose with no managed block.\n\n${wrapManaged("appended body")}\n`)
})

test("upsert append trims trailing whitespace before the blank-line separator", () => {
  const existing = "content\n\n\n   \n"
  const out = upsertAgentsMd(existing, "x")
  assert.equal(out, `content\n\n${wrapManaged("x")}\n`)
})

test("upsert treats a start sentinel with no end as unmanaged and appends fresh", () => {
  const existing = `intro\n\n${MANAGED_START}\ndangling with no end`
  const out = upsertAgentsMd(existing, "recovered")
  // Original (malformed) text is preserved, and a well-formed block is appended.
  assert.ok(out.includes("dangling with no end"))
  assert.ok(hasManagedBlock(out))
  assert.ok(out.trimEnd().endsWith(MANAGED_END))
})

// --- idempotency ---

test("upsert is idempotent for the create case", () => {
  const once = upsertAgentsMd(null, "body")
  const twice = upsertAgentsMd(once, "body")
  assert.equal(twice, once)
})

test("upsert is idempotent for the replace case", () => {
  const base = upsertAgentsMd("# Head\n\nprose", "body")
  const again = upsertAgentsMd(base, "body")
  assert.equal(again, base)
  // And a third time, to be sure it converged.
  assert.equal(upsertAgentsMd(again, "body"), base)
})

// --- defaultManagedInner ---

test("defaultManagedInner includes the project name and boundaries", () => {
  const inner = defaultManagedInner({ name: "acme-api" })
  assert.ok(inner.includes("# AGENTS.md — acme-api"))
  assert.ok(inner.includes("## Boundaries"))
  assert.ok(inner.includes("Always:"))
  assert.ok(inner.includes("Never:"))
})

test("defaultManagedInner renders a commands table only for detected hints", () => {
  const withCmds = defaultManagedInner({ name: "x", build: "npm run build", test: "npm test" })
  assert.ok(withCmds.includes("## Commands"))
  assert.ok(withCmds.includes("`npm run build`"))
  assert.ok(withCmds.includes("`npm test`"))

  const noCmds = defaultManagedInner({ name: "x" })
  assert.ok(!noCmds.includes("## Commands"))
})

test("defaultManagedInner falls back to a generic name and survives no args", () => {
  const inner = defaultManagedInner()
  assert.ok(inner.includes("# AGENTS.md — this project"))
})

test("defaultManagedInner output round-trips cleanly through the upsert (idempotent)", () => {
  const inner = defaultManagedInner({ name: "roundtrip", test: "npm test" })
  const once = upsertAgentsMd(null, inner)
  const twice = upsertAgentsMd(once, inner)
  assert.equal(twice, once)
})

// --- USER_NOTES_STUB / includeNotesStub (create-time unmanaged notes area) ---

import { USER_NOTES_STUB } from "./agents-md-upsert-core.mjs"

test("USER_NOTES_STUB is an unmanaged section (outside the sentinels)", () => {
  assert.ok(USER_NOTES_STUB.includes("## Project notes"))
  assert.ok(!USER_NOTES_STUB.includes(MANAGED_START))
  assert.ok(!USER_NOTES_STUB.includes(MANAGED_END))
})

test("create with includeNotesStub appends the notes stub after the managed block", () => {
  const out = upsertAgentsMd(null, "body", { includeNotesStub: true })
  assert.ok(hasManagedBlock(out))
  assert.ok(out.includes(USER_NOTES_STUB))
  // The notes stub comes AFTER the managed end sentinel.
  assert.ok(out.indexOf(USER_NOTES_STUB) > out.indexOf(MANAGED_END))
  assert.equal(out, `${wrapManaged("body")}\n\n${USER_NOTES_STUB}\n`)
})

test("create without includeNotesStub omits the notes stub (back-compat)", () => {
  const out = upsertAgentsMd(null, "body")
  assert.ok(!out.includes("## Project notes"))
  assert.equal(out, `${wrapManaged("body")}\n`)
})

test("includeNotesStub is ignored when the file already exists", () => {
  const existing = `# Head\n\nprose\n\n${wrapManaged("old")}\n`
  const out = upsertAgentsMd(existing, "new", { includeNotesStub: true })
  assert.ok(!out.includes("## Project notes"))
  assert.ok(out.includes("# Head"))
})

test("a created-with-notes file stays idempotent on re-run (no duplicate stub)", () => {
  const once = upsertAgentsMd(null, "body", { includeNotesStub: true })
  // Second run sees an existing file with sentinels: only the block is touched.
  const twice = upsertAgentsMd(once, "body", { includeNotesStub: true })
  assert.equal(twice, once)
  assert.equal(twice.split("## Project notes").length - 1, 1)
})

// --- I3: reject a managed body that itself contains the sentinels ---
// (delimiter-in-payload would break idempotency and corrupt the block on the
// next replace, so wrapManaged / upsertAgentsMd must refuse it.)

test("wrapManaged throws when the body contains a start sentinel", () => {
  assert.throws(() => wrapManaged(`oops ${MANAGED_START} inside`), /sentinel/i)
})

test("wrapManaged throws when the body contains an end sentinel", () => {
  assert.throws(() => wrapManaged(`oops ${MANAGED_END} inside`), /sentinel/i)
})

test("upsertAgentsMd propagates the sentinel-in-body guard", () => {
  assert.throws(() => upsertAgentsMd(null, `x ${MANAGED_END} y`), /sentinel/i)
})

// --- I2: multiple managed blocks — first wins, later blocks left untouched ---
// Documented, pinned behavior: we replace only the FIRST block and preserve the
// rest verbatim (stable + idempotent), rather than guessing across blocks.

test("upsert with two managed blocks replaces only the first and is idempotent", () => {
  const existing = [
    wrapManaged("FIRST old"),
    "",
    "middle prose",
    "",
    wrapManaged("SECOND old"),
    "",
  ].join("\n")
  const out = upsertAgentsMd(existing, "FIRST new")
  assert.ok(out.includes("FIRST new"), "first block updated")
  assert.ok(out.includes("SECOND old"), "second block preserved verbatim")
  assert.ok(!out.includes("FIRST old"), "first old body gone")
  assert.ok(out.includes("middle prose"), "middle prose preserved")
  // Idempotent: re-running converges (second block still there, unchanged).
  assert.equal(upsertAgentsMd(out, "FIRST new"), out)
})

// --- N4: the managed block is always emitted with LF newlines ---
// Surrounding bytes (including CRLF) are preserved; the injected block is LF.

test("managed block uses LF even when surrounding content is CRLF", () => {
  const existing = `pre\r\n${wrapManaged("old")}\r\npost`
  const out = upsertAgentsMd(existing, "new")
  // Surrounding CRLF preserved:
  assert.ok(out.startsWith("pre\r\n"))
  assert.ok(out.endsWith("\r\npost"))
  // The block itself is LF-only (no CR inside the sentinels):
  const block = out.slice(out.indexOf(MANAGED_START), out.indexOf(MANAGED_END) + MANAGED_END.length)
  assert.ok(!block.includes("\r"), "managed block has no CR")
})
