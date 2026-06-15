# ADR-0001: Generate the Claude Code config from the OpenCode config

## Status

Accepted

## Date

2026-06-15

## Context

The dotfiles repo maintains a large, mature OpenCode configuration under `src/opencode/`
(1 `AGENTS.md`, 17 agents, 35 commands, 105 skills, `opencode.jsonc`, `tui.jsonc`, a JS
plugin). The user also wants the same agents, slash commands, skills, and global rules
available when using Claude Code, whose user-level config lives under `~/.claude/`.

OpenCode and Claude Code use similar but not identical formats:

- Agent frontmatter differs — OpenCode lists *disabled* tools as a boolean map
  (`tools: {write: false}`); Claude lists *allowed* tools as a comma-separated string.
  OpenCode also uses `mode`/`temperature` fields that Claude does not.
- Command frontmatter differs — OpenCode uses `name`/`subtask`; Claude derives the
  command name from the filename and has no `subtask`.
- Skills are nearly identical (`SKILL.md` with `name`/`description` frontmatter), but
  Claude imposes constraints (name `^[a-z0-9-]{1,64}$`, description ≤ 1024 chars).
- `opencode.jsonc` (JSONC, with comments) maps to `settings.json` (strict JSON).

Maintaining two hand-written copies would inevitably drift. We need a single source of
truth and a reliable way to keep the Claude config aligned.

## Decision

We will treat `src/opencode/` as the **single source of truth** and **generate**
`src/claude/` from it with a re-runnable converter. The generated config is committed to
the repo and symlinked to `~/.claude/` via `sync_links.sh`; it must never be hand-edited.

The converter will be written in **Node.js (an `.mjs` ES module)** with a thin Bash
wrapper (`opencode-to-claude.sh`) living in `etc/scripts/src/ai/`. The wrapper preserves
the repo's AI-script convention (`--help`, logs to stderr, minified JSON summary to
stdout) and delegates the actual transformation to the Node module.

## Consequences

### Positive
- Robust YAML frontmatter parsing/serialization and the agent tools-inversion logic are
  far easier and safer in Node than in `sed`/`awk`.
- Node 22 is already available and the `src/opencode/` directory already carries a
  `package.json`/`node_modules`, so no new runtime dependency is introduced.
- One source of truth eliminates drift; regenerating is a single command.
- The bash wrapper keeps the script discoverable and consistent with the existing
  `etc/scripts/src/ai/` table.

### Negative
- Introduces a Node script into a primarily Bash scripts directory, so contributors must
  read two languages to follow the full pipeline.
- The generated `src/claude/` tree (~158 files) adds noise to diffs whenever the OpenCode
  source changes; reviewers must remember the Claude side is generated.

### Neutral
- The JS notification plugin (`plugins/notification.js`) and `tui.jsonc` have no clean
  Claude equivalent and are out of scope for v1.

## Alternatives Considered

### Pure Bash converter
- Description: Implement the converter entirely in Bash with `sed`/`awk` for frontmatter.
- Pros: Matches the dominant language in `etc/scripts/`; no second runtime.
- Cons: YAML parsing and the tools bool-map → allow-string inversion are fragile and
  error-prone in Bash; high risk of malformed frontmatter.

### Hand-maintained Claude config (no generation)
- Description: Write `src/claude/` by hand and keep it in sync manually.
- Pros: No converter to build; full control over every file.
- Cons: Guaranteed drift across 158 files; doubles the maintenance burden for every
  OpenCode change. Rejected outright.

### Symlink-sharing identical files
- Description: Symlink skills directly and only convert agents/commands/settings.
- Pros: Less generated content for the near-identical skills.
- Cons: Skips Claude's skill constraint validation, leaks OpenCode self-reference paths,
  and still needs a converter for the rest — little net simplification.

## References

- Spec: `plans/opencode-to-claude-config-port.md`
- Converter: `etc/scripts/src/ai/opencode-to-claude.sh` (+ `opencode-to-claude.mjs`)
- Symlink wiring: `etc/scripts/src/install/sync_links.sh`
