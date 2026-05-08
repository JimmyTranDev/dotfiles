# Fix: Commit command model persists in session

## TL;DR

- The `/commit` command uses `model: github-copilot/claude-haiku-4.5` which persists after execution
- After running `/commit`, the main session stays on haiku instead of reverting to opus
- Fix: add `subtask: true` to commit command frontmatter so it runs as a subagent
- 1 file, 1-line change, small complexity

## Overview

The `/commit` command overrides the model to haiku for cost efficiency. However, because it runs in the primary agent context, the model override persists for the rest of the session. Adding `subtask: true` forces it to run as a subagent invocation, isolating the model change.

## Architecture

The commit command is defined at `src/opencode/command/commit.md`. OpenCode's command system supports a `subtask` frontmatter option that forces a command to run as a subagent, preventing it from polluting the primary context (including model selection).

## Data flow

1. User types `/commit`
2. OpenCode reads `commit.md` frontmatter, sees `model: github-copilot/claude-haiku-4.5`
3. With `subtask: true`: spawns a subagent with haiku, subagent completes, primary agent stays on opus
4. Without `subtask: true` (current): switches primary agent to haiku, which persists

## Tasks

| # | File | Change | Complexity | Parallel |
|---|------|--------|-----------|----------|
| 1 | `src/opencode/command/commit.md` | Add `subtask: true` to frontmatter | small | - |

## Edge cases

- If subtask mode prevents the commit command from seeing staged changes in the working directory — unlikely since subagents have the same filesystem access, but verify after implementation
- If subtask mode prevents the commit output from appearing in the main chat — per docs, subagent results are returned to the primary agent

## Testing approach

- Run `/commit` with staged changes, verify commit succeeds
- After commit, verify the model indicator in TUI shows opus (not haiku)

## Open questions

None — the fix is straightforward based on OpenCode's documented `subtask` option.
