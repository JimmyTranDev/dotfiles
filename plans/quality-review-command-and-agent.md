# Improve review.md Command and reviewer.md Agent

## Overview

The `/review` command and `reviewer` agent are functional but lack depth compared to other commands/agents in the config. The command is missing error handling, skill loading for different tech stacks, branch-mode review, and structured output. The agent is solid but could benefit from tech-stack-aware skill loading and a more structured workflow.

## Architecture

Both files live in the OpenCode config:
- `src/opencode/command/review.md` — slash command orchestrating the review workflow
- `src/opencode/agent/reviewer.md` — subagent containing review logic and output format

The command delegates to the agent. Improvements should keep this separation clean: the command handles mode detection, skill loading, and orchestration; the agent handles review logic and output formatting.

## Data flow

1. User invokes `/review [args]`
2. Command detects mode (local/PR/branch/file)
3. Command gathers the diff
4. Command loads relevant skills based on tech stack detection
5. Command launches reviewer (and optionally auditor) agent with the diff
6. Agent applies review checklist, self-validation, outputs structured findings
7. Command presents findings grouped by file and severity

## Tasks

### Task 1: Enhance review.md command

- **File**: `src/opencode/command/review.md`
- **Changes**: Rewrite to add missing modes and robustness
- **Complexity**: Medium
- **Parallel**: Yes (independent of Task 2)

Add these improvements:
1. **Branch mode** — argument is a branch name → review diff between that branch and base branch
2. **File/directory mode** — argument is a path → review only changes in that path (filter the diff)
3. **Tech stack skill loading** — detect project type and load appropriate skills:
   - Java files present → load **review-backend**
   - React/TS files → load **review-frontend**
   - React Native → load **review-mobile**
   - Always load **code-follower**
4. **Structured output section** — define how findings should be presented (summary count, grouped by file, severity indicators with emoji: 🔴 critical, 🟡 warning, 💡 suggestion)
5. **Context size handling** — for large diffs, instruct chunking by file and reviewing each chunk separately
6. **Post-review offer** — after presenting findings, ask if the user wants to auto-fix critical/important issues via the **fixer** agent

### Task 2: Enhance reviewer.md agent

- **File**: `src/opencode/agent/reviewer.md`
- **Changes**: Expand skills section, add workflow steps, improve output format
- **Complexity**: Medium
- **Parallel**: Yes (independent of Task 1)

Add these improvements:
1. **Expanded skill loading** — add conditional skills:
   - Java codebases → **review-backend**, **java-spring-senior**
   - Frontend codebases → **review-frontend**
   - Mobile codebases → **review-mobile**
   - Shell scripts → **meta-shell-scripting**
2. **Structured workflow** — add a numbered "How You Work" section (like the auditor agent has):
   - Scan the diff for scope understanding
   - Load applicable skills
   - Apply review checklist systematically
   - Self-validate findings
   - Format output
3. **Improved output format** — add a summary header before detailed findings:
   ```
   ## Summary
   - X critical, Y important, Z minor findings
   - Files reviewed: [list]
   - Overall assessment: [ship/fix-first/needs-rework]
   ```
4. **Overall verdict** — add a clear ship/no-ship recommendation with rationale
5. **Closing tagline** — add a memorable closing line (matches convention from auditor.md)

## API contracts

Not applicable — these are markdown config files, not code.

## State changes

No new state, config entries, or environment variables.

## Edge cases

- Very large diffs (1000+ lines) — command should instruct chunking
- Empty diff — command should detect and notify user early
- Binary files in diff — skip with note
- Review of generated/vendored code — skip with note
- Mixed tech stack (Java + React monorepo) — load multiple review skills

## Testing approach

Manual testing:
1. Run `/review` with no changes → verify "no changes" message
2. Run `/review` with local changes → verify findings output
3. Run `/review <PR-URL>` → verify PR mode works
4. Run `/review <branch-name>` → verify branch mode works
5. Run `/review src/some-file.ts` → verify file-scoped review

## Decisions

1. **Branch mode**: Compare against base branch (develop/main) — gives a full feature-branch review
2. **Post-review fix offer**: Always present when critical/important issues are found
3. **Quick mode**: No — single mode, self-validation is always valuable
4. **Stash review**: No — niche use case, not worth the complexity
