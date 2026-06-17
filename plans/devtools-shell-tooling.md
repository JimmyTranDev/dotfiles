---
todoist:
  - https://app.todoist.com/app/task/make-move-between-panes-better-zellij-keymap-6grvCFRfQ7Cm6qXF
  - https://app.todoist.com/app/task/add-code-coverage-of-current-uncommited-code-checker-6gv2G8M8PQ3282Hq
  - https://app.todoist.com/app/task/add-rename-generic-update-commit-names-6gv2RfCc3jgJ5pXF
---

# Devtools: Shell & Terminal Tooling

## TL;DR
- Covers 3 p1 tasks: add `Alt+h/j/k/l` pane focus to Zellij, a shell script that reports test coverage of currently-uncommitted code, and a **separate opencode command** that scans git history for vague commits and rewrites them with the Haiku model.
- Touches `src/zellij/config.kdl`, adds a new script under `etc/scripts/src/ai/`, and adds a new command under `src/opencode/command/`.
- Most critical: the uncommitted-coverage checker (a reusable cross-project script) — highest leverage of the three.
- Estimated effort: ~half a day. Zellij binding is Small; coverage script is Medium; commit-rewrite command is Medium.

## Overview
Improve terminal/git ergonomics: make Zellij pane navigation use Vim-style `hjkl`, add a script that maps `git diff` (uncommitted changes) to test-coverage of the changed lines, and add a dedicated opencode command that scans recent git history for vague commit messages (e.g. `update`, `wip`) and rewrites them into descriptive conventional-commit messages using the Haiku model.

## Architecture
- **Zellij**: `src/zellij/config.kdl` — pane focus is currently `Alt left/down/up/right` → `MoveFocus` (config.kdl:141-144). Modes are KDL keybind blocks.
- **Scripts**: `etc/scripts/src/ai/` — convention is `set -e`, source `utils/logging.sh` (or `utils/common.sh`), function-based, `main "$@"`, minified JSON to stdout, logs to stderr, `--help`. Register new scripts in AGENTS.md's AI Utility Scripts table.
- **Commit rewriting**: a **new, separate** opencode command under `src/opencode/command/` (distinct from `/commit`, which crafts a single new message). It scans git history for vague commits and rewrites them, using Haiku for speed/cost. Note: rewriting historical commit messages requires `git rebase`/`git filter-branch` and rewrites history — handle with care (see edge cases / open questions).

## Data flow
- **Coverage checker**: `git diff --name-only` + per-file changed line ranges → run the project's coverage tool (auto-detected) → intersect changed lines with covered lines → emit a JSON summary of coverage % over uncommitted changes.
- **Commit rewrite command**: scan `git log` for commits whose messages match a "vague" heuristic (e.g. `update`, `wip`, `fix`, `stuff`, single-word) → for each, send the diff + old message to Haiku → produce a `<type>(<scope>): <desc>` replacement → rewrite history (interactive/`reword`) after user confirmation.

## Tasks
| # | File | Change | Complexity | Deps | Parallel? |
|---|------|--------|------------|------|-----------|
| 1 | `src/zellij/config.kdl` | Add `Alt h/j/k/l` → `MoveFocus left/down/up/right` in the relevant mode, alongside existing `Alt arrows` (config.kdl:141-144) | Small | None | Yes |
| 2 | `etc/scripts/src/ai/uncommitted-coverage.sh` (new) | Script: detect coverage tool (via `detect-stack.sh`/`run-tests.sh` patterns), compute coverage of lines changed in uncommitted diff, emit minified JSON | Medium | None | Yes |
| 3 | `src/opencode/command/rewrite-commits.md` (new) | New opencode command: scan git history for vague commit messages and rewrite them into conventional-commit format using the Haiku model; confirm before rewriting history | Medium | None | Yes |
| 4 | `AGENTS.md` (root + `src/opencode/AGENTS.md`) | Register `uncommitted-coverage.sh` in the AI Utility Scripts table | Small | 2 | Sequential after 2 |
| 5 | regenerate `~/.claude/` | Run `opencode-to-claude.sh` after the new command is added | Small | 3 | Sequential after 3 |

## API contracts
- `uncommitted-coverage.sh [dir]` → stdout minified JSON: `{"changed_lines":N,"covered":N,"coverage_pct":P,"files":[{"path":"...","pct":P}]}`. Exit 0 on success, `--help` supported.

## State changes
- New Zellij keybindings (no conflict with existing — `Alt h/j/k/l` currently unused in that mode; verify).
- New script file + AGENTS.md table row.

## Edge cases
- No uncommitted changes → script reports 0 changed lines, exits 0.
- Project has no coverage tooling → script logs a warning to stderr and exits non-zero or returns `coverage_pct: null`.
- `Alt h/j/k/l` already bound elsewhere in that Zellij mode → resolve conflict (verify against config.kdl before adding).
- Commit message already descriptive → rewrite command leaves it unchanged.
- **Rewriting pushed commits** → history rewrite requires force-push and breaks collaborators; the command must warn and default to local/un-pushed commits only.
- Merge commits / commits with no diff → skip.

## Testing approach
- Zellij: reload config, confirm pane focus moves with `Alt h/j/k/l` and arrows still work.
- Coverage script: run in a project with known coverage; assert JSON shape and a sane percentage; run in a repo with no changes (0 case) and no coverage tool (error case).
- Rewrite command: run on a throwaway branch with seeded vague commits; confirm only vague ones are reworded and history rewrite is gated behind confirmation.

## Open questions
### Architecture
- **Decision: the commit-rewrite tool is a separate opencode command** (`src/opencode/command/rewrite-commits.md`), not part of `/commit` and not an nvim keymap. It scans git history for vague commits and rewrites them using the **Haiku** model.
- **Coverage granularity (#6)** — **Decision: line-level** coverage of changed lines, falling back to file-level only if the tool can't map lines.

### Conventions
- **Coverage tool detection** — reuse `run-tests.sh`/`detect-stack.sh` rather than re-detecting. (Recommend: yes, call existing scripts.) — Decision pending.
- **Vague-commit heuristic & history-rewrite safety** — which messages count as "vague", and how far back to scan? Default to un-pushed commits only to avoid force-push hazards. (Recommend: scan commits ahead of upstream; treat single-word / `update`/`wip`/`fix`/`stuff` as vague.) — Decision pending.
