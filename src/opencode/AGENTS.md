## Critical Code Writing Rule
**NO COMMENTS POLICY**: When writing, modifying, or generating code, do NOT add any comments. Write clean, self-documenting code with clear variable names, function names, and code structure that makes the intent obvious without explanatory comments. Comments clutter code, become outdated, and can mislead. Focus on readability through code structure, not comments.

## Universal Rules

- **Prefer editing over creating** — always modify existing files rather than creating new ones when possible.
- **Use zsh** — when executing shell commands via the Bash tool, always use `zsh` syntax and builtins. This environment runs zsh as the default shell.
- **Todoist links** — when given a Todoist URL (`app.todoist.com/...`), always load the **tool-todoist-cli** skill and use the `td` CLI to interact with it (e.g., `td view <url>`, `td task view <url>`, `td task complete <url>`). Never use WebFetch or browser tools for Todoist URLs.

## OpenCode Config Structure

```
src/opencode/
├── AGENTS.md               # Global LLM rules
├── opencode.json            # OpenCode project config
├── tui.json                 # TUI appearance config
├── agent/                   # Specialized subagents
│   ├── auditor.md
│   ├── designer.md
│   ├── engager.md
│   ├── fixer.md
│   ├── git.md
│   ├── implementer.md
│   ├── optimizer.md
│   ├── reviewer.md
│   └── tester.md
├── command/                 # Slash commands (/name)
│   ├── clarify.md
│   ├── clarify-agents-md.md
│   ├── clean-worktrees.md
│   ├── close-dependabot.md
│   ├── commit.md
│   ├── fix-ci.md
│   ├── fix-comments.md
│   ├── fix-conflict.md
│   ├── fix-pr.md
│   ├── fix.md
│   ├── implement-jira.md
│   ├── implement-sequential.md
│   ├── implement.md
│   ├── improve-agents-md.md
│   ├── improve-consolidate.md
│   ├── improve-optimize.md
│   ├── improve-security.md
│   ├── init.md
│   ├── merge.md
│   ├── plan-audit.md
│   ├── plan-design.md
│   ├── plan-devtools.md
│   ├── plan-engage.md
│   ├── plan-innovate.md
│   ├── plan-logic.md
│   ├── plan-quality.md
│   ├── plan-review.md
│   ├── plan-test.md
│   ├── plan-useful.md
│   ├── plan.md
│   ├── pr-audit.md
│   ├── pr-multiple.md
│   ├── pr-sequential.md
│   ├── pr.md
│   ├── review.md
│   ├── tutorial-implement-jira.md
│   └── tutorial.md
└── skills/                  # On-demand knowledge (auto-discovered)
    ├── code-consolidator/
    ├── code-conventions/
    ├── code-deduplicator/
    ├── code-follower/
    ├── code-logic-checker/
    ├── code-quality/
    ├── code-simplifier/
    ├── code-soundness/
    ├── comm-caveman/
    ├── comm-fsrs/
    ├── git-conflict-resolution/
    ├── git-gitignore/
    ├── git-workflows/
    ├── git-worktree-workflow/
    ├── mcp-browser/
    ├── mcp-mobile/
    ├── meta-agents-md/
    ├── meta-opencode-authoring/
    ├── meta-parallelization/
    ├── meta-shell-scripting/
    ├── meta-structure/
    ├── security/
    ├── security-npm-vulnerabilities/
    ├── strategy-career/
    ├── strategy-engager/
    ├── strategy-founding-sales/
    ├── strategy-innovate/
    ├── strategy-pragmatic-programmer/
    ├── strategy-usefulness-checker/
    ├── test/
    ├── test-android-db-inspector/
    ├── tool-drizzle-orm/
    ├── tool-eslint-config/
    ├── tool-knip/
    ├── tool-slack-cli/
    ├── tool-spring-boot/
    ├── tool-sqlite-local-sync/
    ├── tool-storybook-mcp/
    ├── tool-todoist-cli/
    ├── ts-total-typescript/
    ├── ui-accessibility/
    ├── ui-animator/
    ├── ui-designer/
    ├── ui-gamification/
    └── ui-stitch/
```

- `opencode.json` loads `AGENTS.md` via its `instructions` array
- Agents in `agent/` are subagents launched via the Task tool
- Commands in `command/` are slash commands invoked with `/name`
- Skills in `skills/<name>/SKILL.md` are auto-discovered and loaded on demand via the Skill tool

## Command Naming Taxonomy

| Prefix | Purpose | Makes Changes? |
|--------|---------|----------------|
| `plan-*` | Analysis, recommendations, findings | No |
| `improve-*` | Find issues and apply fixes/improvements | Yes |
| `fix-*` | Diagnose and fix specific problems | Yes |
| `implement-*` | Build new features or implement tasks | Yes |
| `pr-*` | Create/manage pull requests with worktrees | Yes |
| `tutorial-*` | Step-by-step interactive implementation | Yes |
| `clarify-*` | Ask targeted questions to refine requirements or config | No |
| (no prefix) | Utility commands (`commit`, `merge`, `init`, `review`, `clarify`) | Varies |

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
