// Pure text-merge logic for upserting a managed section into a project's
// AGENTS.md, used by the /init-config command.
//
// A project's AGENTS.md may be hand-written. To update opencode's guidance in
// place without ever clobbering that prose, opencode's content lives between two
// sentinel comments. An upsert only ever rewrites the bytes BETWEEN the
// sentinels; everything outside them is preserved verbatim. When the file has no
// sentinels yet, the managed block is appended; when the file is absent/empty,
// the managed block becomes the file (optionally followed by an unmanaged
// "user notes" area so there is an obvious safe place to write). Re-running with
// identical managed content is idempotent.
//
// This module is pure: no I/O, no process, no side effects — so it is unit
// testable in isolation. The thin CLI wrapper (agents-md-upsert.mjs) does the
// file reads/writes around it.

export const MANAGED_START = "<!-- opencode:managed:start -->"
export const MANAGED_END = "<!-- opencode:managed:end -->"

// A small unmanaged stub placed AFTER the managed block when creating a brand-new
// AGENTS.md, giving the user an obvious place to add their own guidance that the
// command will never overwrite. It lives outside the sentinels on purpose.
export const USER_NOTES_STUB = [
  "## Project notes",
  "",
  "<!-- Add your own project-specific guidance here. This section is OUTSIDE the",
  "     managed block above, so re-running `/init-config` will never touch it. -->",
].join("\n")

// Wrap the inner managed body in the sentinel comments. The inner content is
// trimmed and re-padded with single blank lines so repeated upserts are stable
// regardless of incidental leading/trailing whitespace in the input.
//
// The body must NOT itself contain either sentinel string: a sentinel in the
// payload would break idempotency and let a later replace truncate the block at
// the injected marker (the classic delimiter-in-payload bug). We refuse it
// loudly rather than silently corrupt the file on a future run.
export function wrapManaged(inner) {
  const body = String(inner ?? "").trim()
  if (body.includes(MANAGED_START) || body.includes(MANAGED_END)) {
    throw new Error(
      "managed body must not contain the opencode:managed sentinel comments",
    )
  }
  return `${MANAGED_START}\n\n${body}\n\n${MANAGED_END}`
}

// True when the text already carries a managed block (both sentinels, in order).
export function hasManagedBlock(text) {
  const value = String(text ?? "")
  const startAt = value.indexOf(MANAGED_START)
  if (startAt === -1) return false
  const endAt = value.indexOf(MANAGED_END, startAt + MANAGED_START.length)
  return endAt !== -1
}

// Upsert the managed block into an existing AGENTS.md document.
//
//   existing:      the current file contents (null/undefined/"" => file absent)
//   managedInner:  the managed body to place between the sentinels
//   options:
//     includeNotesStub:  when creating a brand-new file, also append the
//                        unmanaged USER_NOTES_STUB after the managed block
//                        (default false; ignored when the file already exists)
//
// Returns the full new document as a string. Behaviour:
//   - absent/blank existing  -> the wrapped managed block is the file (plus the
//                               notes stub when includeNotesStub is set)
//   - existing has sentinels -> only the FIRST block (its first start + matching
//                               end) is replaced; all surrounding bytes are
//                               preserved verbatim
//   - existing, no sentinels -> the wrapped block is appended after exactly one
//                               blank line, leaving existing content untouched
//
// Multiple managed blocks: only the first is updated; any later block is left
// untouched (stable and idempotent, never guessed across blocks). A lone start
// sentinel with no matching end is treated as unmanaged and a fresh block is
// appended.
//
// Idempotent: re-running with the same managedInner yields identical output. The
// notes stub is only ever emitted on first creation, so idempotency holds (the
// second run sees an existing file with sentinels and only replaces the block).
export function upsertAgentsMd(existing, managedInner, options = {}) {
  const wrapped = wrapManaged(managedInner)
  const current = existing === undefined || existing === null ? "" : String(existing)

  // Absent or whitespace-only file: the managed block IS the file. Optionally
  // append the unmanaged notes stub so the user has a safe place to write.
  if (current.trim() === "") {
    if (options.includeNotesStub) {
      return `${wrapped}\n\n${USER_NOTES_STUB}\n`
    }
    return `${wrapped}\n`
  }

  const startAt = current.indexOf(MANAGED_START)
  if (startAt !== -1) {
    const endAt = current.indexOf(MANAGED_END, startAt + MANAGED_START.length)
    if (endAt !== -1) {
      // Replace only [startAt, endAt + END.length) with the freshly wrapped
      // block; keep the prefix and suffix (user prose) byte-for-byte.
      const prefix = current.slice(0, startAt)
      const suffix = current.slice(endAt + MANAGED_END.length)
      return `${prefix}${wrapped}${suffix}`
    }
    // A start sentinel with no matching end is malformed; fall through and
    // append a fresh, well-formed block rather than trying to guess the range.
  }

  // No (valid) managed block: append one after exactly one blank line, and end
  // the file with a single trailing newline.
  const base = current.replace(/\s+$/, "")
  return `${base}\n\n${wrapped}\n`
}

// Build the default managed body for a project from a lightweight detected-stack
// descriptor. `detected` is best-effort and every field is optional:
//
//   { name, build, test, lint, dev, notes }
//
// The body is intentionally a compact, editable starter: a routing note plus a
// commands table (only for the hints that were detected) plus the Always /
// Ask-first / Never boundaries. Users are expected to edit around it and add
// their own prose OUTSIDE the sentinels.
export function defaultManagedInner(detected = {}) {
  const name = (detected.name && String(detected.name).trim()) || "this project"

  const commandRows = [
    ["Build", detected.build],
    ["Test", detected.test],
    ["Lint", detected.lint],
    ["Dev", detected.dev],
  ].filter(([, cmd]) => cmd && String(cmd).trim() !== "")

  const lines = []
  lines.push(`# AGENTS.md — ${name}`)
  lines.push("")
  lines.push(
    "Guidance for AI agents working in this project. The content between the",
  )
  lines.push(
    "`opencode:managed` sentinels is maintained by the `/init-config` command —",
  )
  lines.push(
    "edit your own notes OUTSIDE this block so re-running the command never",
  )
  lines.push("overwrites them.")
  lines.push("")

  if (commandRows.length > 0) {
    lines.push("## Commands")
    lines.push("")
    lines.push("| Task | Command |")
    lines.push("|------|---------|")
    for (const [label, cmd] of commandRows) {
      lines.push(`| ${label} | \`${String(cmd).trim()}\` |`)
    }
    lines.push("")
  }

  lines.push("## Boundaries")
  lines.push("")
  lines.push("- **Always:** run the project's tests/build before committing; follow existing conventions.")
  lines.push("- **Ask first:** adding dependencies, changing config or CI, schema changes.")
  lines.push("- **Never:** commit secrets; overwrite hand-written docs; force-push shared branches.")

  if (detected.notes && String(detected.notes).trim() !== "") {
    lines.push("")
    lines.push(String(detected.notes).trim())
  }

  return lines.join("\n")
}
