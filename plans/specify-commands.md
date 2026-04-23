# Rename scan-* Commands to specify-* with Spec Output

## Overview

Rename all 12 `scan-*` commands to `specify-*` and change their behavior from outputting findings to chat to writing structured spec files into a `spec/` folder at the project root. Each command writes to its own subfolder (e.g., `spec/review/`, `spec/audit/`). This moves the workflow toward spec-driven design where analysis produces actionable spec documents rather than ephemeral chat output.

## Architecture

All changes are within `src/opencode/command/`. Each command file is a standalone markdown file with frontmatter — no shared code between them. The AGENTS.md command taxonomy table also needs updating to reflect the new `specify-*` prefix.

## Data flow

1. User runs `/specify-review [scope]`
2. Command performs the same analysis as the old `scan-review`
3. Instead of outputting to chat, writes findings to `spec/review/<descriptive-name>.md` (or timestamped if no scope given)
4. Prints a summary to chat with the file path and key highlights

## Tasks

### 1. Rename and update each command file

For each of the 12 commands below, rename the file, update the frontmatter `name`, update the `Usage:` line, and change the output behavior from "output to chat" to "write to spec/<subfolder>/". The analysis logic stays identical — only the name, description, and output destination change.

| Old file | New file | Spec subfolder | Complexity |
|----------|----------|----------------|------------|
| `scan-review.md` | `specify-review.md` | `spec/review/` | small |
| `scan-audit.md` | `specify-audit.md` | `spec/audit/` | small |
| `scan-quality.md` | `specify-quality.md` | `spec/quality/` | small |
| `scan-test.md` | `specify-test.md` | `spec/test/` | small |
| `scan-logic.md` | `specify-logic.md` | `spec/logic/` | small |
| `scan-design.md` | `specify-design.md` | `spec/design/` | small |
| `scan-innovate.md` | `specify-innovate.md` | `spec/innovate/` | small |
| `scan-engage.md` | `specify-engage.md` | `spec/engage/` | small |
| `scan-devtools.md` | `specify-devtools.md` | `spec/devtools/` | small |
| `scan-useful.md` | `specify-useful.md` | `spec/useful/` | small |
| `scan-architecture.md` | `specify-architecture.md` | `spec/architecture/` | small |
| `scan-comments.md` | `specify-comments.md` | `spec/comments/` | small |

All 12 can be done in parallel — no dependencies between them.

For each file, the changes are:

1. **Frontmatter**: `name: scan-X` → `name: specify-X`
2. **Description**: Keep the analysis description but add "and write spec to `spec/X/`"
3. **Usage line**: `/scan-X` → `/specify-X`
4. **Output step** (the final step in each command): Replace the "output to chat" instruction with:
   - Create `spec/<subfolder>/` if it doesn't exist
   - Choose a filename: use the scope description in kebab-case if given (e.g., `spec/review/auth-module.md`), otherwise use a timestamp (e.g., `spec/review/2026-04-23.md`)
   - Write findings in the same structured format, but to the file
   - Print a brief summary to chat: file path, total findings count, top 3 items
5. **Internal references**: Any mention of `/scan-*` commands as suggestions (e.g., "run `/scan-review`") should be updated to `/specify-*`

### 2. Delete old scan-* files

After creating the new `specify-*` files, delete all 12 old `scan-*` files. Sequential after task 1.

- Complexity: small

### 3. Update AGENTS.md command taxonomy

In both `src/opencode/AGENTS.md` and the repo root `AGENTS.md`:

- Rename `scan-*` → `specify-*` in the taxonomy table
- Update the prefix description from "Analysis, recommendations, findings" to "Analysis that writes structured specs to spec/ subfolders"
- Update the "Makes Changes?" column — `specify-*` writes spec files, so it's "Yes (spec files only)"
- Update the command listing to show all `specify-*` names
- Update any other references to `scan-*` commands throughout both files

Dependencies: none (can run in parallel with task 1)
Complexity: small

### 4. Update cross-references in other commands

Other commands reference `/scan-*` in their suggestions (e.g., `/fix` might say "run `/scan-review` first"). Search all command files for `scan-` references and update to `specify-`.

Dependencies: none (can run in parallel with tasks 1-3)
Complexity: small

### 5. Update cross-references in improve-* and fix-* commands

Commands like `improve-security.md` may reference `/scan-audit`. Update these references.

Dependencies: none (can run in parallel)
Complexity: small

## Edge cases

- **Existing spec/ folder**: The command should create `spec/<subfolder>/` only if it doesn't exist — use `mkdir -p` equivalent
- **Filename collisions**: If a spec file with the same name already exists, append a timestamp suffix rather than overwriting
- **No findings**: If analysis produces zero findings, still write the spec file with an "all clear" summary
- **scan-test special case**: `scan-test` currently writes tests (makes changes). As `specify-test`, it should still write tests but ALSO write a spec file to `spec/test/` with coverage gap analysis. The test-writing behavior should remain unchanged.
- **scan-comments special case**: `scan-comments` fetches PR review threads. As `specify-comments`, it should write the organized comment summary to `spec/comments/` instead of only chat output.

## Testing approach

Manual testing — run each `/specify-*` command on a test project and verify:
- Spec file is created in the correct subfolder
- Filename is descriptive or timestamped appropriately
- Chat summary is printed with file path and highlights
- Old `/scan-*` commands no longer exist

## Open questions

### Scope
- Should the existing `/specify` command (the implementation spec writer from `plans/`) be renamed to avoid confusion with the new `specify-*` analysis commands? They serve different purposes — `/specify` writes implementation plans to `plans/`, while `specify-review` writes review findings to `spec/review/`.

### Conventions
- Spec file format: should it match the current chat output format exactly, or adopt a more structured template (e.g., with YAML frontmatter for metadata like date, scope, severity counts)?
