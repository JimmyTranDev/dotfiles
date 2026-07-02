#!/usr/bin/env node
// Thin I/O wrapper around agents-md-upsert-core.mjs: upsert opencode's managed
// section into a project's AGENTS.md without clobbering hand-written prose.
//
// The /init-config command runs this. All the merge rules live in the pure core
// (create / replace-block / append / idempotent); this file only reads the
// target file + the managed body, calls upsertAgentsMd, then prints or writes.
//
// Usage:
//   node agents-md-upsert.mjs <AGENTS.md path> [options]
//   node agents-md-upsert.mjs --file <path> [options]
//
// Managed-body source (pick one; default is the generated starter):
//   --inner-file <path>   read the managed body from a file
//   --stdin               read the managed body from stdin
//   (neither)             generate a default starter body from the hints below
//
// Starter hints (only used when generating the default body):
//   --name <s>   --build <cmd>   --test <cmd>   --lint <cmd>   --dev <cmd>
//
// Output:
//   (default)      print the merged document to stdout (a dry run — writes nothing)
//   --dry-run      same as default, explicit
//   --write        write the merged document back to the target file
//                  (its parent directory is created if needed)
//   --create-notes when creating a NEW file, add an unmanaged "Project notes"
//                  section after the managed block (ignored if the file exists)
//   -h, --help     print this usage and exit 0
//
// Missing target file => treated as "create". Errors (missing path, an
// unreadable existing file, a failed write) print a single `error: <message>`
// line to stderr and exit non-zero — never an uncaught stack trace.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs"
import { dirname } from "node:path"
import { upsertAgentsMd, defaultManagedInner } from "./agents-md-upsert-core.mjs"

const USAGE = `Upsert opencode's managed section into a project's AGENTS.md.

Usage:
  node agents-md-upsert.mjs <AGENTS.md path> [options]
  node agents-md-upsert.mjs --file <path> [options]

Managed-body source (default: generated starter):
  --inner-file <path>   read the managed body from a file
  --stdin               read the managed body from stdin

Starter hints (used only when generating the default body):
  --name <s>  --build <cmd>  --test <cmd>  --lint <cmd>  --dev <cmd>

Output:
  (default)       print merged document to stdout (dry run; writes nothing)
  --dry-run       explicit dry run
  --write         write merged document back to the target file (mkdir -p parent)
  --create-notes  on a NEW file, add an unmanaged "Project notes" section
  -h, --help      show this help
`

// Minimal flag parser: collects "--flag value" pairs, "--bool" switches, and the
// first bare token as the positional target path.
function parseArgs(argv) {
  const opts = { write: false, stdin: false, help: false, createNotes: false }
  const valueFlags = new Set([
    "file",
    "inner-file",
    "name",
    "build",
    "test",
    "lint",
    "dev",
  ])
  let positional = null
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i]
    if (arg === "-h" || arg === "--help") {
      opts.help = true
    } else if (arg === "--write") {
      opts.write = true
    } else if (arg === "--dry-run") {
      opts.write = false
    } else if (arg === "--stdin") {
      opts.stdin = true
    } else if (arg === "--create-notes") {
      opts.createNotes = true
    } else if (arg.startsWith("--")) {
      const key = arg.slice(2)
      if (valueFlags.has(key)) {
        opts[key] = argv[++i]
      }
      // Unknown --flags are ignored so the caller can pass extras harmlessly.
    } else if (positional === null) {
      positional = arg
    }
  }
  if (opts.file === undefined && positional !== null) {
    opts.file = positional
  }
  return opts
}

function readFileOrEmpty(path) {
  try {
    return readFileSync(path, "utf8")
  } catch (error) {
    if (error && error.code === "ENOENT") return ""
    throw error
  }
}

// Read the managed body from stdin. A closed/empty stdin (EOF) legitimately
// yields "", but any other read failure is surfaced rather than silently
// turning into an empty managed block.
function readStdin() {
  try {
    return readFileSync(0, "utf8")
  } catch (error) {
    if (error && (error.code === "EOF" || error.code === "EAGAIN" || error.code === "ENXIO")) {
      return ""
    }
    throw error
  }
}

function resolveManagedInner(opts) {
  if (opts["inner-file"]) {
    return readFileOrEmpty(opts["inner-file"])
  }
  if (opts.stdin) {
    return readStdin()
  }
  return defaultManagedInner({
    name: opts.name,
    build: opts.build,
    test: opts.test,
    lint: opts.lint,
    dev: opts.dev,
  })
}

function main() {
  const opts = parseArgs(process.argv.slice(2))

  if (opts.help) {
    process.stdout.write(USAGE)
    return 0
  }

  if (!opts.file) {
    process.stderr.write("error: no target AGENTS.md path given\n\n")
    process.stderr.write(USAGE)
    return 2
  }

  const existing = readFileOrEmpty(opts.file)
  const managedInner = resolveManagedInner(opts)
  const merged = upsertAgentsMd(existing, managedInner, {
    includeNotesStub: opts.createNotes,
  })

  if (opts.write) {
    // Create the parent directory so writing a nested target (e.g. a project's
    // .opencode/AGENTS.md) never fails on a missing directory.
    mkdirSync(dirname(opts.file), { recursive: true })
    writeFileSync(opts.file, merged)
    process.stderr.write(`agents-md-upsert: wrote ${opts.file}\n`)
  } else {
    process.stdout.write(merged)
  }
  return 0
}

// Best-effort CLI: any failure becomes a single clear error line, never an
// uncaught stack trace, and always a non-zero exit.
try {
  process.exit(main())
} catch (error) {
  process.stderr.write(`error: ${error?.message ?? error}\n`)
  process.exit(1)
}
