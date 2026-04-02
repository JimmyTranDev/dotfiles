## Critical Code Writing Rule
**NO COMMENTS POLICY**: When writing, modifying, or generating code, do NOT add any comments. Write clean, self-documenting code with clear variable names, function names, and code structure that makes the intent obvious without explanatory comments. Comments clutter code, become outdated, and can mislead. Focus on readability through code structure, not comments.

## Universal Rules

- **Prefer editing over creating** — always modify existing files rather than creating new ones when possible.
- **Use zsh** — when executing shell commands via the Bash tool, always use `zsh` syntax and builtins. This environment runs zsh as the default shell.

## OpenCode Config Structure

```
src/opencode/
├── AGENTS.md               # Global LLM rules
├── opencode.json            # OpenCode project config
├── tui.json                 # TUI appearance config
├── agent/                   # Specialized subagents
│   ├── auditor.md
│   ├── browser.md
│   ├── designer.md
│   ├── engager.md
│   ├── fixer.md
│   ├── optimizer.md
│   ├── reviewer.md
│   └── tester.md
├── command/                 # Slash commands (/name)
│   ├── agents-md.md
│   ├── clarify.md
│   ├── comments.md
│   ├── commit.md
│   ├── design.md
│   ├── engage.md
│   ├── fix.md
│   ├── implement.md
│   ├── init.md
│   ├── innovate.md
│   ├── jira.md
│   ├── merge-conflict.md
│   ├── merge.md
│   ├── optimize.md
│   ├── pr-audit.md
│   ├── pr-fix.md
│   ├── pr-multiple.md
│   ├── pr.md
│   ├── quality.md
│   ├── review.md
│   ├── security.md
│   └── test.md
└── skills/                  # On-demand knowledge (auto-discovered)
    ├── accessibility/
    ├── agents-md/
    ├── browser-mcp/
    ├── career/
    ├── consolidator/
    ├── conventions/
    ├── deduplicator/
    ├── designer-ui-ux/
    ├── engager/
    ├── eslint-config/
    ├── follower/
    ├── fsrs/
    ├── gamification/
    ├── git-workflows/
    ├── gitignore/
    ├── innovate/
    ├── logic-checker/
    ├── mobile-mcp/
    ├── npm-vulnerabilities/
    ├── opencode-authoring/
    ├── parallelization/
    ├── pragmatic-programmer/
    ├── quality/
    ├── security/
    ├── shell-scripting/
    ├── simplifier/
    ├── stitch/
    ├── structure/
    ├── todoist-cli/
    ├── total-typescript/
    ├── ux-ui-animator/
    └── worktree-workflow/
```

- `opencode.json` loads `AGENTS.md` via its `instructions` array
- Agents in `agent/` are subagents launched via the Task tool
- Commands in `command/` are slash commands invoked with `/name`
- Skills in `skills/<name>/SKILL.md` are auto-discovered and loaded on demand via the Skill tool

## Parallelization

Maximize parallel execution at every level to reduce latency and total task time.

### Tool Calls
- When multiple tool calls have no data dependencies between them, issue them all in a single message as parallel calls
- Common parallel patterns: reading multiple files, running independent searches, launching independent agents, loading multiple skills
- Never serialize calls that could run concurrently — if tool B does not depend on tool A's output, call them together

### Skill Loading
- Load all needed skills in a single parallel batch at the start of a task — not one at a time sequentially
- Skills are read-only reference material with no side effects, so they are always safe to load in parallel

### Agent Delegation
- Launch independent subagents in parallel when their tasks do not depend on each other's output
- Examples: run **reviewer** and **auditor** in parallel on completed code, run **tester** and **optimizer** in parallel when both are needed
- Only serialize agent calls when one agent's output feeds into another (e.g., **fixer** depends on **reviewer** findings)

### Codebase Exploration
- When investigating unfamiliar code, batch related file reads and searches into parallel calls rather than reading one file at a time
- Use the Task tool with the **explore** agent for open-ended searches to avoid sequential tool call chains

### Git Operations
- Run independent git info commands in parallel (e.g., `git status`, `git diff`, `git log` can all run at once)
- Only serialize git commands that mutate state and depend on ordering (e.g., `git add` before `git commit`)
