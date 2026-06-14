---
todoist:
  - https://app.todoist.com/app/task/check-keymap-to-generate-4-pane-opencode-6grHXjPW4fV9hgjF
  - https://app.todoist.com/app/task/create-opencode-npm-audit-fix-command-opencode-6grHXmpjg9XcX8jm
  - https://app.todoist.com/app/task/abstract-things-from-skills-that-can-be-a-script-out-and-make-the-skill-use-the-script-6grHjhFcWrJgqvjm
  - https://app.todoist.com/app/task/task-6grHq7CJ3CrCGHRm
  - https://app.todoist.com/app/task/make-good-skill-for-inline-comment-we-dont-want-to-ban-it-completely-but-want-to-use-where-the-usage-is-useful-and-valid-6grHqPR83cwP4MmF
  - https://app.todoist.com/app/task/after-specify-always-ask-if-should-review-the-plan-or-not-6grHqcV3HJWHPPfm
---

# OpenCode p1 Tasks

## Layer recommendation

**Tooling / config (not frontend or backend).** Every task targets the OpenCode
configuration in this dotfiles repo (`src/opencode/` plus `etc/scripts/`). No
application UI or server logic is involved.

## TL;DR

- Covers the 6 p1 (urgent) tasks in the Todoist **Dotfiles** project, all
  OpenCode config / tooling work.
- **6 task groups**, mostly independent and parallelizable. Two are
  documentation/verification only; four create or modify config assets.
- Most critical / highest leverage: **T3** (extract repeatable skill logic into
  scripts) and **T4** (adopt net-new global-agent ideas) — both shape how every
  future skill and agent behaves.
- Quick wins: **T1** (verify + document the existing zellij quad keymap) and
  **T6** (add a "review the plan?" prompt to `/specify`).
- Estimated overall effort: **~1 day**. No single task is large; T3 and T5 are
  the biggest.

## Overview

This spec plans the six urgent OpenCode tasks pulled from the Todoist Dotfiles
project. They are unrelated features bundled by priority, so each is treated as
an independent task group under one spec file. Scope was clarified with the
user: single combined spec, verify-only for the existing quad keymap, net-new
ideas only for the global-agent proposal, and reuse of existing skill + scripts
for the npm-audit command.

All work lands under `~/Programming/JimmyTranDev/dotfiles/src/opencode/`
(agents, commands, skills, AGENTS.md) and `etc/scripts/src/ai/` (shared scripts).

## Architecture

How each piece fits the existing OpenCode config layout:

- **Commands** (`src/opencode/command/*.md`) — slash commands. T2 adds one; T6
  edits `specify.md`.
- **Skills** (`src/opencode/skills/<name>/SKILL.md`) — auto-discovered knowledge.
  T5 adds one; T3 edits many to delegate to scripts.
- **Agents** (`src/opencode/agent/*.md`) — T4 may add agents and/or AGENTS.md
  guidance.
- **Scripts** (`etc/scripts/src/ai/*.sh`) — reusable, version-controlled logic.
  T3 extracts script bodies here; T2 reuses `check-deps.sh` / `security-scan.sh`.
- **Keymaps** (`src/zellij/`, `etc/scripts/src/zellij/`) — T1 verifies the
  existing quad layout; no new keymap.
- **AGENTS.md** (`src/opencode/AGENTS.md`) — global rules; updated by T3
  (script registry table), T4 (agent guidance), and T5 (link to new skill).

## Data flow

There is no runtime data flow; the "data" is configuration consumed by the
OpenCode agent at prompt-assembly time:

1. User invokes a command (`/specify`, `/npm-audit-fix`) or the agent loads a
   skill on demand.
2. The command/skill prompt is injected into context; skills referencing scripts
   instruct the agent to run a script in `etc/scripts/src/ai/`.
3. Scripts emit minified JSON to stdout (and logs to stderr); the agent consumes
   the JSON instead of re-deriving the result via many tool calls.
4. AGENTS.md rules and the script registry table steer which assets the agent
   reaches for.

## Tasks

Ordered by recommended execution. Complexity and parallelism noted per task.

### T1 — Verify and document the 4-pane OpenCode keymap

- **Files:**
  - `src/zellij/config.kdl` (verify `Alt a` binding, line ~133) — read/verify only
  - `etc/scripts/src/zellij/open_opencode_quad.sh` — verify only
  - `src/zellij/layouts/opencode-quad.kdl` — verify only
  - `src/opencode/AGENTS.md` or repo docs — add a short note documenting the keymap
- **Changes:** Confirm `Alt a` (locked-mode) launches a new tab with the 4-pane
  `opencode-quad.kdl` layout via `open_opencode_quad.sh`, that the layout opens
  four `opencode` panes, and that `update_tab_indexes.sh` runs afterward. Record
  the keybinding + script + layout in a discoverable place.
- **Decision (clarified):** Verify/document only — do **not** add an nvim keymap
  or rework the layout.
- **Dependencies:** none.
- **Complexity:** small.
- **Parallel:** yes (independent).

### T2 — `/npm-audit-fix` OpenCode command

- **Files:**
  - `src/opencode/command/npm-audit-fix.md` (new command)
  - `src/opencode/AGENTS.md` — add to the command list + Utility Command Reference
- **Changes:** New slash command that drives the existing
  **security-npm-vulnerabilities** skill and reuses `check-deps.sh` (outdated +
  audit) and `security-scan.sh` (secret + dependency audit) rather than
  reimplementing audit logic. Workflow: detect package manager → run audit →
  classify by severity (per the skill) → apply safe fixes (`npm audit fix`) →
  surface breaking/forced fixes for confirmation → report.
- **Decision (clarified):** Reuse existing skill + scripts; no standalone audit
  logic. Command name `/npm-audit-fix`.
- **Dependencies:** none (skill + scripts already exist).
- **Complexity:** small–medium.
- **Parallel:** yes.

### T3 — Extract repeatable skill logic into scripts

- **Files:**
  - `etc/scripts/src/ai/*.sh` (new scripts, one per extracted operation)
  - `src/opencode/skills/<name>/SKILL.md` (edit skills to call the new scripts)
  - `src/opencode/AGENTS.md` — register new scripts in the AI Utility Scripts table
- **Changes:** Audit skills for embedded multi-step procedures that are
  deterministic and repeatable (data transforms, file processing, API calls,
  detection logic). Extract each into a `set -e` / `source utils/logging.sh` /
  `main "$@"` script emitting minified JSON, then rewrite the skill to instruct
  the agent to call the script. Follows the AGENTS.md "Prefer scripts over pure
  AI" rule.
- **Dependencies:** none, but should land before T4/T5 settle conventions so new
  assets follow the script-first pattern.
- **Complexity:** medium–large (scope depends on how many skills qualify).
- **Parallel:** partially — script extractions are independent of each other.

### T4 — Adopt net-new global-agent ideas

- **Files:**
  - `src/opencode/agent/*.md` (new agents only if a genuine gap exists)
  - `src/opencode/AGENTS.md` (guidance for primary vs subagent modes, delegation)
- **Changes:** Evaluate the Todoist proposal (build/plan/code-reviewer/
  security-auditor/docs-writer/steward) against the existing 17 agents. Map
  overlaps to existing agents (e.g., code-reviewer→`reviewer`,
  security-auditor→`auditor`, docs-writer→`documenter`, steward→`git`) and spec
  **only** the genuinely missing pieces — most likely the **primary** `plan` /
  `build` tab-  switchable modes and any permission-matrix guidance not already
  captured. Do not restructure the whole agent dir.
- **Decision (clarified):** Extract only net-new ideas; no full 6-agent
  restructure. **Guidance only** — add AGENTS.md guidance on primary/subagent
  modes + permission matrix; create no new agents.
- **Dependencies:** none.
- **Complexity:** medium.
- **Parallel:** yes.

### T5 — `inline-comments` skill

- **Files:**
  - `src/opencode/skills/inline-comments/SKILL.md` (new skill)
  - `src/opencode/AGENTS.md` — reference the skill where comment policy is relevant
- **Changes:** New skill defining when inline comments are useful and valid
  versus noise. The intent (per the task) is **not** a blanket ban — capture the
  cases where comments add value (non-obvious "why", workarounds, invariants,
  warnings, public API docs) and the cases to avoid (restating the code,
  commented-out code, redundant section banners). Include language-specific
  guidance consistent with **code-conventions** and **code-naming**.
- **Decision (clarified):** Skill name `inline-comments` (strictly inline
  `//`-style comments).
- **Dependencies:** none.
- **Complexity:** medium.
- **Parallel:** yes.

### T6 — `/specify` asks whether to review the plan

- **Files:**
  - `src/opencode/command/specify.md` (edit)
  - `src/opencode/command/specify-parallel.md` (edit, for parity — confirm scope)
- **Changes:** After the Post-Specification Clarification step completes, add a
  final step that asks the user (via the question tool) whether to run
  `/review-plans` on the freshly generated spec(s). If yes, hand off / invoke the
  review flow; if no, finish. Keep it as the last action so it does not interrupt
  the clarification loop.
- **Decision (clarified):** *Offer* (ask) — do not auto-run. Apply to **both**
  `specify.md` and `specify-parallel.md` for consistent behavior.
- **Dependencies:** none.
- **Complexity:** small.
- **Parallel:** yes.

## API contracts

Config-level "contracts" other assets depend on:

- **T2 command name:** `/npm-audit-fix` — filename `npm-audit-fix.md`, frontmatter
  `name: npm-audit-fix`, description starts with a verb.
- **T3 script convention:** each new script outputs minified JSON to stdout, logs
  via `log_*` to stderr, exits 0 on success, accepts `--help`, lives in
  `etc/scripts/src/ai/`, and is registered in the AGENTS.md script table.
- **T5 skill name:** `inline-comments` — directory + frontmatter `name` matching
  `^[a-z0-9]+(-[a-z0-9]+)*$`.
- **T4 agent frontmatter:** any new agent uses `mode: primary|subagent`, unquoted
  `description`, name matching its filename.

## State changes

- New file: `src/opencode/command/npm-audit-fix.md` (T2).
- New file(s): `etc/scripts/src/ai/*.sh` (T3).
- New file: `src/opencode/skills/inline-comments/SKILL.md` (T5).
- Possible new file(s): `src/opencode/agent/plan.md`, `src/opencode/agent/build.md` (T4, only if gaps confirmed).
- Edits to `src/opencode/AGENTS.md` (T2, T3, T4, T5) — keep the structure
  doc, command list, and script registry in sync.
- Edits to `src/opencode/command/specify.md` (+ `specify-parallel.md`) (T6).
- No database, env var, or runtime state changes.

## Edge cases

- **T1:** `Alt a` only fires inside zellij (`[[ -z "$ZELLIJ" ]] && exit 0`); the
  script also exits if `opencode` is not installed or the layout file is missing.
  Document these preconditions.
- **T2:** repos with no `package.json`, monorepo workspaces, and `npm audit fix`
  forcing breaking upgrades — gate forced fixes behind confirmation.
- **T3:** do not extract genuinely one-off or exploratory logic; avoid scripts
  that just wrap a single trivial command. Keep skill prose that explains
  judgment, move only mechanical steps.
- **T4:** avoid creating agents that duplicate existing ones; respect the
  "When to Use X (vs Y)" differentiation rule.
- **T5:** the skill must not contradict any existing "no comments" stance in
  AGENTS.md / code-conventions — **Decision:** the new skill **supersedes** any
  blanket no-comment stance; AGENTS.md links to it.
- **T6:** the prompt must not fire when `/specify` produced no spec files (e.g.,
  user aborted) and must offer a skip option.

## Testing approach

Validation is config-level, not unit tests:

- **Cross-cutting decision:** run `etc/scripts/src/ai/validate-opencode.sh`
  **after each config-touching task (T2/T4/T5)** and keep AGENTS.md in sync.
- Run `etc/scripts/src/ai/validate-opencode.sh` after T2/T4/T5 to confirm
  skills/commands/agents and AGENTS.md references are valid and not deprecated.
- For T3 scripts: run each with `--help`, run on a sample repo, and confirm valid
  minified JSON output (`| python3 -m json.tool`).
- For T1: manually trigger `Alt a` in a zellij session and confirm four opencode
  panes open with correct tab indexing.
- For T6: dry-run `/specify` end-to-end and confirm the review prompt appears
  last with a working skip path.

## Open questions

### Requirements
- **T3:** Which skills are the best extraction candidates? (Need a pass to
  enumerate qualifying multi-step procedures.)
- **T5:** Decision — scope is **inline `//`-style comments only**; docstrings /
  public-API doc comments are out of scope.

### Architecture
- **T4:** Decision — guidance only; no primary `plan`/`build` tab-modes. Capture
  permission-matrix + mode guidance in AGENTS.md.
- **T6:** Decision — *offer* (ask) to run `/review-plans`; do not auto-run.

### Scope
- **T6:** Decision — apply to **both** `specify.md` and `specify-parallel.md`.
- **T3:** Decision — **one-time extraction pass now + add an AGENTS.md
  convention** enforcing script-first for future skills.

### Conventions
- **T2:** Decision — command name `/npm-audit-fix`.
- **T5:** Decision — skill name `inline-comments`.

### Risks
- **T4:** Adding primary modes changes the Tab-cycle UX; confirm before adding.
- **T3:** Moving logic out of skills into scripts could reduce in-context
  explanation; ensure skills still explain *when* to run each script.

## References

- T1: https://app.todoist.com/app/task/check-keymap-to-generate-4-pane-opencode-6grHXjPW4fV9hgjF
- T2: https://app.todoist.com/app/task/create-opencode-npm-audit-fix-command-opencode-6grHXmpjg9XcX8jm
- T3: https://app.todoist.com/app/task/abstract-things-from-skills-that-can-be-a-script-out-and-make-the-skill-use-the-script-6grHjhFcWrJgqvjm
- T4: https://app.todoist.com/app/task/task-6grHq7CJ3CrCGHRm
- T5: https://app.todoist.com/app/task/make-good-skill-for-inline-comment-we-dont-want-to-ban-it-completely-but-want-to-use-where-the-usage-is-useful-and-valid-6grHqPR83cwP4MmF
- T6: https://app.todoist.com/app/task/after-specify-always-ask-if-should-review-the-plan-or-not-6grHqcV3HJWHPPfm
