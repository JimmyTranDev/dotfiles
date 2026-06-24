---
name: knip
description: Finds and safely removes unused files, dependencies, devDependencies, exports, types, enum/namespace members, and duplicate exports in JavaScript/TypeScript projects with Knip. Use when asked to run knip, find or delete dead code, prune unused dependencies/exports, clean up a JS/TS codebase, write or fix knip.json / knip.config.ts, triage knip's reported issues, auto-fix with `knip --fix`, or add knip to CI. Triggers on "knip", "unused dependencies", "unused exports", "unused files", "dead code", "prune deps", "knip.json", "--fix". Use ONLY for JavaScript/TypeScript projects that have a package.json; treat surprising results as real findings or configuration gaps to teach Knip (entry/project/plugins), not false positives to silence with ignore*. For routine dependency version bumps use npm-audit-and-bump-minor, not this.
---

# Knip (Unused Files, Dependencies & Exports)

## Overview

Knip is a dead-code linter for JavaScript/TypeScript projects. It builds a module
graph from your `entry` files and reports everything in your `project` files it
cannot reach: unused **files**, **dependencies** / **devDependencies**, unlisted
dependencies, unused **binaries**, unresolved imports, unused **exports**,
**types**, **enum/namespace members**, **duplicate exports**, and unused catalog
entries. It then auto-fixes most of them with `--fix`.

> **Core principle.** When Knip reports something surprising, it is telling the
> truth about its module graph: it could not reach that code from an entry file.
> A surprising result is almost always a **real finding** or a **configuration
> gap** — *not* a false positive to silence. The fix is to teach Knip about the
> project (`entry`, `project`, plugins, `paths`, compilers), and reach for
> `ignore*` only as a last resort.

## When to Use

- Running `knip` to find unused files, dependencies, exports, or types in a JS/TS repo
- Removing dead code / pruning unused deps with `knip --fix`
- Writing or fixing a `knip.json` / `knip.config.ts` configuration
- Triaging Knip's reported issues (true finding vs config gap)
- Adding Knip as a quality gate in CI

**Do NOT use when:**

- The project is not JavaScript/TypeScript (no `package.json`) — Knip does not apply.
- The task is bumping dependency *versions* (latest minor/patch) → use `npm-audit-and-bump-minor`.
- The task is removing unused **variables/imports inside a file** — that is ESLint/Biome's
  job, not Knip's (Knip works at the file/export/dependency level).

## Install & Run

Knip v6 requires Node.js ≥20.19.0 (or Bun). `typescript` is a peer dependency.

```bash
# One-off, no install (typescript expected to be present already)
npx knip

# Scaffold a config + script (recommended for a repo you'll lint repeatedly)
npm init @knip/config        # adds knip + a "knip" script to package.json

# Manual install
npm install -D knip typescript @types/node   # then: npm run knip
```

Run it via `npx knip`, or a `package.json` script `"knip": "knip"`. Use
`knip-bun` (= `bunx --bun knip`) to run on the Bun runtime.

## Core Workflow

### 1. Work on a clean tree

Knip's `--fix` edits and can delete files. Commit or stash first so every change
is reviewable and reversible via git. Generate/build any codegen'd files first
(e.g. route trees, `dist/` in monorepos) so Knip can resolve them.

### 2. Establish a baseline

```bash
npx knip
```

Read **configuration hints** first — addressing them often clears a cascade of
false unused-file reports. Exit codes: `0` = clean, `1` = issues found, `2` =
Knip itself errored (bad input/config).

### 3. Triage top-down — findings come in chains

Resolve issue types **in this order**; fixing earlier ones removes many later
ones. Use filters to focus on one type at a time:

```bash
knip --files          # only unused files
knip --dependencies   # only dependency issues (unused/unlisted/binaries/unresolved)
knip --exports        # only export issues (exports/types/enum & ns members/duplicates)
```

```
1. Unused files        → fix entry/project coverage first (biggest leverage)
2. Unresolved imports  → path aliases, extensions, template-string imports
3. Unused exports      → internal-only exports, namespace/external consumption
4. Unused dependencies → mostly resolved once files above are correct
```

### 4. For each finding: real removal vs configuration gap

Before deleting, decide which it is. Common causes of **false** positives and the
**right fix** (teach Knip — do not `ignore`):

| Symptom | Likely cause | Fix |
|---|---|---|
| Source file reported unused | Dynamic/template `import()`, codegen, HTML `<script src>`, auto-import | Add it to `entry`; add a compiler for non-JS/HTML |
| Config/tool file + its dep reported unused | Missing/incomplete **plugin** for that tool | Enable/override the plugin; add the config as `entry`; PR a plugin |
| Import unresolved | Unrecognized path alias / extensionless non-standard import | Add `paths`; include the file extension |
| Export reported unused but used internally | Internal-only usage | `ignoreExportsUsedInFile`, or a JSDoc `@public`-style tag via `tags` |
| Export used only by an external lib / custom element | Non-standard consumption | Tag it, or re-export from / move to an `entry` file |
| Dependency added conditionally in a config file | `process.env` branch false at lint time | `ignoreDependencies` (documented last resort) |
| `@types/*` reported unused | Package now ships its own bundled types | Remove the obsolete `@types/*` (a real finding) |

Genuinely unused code/deps → proceed to fix. `--include-entry-exports` /
`includeEntryExports` surfaces unused exports in entry files (Knip hides these by
default).

### 5. Configure with a schema-backed file

Prefer `entry` / `project` / plugin config over `ignore`. Always add `$schema`
for editor validation:

```jsonc
// knip.jsonc
{
  "$schema": "https://unpkg.com/knip@6/schema.json",
  "entry": ["src/index.ts", "scripts/*.ts"],
  "project": ["src/**/*.ts", "!**/__mocks__/**"],
  "ignoreDependencies": ["@reportportal/agent-js-playwright"]
}
```

Config files (first found wins): `knip.json`, `knip.jsonc`, `.knip.json`,
`knip.ts`, `knip.config.ts`, `knip.js`, `package.json#knip`. JSONC schema is
`schema-jsonc.json`. For monorepos, configure `entry`/`project`/plugins per
workspace under `"workspaces": { ".": {…}, "packages/*": {…} }`. Use
`--production` / `-p` (excludes tests, config, stories, devDependencies) or
`--strict` (also isolates workspaces to direct deps) to lint only shipped code.

### 6. Auto-fix — only after the report looks right

```bash
knip --fix                          # remove unused exports & dependencies
knip --fix --allow-remove-files     # also delete unused files
knip --fix-type exports,types       # scope the fix to specific issue types
knip --fix --format                 # format touched files (Biome/dprint/Prettier/deno)
```

`--fix` handles: unused files (with `--allow-remove-files`), `export`/`export
default` keywords, re-exports, enum & namespace members, unused
`dependencies`/`devDependencies`, and catalog entries. It does **not**: add
unlisted deps/binaries, fix duplicate exports, or remove unused variables inside
a file.

### 7. Post-fix cleanup

1. **Reinstall** after `package.json` changes: `npm install`.
2. **Unused variables/imports** left behind → run ESLint/Biome (or
   `remove-unused-vars`). This may delete more code → **re-run Knip; rinse and
   repeat** until stable.
3. **Unlisted deps/binaries** Knip reported → install/list them yourself
   (`npm install <pkg>`); Knip won't add them.

### 8. Verify, then gate in CI

Run the project's build, typecheck, and tests after any removal (see
Verification). Then wire Knip in: it exits `1` on findings, so `knip` alone fails
CI. For gradual adoption use `--reporter github-actions`, cap with `--max-issues
<n>`, or temporarily `--no-exit-code`.

## Reference

**Key CLI flags** — `-p/--production`, `-s/--strict`, `-W/--workspace <name>`,
`--include`/`--exclude <type>`, `--files`/`--dependencies`/`--exports` (filters),
`-f/--fix`, `--fix-type <types>`, `--allow-remove-files`, `-F/--format`,
`-c/--config <file>`, `-t/--tsConfig <file>`, `--cache` (10–40% faster reruns),
`--reporter <symbols|compact|json|markdown|codeowners|codeclimate|github-actions>`,
`--no-exit-code`, `--max-issues <n>`, `--include-entry-exports`, `-d/--debug`,
`--trace` / `--trace-export <name>` / `--trace-file <path>` (why is X used?).

**Issue types** (for `--include`/`--exclude`/`--fix-type`): `files`,
`dependencies`, `unlisted`, `binaries`, `unresolved`, `exports`, `nsExports`,
`types`, `nsTypes`, `enumMembers`, `namespaceMembers`, `duplicates`, `catalog`.

**Key config options** — `entry`, `project`, `paths`, `workspaces`, plugin
overrides (`"<plugin>": { config, entry } | true | false`), `ignore`,
`ignoreFiles`, `ignoreDependencies`, `ignoreBinaries`, `ignoreUnresolved`,
`ignoreWorkspaces`, `ignoreIssues`, `ignoreExportsUsedInFile`,
`includeEntryExports`, `tags`, `compilers` (dynamic config only),
`treatConfigHintsAsErrors`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It's a false positive, I'll just add it to `ignore`." | Knip is reporting its real module graph. `ignore` hides the symptom; the right fix is almost always an `entry`/`project`/plugin/`paths` adjustment. `ignore*` is a documented last resort. |
| "I'll run `knip --fix` right away to clean up fast." | `--fix` deletes code and files. Establish a clean git tree and review the *report* first; only fix once the report reflects reality. |
| "Knip says these files are unused, delete them all." | Unused-file reports are frequently a missing plugin, codegen step, or dynamic import. Triage the cause before `--allow-remove-files`. |
| "Knip removed the exports, the cleanup is done." | `--fix` leaves unused *variables/imports* inside files and never adds unlisted deps. Run ESLint/Biome, reinstall, then re-run Knip — removals cascade. |
| "It found unused deps, I'll edit package.json by hand." | Let `--fix` prune `dependencies`/`devDependencies` precisely, then `npm install`. Hand-editing misses transitive/catalog cases Knip tracks. |
| "I'll skip the build/tests; Knip only removes dead code." | Dynamic usage and config-driven imports can be misread. Always prove build + typecheck + tests still pass after removal. |

## Red Flags

- Adding entries to `ignore` / `ignoreDependencies` before reading config hints
  or adjusting `entry`/`project`/plugins.
- Running `--fix` / `--allow-remove-files` on a dirty git tree, or without first
  reading the report.
- Deleting reported files when a plugin is missing, codegen hasn't run, or the
  import is dynamic.
- Treating the run as done after `--fix` without reinstalling deps, running
  ESLint/Biome for unused vars, and re-running Knip.
- No build/typecheck/test run after removals.
- A `knip.json` without `$schema`.

## Verification

- [ ] Baseline `npx knip` was run and configuration hints were addressed first.
- [ ] Each finding was triaged as a real removal vs a config gap; config gaps fixed via `entry`/`project`/plugins/`paths`/compilers, not blanket `ignore`.
- [ ] Any config lives in a schema-backed `knip.json`/`knip.jsonc`/`knip.config.ts`.
- [ ] `--fix` was run only after the report was correct; file deletion used `--allow-remove-files` deliberately.
- [ ] Post-fix: `npm install` run, ESLint/Biome cleared unused vars, Knip re-run until stable.
- [ ] Project build, typecheck, and tests pass after all removals.
- [ ] If gated in CI, the chosen exit-code behavior (`knip` fails on `1`, or `--max-issues`/`--no-exit-code` for gradual adoption) is intentional.
