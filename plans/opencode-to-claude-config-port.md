# Spec: Port OpenCode config to a Claude Code config (`src/claude/`)

## TL;DR

- Generate a new `src/claude/` config in the dotfiles repo, mirroring `src/opencode/`, symlinked to `~/.claude/` (Claude Code's global config home — note: NOT under `~/.config/`).
- Full port: `AGENTS.md` → `CLAUDE.md`, `agent/` → `agents/`, `command/` → `commands/`, `skills/` → `skills/`, `opencode.jsonc` → `settings.json`. That's 1 instructions file + 17 agents + 35 commands + 105 skills + settings = **~158 generated files**.
- Approach: build a single **re-runnable converter** in `etc/scripts/src/ai/` so OpenCode stays the source of truth and `src/claude/` is regenerated, never hand-edited.
- Most critical / highest-risk transforms: (1) **inverting agent `tools` semantics** (OpenCode lists *disabled* tools as a bool map; Claude lists *allowed* tools as a comma string), (2) **model alias mapping** (`github-copilot/claude-haiku-4.5` → Claude aliases), (3) **`permission` map → `settings.json` permissions**.
- Estimated effort: **Medium-Large** (~9 tasks). Critical path runs through the converter script. The 17 agents, 35 commands, and 105 skills convert mechanically once the script exists; per-file content is mostly copy-through with frontmatter rewrites.
- Out of scope unless decided otherwise: porting `plugins/notification.js` (Claude uses shell hooks, not JS plugins) and `tui.jsonc` (no Claude equivalent). **Decided: both skipped for v1.**

## Overview

The user wants a Claude Code configuration that mirrors the existing, mature OpenCode setup so the same agents, slash commands, skills, and global rules are available when using Claude Code. OpenCode remains the **single source of truth**; the Claude config is *generated* from it by a re-runnable converter, then symlinked into place via `sync_links.sh`. This spec covers the converter, the format-mapping rules, the symlink wiring, and the handling of pieces that have no clean Claude equivalent (JS plugin, TUI theme).

## Layer recommendation

**Tooling / config (devtools)** — full-stack-agnostic. This is OpenCode/Claude Code configuration engineering plus a shell/Node conversion script. No frontend/backend application layer involved.

## Architecture

How this fits the dotfiles repo:

- **Source of truth**: `src/opencode/` (unchanged by this work, except possibly a new `.gitignore` entry).
- **Generated output**: a new top-level `src/claude/` directory, structured to match Claude Code's expected `~/.claude/` layout.
- **Converter**: a new script under `etc/scripts/src/ai/` that reads `src/opencode/` and writes `src/claude/`. It owns all format transforms and is idempotent (safe to re-run; fully regenerates the output).
- **Symlinking**: `etc/scripts/src/install/sync_links.sh` gains a `src/claude → ~/.claude` entry in both the macOS and Linux link lists. Unlike every other tool here, the target is `~/.claude`, **not** `~/.config/claude` — Claude Code reads its user-level config from `~/.claude/`.
- **Docs**: `src/opencode/AGENTS.md` and the root `AGENTS.md` describe repo structure; they should gain a short note that `src/claude/` is generated and must not be hand-edited.

Directory mapping:

```
src/opencode/                      src/claude/
├── AGENTS.md             ───────▶ ├── CLAUDE.md
├── opencode.jsonc        ───────▶ ├── settings.json
├── tui.jsonc            ──(skip)─ │   (no Claude equivalent — see Open Questions)
├── agent/<name>.md       ───────▶ ├── agents/<name>.md
├── command/<name>.md     ───────▶ ├── commands/<name>.md
├── plugins/notification.js ─(?)── │   (hook reimpl — see Open Questions)
└── skills/<name>/SKILL.md ──────▶ └── skills/<name>/SKILL.md
```

## Data flow

1. Developer edits something in `src/opencode/` (an agent, command, skill, or `AGENTS.md`).
2. Developer runs the converter (`etc/scripts/src/ai/opencode-to-claude.<sh|mjs>`).
3. Converter walks `src/opencode/`, and for each file type applies the transform rules in **API contracts** below, writing results into `src/claude/` (wiping/regenerating output first so deletions propagate).
4. Converter prints a JSON summary to stdout (counts per type, any skipped/failed files) and logs progress to stderr — consistent with the repo's AI-script convention.
5. `sync_links.sh` symlinks `src/claude → ~/.claude` so Claude Code picks up agents, commands, skills, and `CLAUDE.md`.
6. On the next Claude Code session, the ported config is live.

## Tasks

Ordered. Complexity and parallelism noted per task.

1. **Record converter language decision + ADR.** **Decision: Node (`.mjs`) + thin bash wrapper.**
   - Output: ADR in `architecture/` per repo convention noting Node was chosen for robust YAML/frontmatter handling and tools-inversion, with a bash wrapper to satisfy the AI-script convention.
   - Complexity: small. Sequential — blocks Task 2.

2. **Create the converter skeleton** — `etc/scripts/src/ai/opencode-to-claude.mjs` + thin bash wrapper `opencode-to-claude.sh`.
   - New file. Set up arg parsing (`--help`, optional `[opencode-dir] [out-dir]` defaults), `set -e`, source `utils/logging.sh` (or wrapper does), JSON summary to stdout, logs to stderr. Idempotent: clear `src/claude/{agents,commands,skills}` before writing.
   - Depends on: Task 1.
   - Complexity: medium. Sequential.

3. **Implement AGENTS.md → CLAUDE.md transform.**
   - Copy content through. Apply term/path substitutions per the mapping table (e.g. references to "Skill tool"/"Task tool" semantics are kept; `src/opencode/` structural section may be relabeled). Decide whether to rewrite OpenCode-specific phrasing or copy verbatim (Open Question Q3).
   - Depends on: Task 2.
   - Complexity: medium. Parallel with Tasks 4–6.

4. **Implement agent frontmatter transform** (`agent/*.md` → `agents/*.md`).
   - Apply the **Agent frontmatter mapping** table. Critical: invert `tools` bool-map → Claude allowed-tools comma string; drop `mode`/`temperature`; map `model`. 17 files.
   - Depends on: Task 2.
   - Complexity: large (most error-prone transform). Parallel with Tasks 3, 5, 6.

5. **Implement command frontmatter transform** (`command/*.md` → `commands/*.md`).
   - Apply the **Command frontmatter mapping** table. Drop `name`/`subtask`; map `model`; keep `$ARGUMENTS`; optionally derive `argument-hint`. 35 files.
   - Depends on: Task 2.
   - Complexity: medium. Parallel with Tasks 3, 4, 6.

6. **Implement skill transform** (`skills/<name>/SKILL.md` → `skills/<name>/SKILL.md`).
   - Mostly copy-through (formats are near-identical). Validate Claude skill constraints (name: lowercase/hyphen/≤64 chars; description ≤1024 chars). Copy any non-`SKILL.md` resource files in each skill dir verbatim. Rewrite `Base directory for this skill: file://.../opencode/...` self-reference lines to the Claude path. 105 dirs.
   - Depends on: Task 2.
   - Complexity: medium (volume + constraint validation). Parallel with Tasks 3, 4, 5.

7. **Implement opencode.jsonc → settings.json transform.**
   - Map `permission` map → Claude `permissions` (recommend `{"defaultMode": "bypassPermissions"}` to match the current global `allow`, or explicit allow lists — see Q4). Map `mcp` block → `.mcp.json` (all currently disabled). Drop `autoupdate`/`instructions` (CLAUDE.md auto-loads). Emit valid JSON (no comments).
   - Depends on: Task 2.
   - Complexity: medium. Parallel with Tasks 3–6.

8. **Wire symlinks** — edit `etc/scripts/src/install/sync_links.sh`.
   - Add `"$DOTFILES_ROOT/src/claude|$HOME/.claude"` to the macOS link list (near line 27) and the Linux link list (near line 72). Confirm there's no pre-existing `~/.claude` to clobber (sync_links should back up/replace per its existing behavior).
   - Depends on: Task 2 producing `src/claude/` (for a real run); can be authored in parallel.
   - Complexity: small.

9. **Update repo docs + ignore generated noise.**
   - Add a note to root `AGENTS.md` and `src/opencode/AGENTS.md` "OpenCode Config Structure" that `src/claude/` is generated by the converter and must not be hand-edited.
   - Register the converter in the **AI Utility Scripts** table in both `AGENTS.md` files.
   - **Decision: commit `src/claude/`** (visible, diffable, usable right after clone). Do NOT git-ignore the generated output.
   - Depends on: Tasks 2–8.
   - Complexity: small.

## API contracts

### Converter CLI

```
opencode-to-claude.sh [--help] [opencode-dir] [out-dir]
  opencode-dir  default: src/opencode  (relative to dotfiles root)
  out-dir       default: src/claude
  stdout: minified JSON summary { agents, commands, skills, settings, claudeMd, skipped[], failed[] }
  stderr: log_info/log_success/log_warning/log_error progress
  exit 0 on success, non-zero on any failed transform
```

### Agent frontmatter mapping (`agent/*.md` → `agents/*.md`)

| OpenCode field | Claude Code field | Rule |
|----------------|-------------------|------|
| `name` | `name` | copy verbatim |
| `description` | `description` | copy verbatim |
| `mode: subagent` | — | drop (all Claude agents in `agents/` are subagents) |
| `temperature: N` | — | drop (unsupported); do NOT silently map to model |
| `tools: {write: false, edit: false}` (bool map of **disabled**) | `tools:` (comma string of **allowed**) | **INVERT**: start from the full Claude tool set, remove any key set to `false`, emit the remainder as a comma-separated string. If no `tools` block in source, omit `tools` (agent inherits all). |
| `model: github-copilot/claude-haiku-4.5` | `model: haiku` | map via **Model alias table**; if no model, omit |

Body (everything after frontmatter): copy verbatim. `@agent-name` mentions and skill names are preserved.

### Command frontmatter mapping (`command/*.md` → `commands/*.md`)

| OpenCode field | Claude Code field | Rule |
|----------------|-------------------|------|
| `name` | — | drop (filename is the command name) |
| `description` | `description` | copy verbatim |
| `subtask: true` | — | drop (no equivalent) |
| `model: github-copilot/...` | `model: <alias>` | map via **Model alias table**; if absent, omit |
| (none) | `argument-hint` | OPTIONAL: derive from a leading `Usage: /name [args]` line if present, else omit |
| `$ARGUMENTS` in body | `$ARGUMENTS` | keep as-is (both support it); `$1`/`$2` also valid in Claude |

Body: copy verbatim.

### Skill mapping (`skills/<name>/SKILL.md` → `skills/<name>/SKILL.md`)

| OpenCode field | Claude Code field | Rule |
|----------------|-------------------|------|
| `name` | `name` | copy; validate `^[a-z0-9-]{1,64}$` — fail loudly if violated |
| `description` | `description` | copy; truncate-guard at 1024 chars (fail, do not silently cut) |
| (body) | (body) | copy verbatim; rewrite trailing `Base directory for this skill: file://...opencode...` to the Claude install path |

Copy any sibling resource files (`scripts/`, `reference/`, etc.) within each skill dir verbatim.

### Model alias table (proposed — confirm in Q2)

| OpenCode model | Claude Code model |
|----------------|-------------------|
| `github-copilot/claude-haiku-4.5` | `haiku` |
| `github-copilot/claude-sonnet-4.5` (if used) | `sonnet` |
| `github-copilot/claude-opus-*` (if used) | `opus` |
| anything unrecognized | omit field + warn |

### settings.json shape (from `opencode.jsonc`)

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": { "defaultMode": "bypassPermissions" }
}
```
MCP servers (all currently `enabled: false`) go to a separate `.mcp.json` or are omitted until needed (Q4).

## State changes

- **New directory**: `src/claude/` and all generated contents (committed by default).
- **New script**: `etc/scripts/src/ai/opencode-to-claude.<sh|mjs>` (+ optional wrapper).
- **New symlink** (at install time): `~/.claude → src/claude` (created by `sync_links.sh`).
- **New ADR**: `architecture/NNNN-claude-config-generated-from-opencode.md`.
- **Edited files**: `sync_links.sh`, root `AGENTS.md`, `src/opencode/AGENTS.md`, possibly `.gitignore`.
- No environment variables introduced. The notification plugin's env vars (`OPENCODE_SOUND_*`) are not ported unless the hook reimplementation (Q6) is approved.

## Edge cases

- **Tools inversion correctness**: an agent with no `tools` block must inherit ALL tools (omit field), not get an empty allowlist. An agent disabling `write` + `edit` must still allow read/grep/glob/bash/etc. Verify against `reviewer.md` (`write: false, edit: false`) and `implementer.md` (no tools block).
- **Skill name/description constraints**: any OpenCode skill whose name exceeds 64 chars or has invalid characters, or description > 1024 chars, must fail the run with a clear message rather than produce an invalid Claude skill.
- **Idempotency / deletions**: re-running after deleting an OpenCode agent must remove the stale Claude agent. Regenerate output dirs from scratch each run.
- **JSON validity**: `settings.json` and `.mcp.json` must be comment-free valid JSON (source is JSONC with comments).
- **`$ARGUMENTS` vs `$1`**: commands relying on positional logic must keep working; don't rewrite `$ARGUMENTS`.
- **Self-referential skill paths**: skills print `Base directory ... file:///Users/jimmy/.config/opencode/skills/...`; if not rewritten, loaded Claude skills point at the OpenCode tree (works only because both are symlinked for the same user — still better to rewrite).
- **`~/.claude` already exists**: installing must not silently destroy a user's existing Claude config; rely on `sync_links.sh`'s existing backup/replace behavior and verify it triggers for a non-`.config` target.
- **AGENTS.md references to OpenCode-only concepts** (Skill tool, Task subagent types, `opencode.jsonc`): decide copy-verbatim vs. rewrite (Q3) — verbatim risks minor inaccuracy in Claude; rewriting risks drift from source of truth.

## Testing approach

- **Converter unit-ish checks**: run the converter against `src/opencode/`, then assert: file counts match (17 agents, 35 commands, 105 skills), every output frontmatter has no `mode`/`temperature`/`subtask`/(`name` for commands), and every `settings.json`/`.mcp.json` parses as JSON.
- **Tools-inversion spot checks**: assert `agents/reviewer.md` `tools` excludes `write,edit` but includes read tools; assert `agents/implementer.md` has no `tools` field.
- **Skill constraint checks**: assert all 105 skill names match `^[a-z0-9-]{1,64}$` and descriptions ≤1024 chars (this doubles as a lint on the OpenCode source).
- **Idempotency**: run twice; second run produces no diff.
- **Live smoke test**: symlink, open Claude Code, confirm a sample slash command (`/commit`), a subagent, and a skill load correctly.
- A small `verify` flag or companion check could be added later, but manual verification is acceptable for v1.

## Open questions

### Requirements
- **Q5 — Commit vs ignore generated output**: **Decision: commit `src/claude/`** — visible, diffable, usable right after clone with no build step.
- **Q6 — Notification plugin**: **Decision: out of scope for v1.** `plugins/notification.js` is not ported. May later be reimplemented as a Claude `Stop`/`Notification` hook.

### Architecture
- **Q1 — Converter language**: **Decision: Node (`.mjs`) + thin bash wrapper** for robust YAML/tools-inversion handling.
- **Q2 — Model alias mapping**: Confirm the OpenCode→Claude model alias table. Are any non-Haiku models used in commands/agents today? (Only `commit.md` shows `github-copilot/claude-haiku-4.5` so far.)
- **Q3 — AGENTS.md fidelity**: **Decision: copy `AGENTS.md` → `CLAUDE.md` verbatim** for v1; revisit if OpenCode-specific phrasing causes confusion.

### Scope
- **Q7 — `tui.jsonc`**: Claude Code has no TUI theme config equivalent. Confirm it's simply **skipped** (assumed yes).
- **Q8 — `_depreciated/`**: The OpenCode config excludes `_depreciated/` from discovery. Confirm the converter also **skips** `command/_depreciated/` and `skills/_depreciated/` (assumed yes).

### Conventions
- **Q9 — Output location of converter**: Confirm `etc/scripts/src/ai/` is the right home (per AGENTS.md "Save useful scripts to dotfiles") even though it generates files rather than emitting query JSON. Assumed yes.

### Risks
- **Q10 — `~/.claude` clobbering**: Confirm `sync_links.sh` safely backs up an existing `~/.claude` before symlinking, and that pointing the user's *global* Claude config at this repo is desired (vs a project-scoped `.claude/`).

## References

- Source config analyzed: `src/opencode/` (AGENTS.md, `agent/` ×17, `command/` ×35, `skills/` ×105, `opencode.jsonc`, `tui.jsonc`, `plugins/notification.js`).
- Symlink wiring: `etc/scripts/src/install/sync_links.sh` (macOS list ~line 27, Linux list ~line 72).
