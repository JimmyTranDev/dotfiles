## Critical Code Writing Rules
**NO COMMENTS POLICY**: When writing, modifying, or generating code, do NOT add any comments. Write clean, self-documenting code with clear variable names, function names, and code structure that makes the intent obvious without explanatory comments. Comments clutter code, become outdated, and can mislead. Focus on readability through code structure, not comments.

**ALWAYS USE BRACES**: Never write `if`/`else`/`for`/`while` statements without curly braces `{}`, even for single-line bodies. Braceless control flow is error-prone and fails linting.
- Wrong: `if (!cachedLoans) return [];`
- Right: `if (!cachedLoans) { return []; }`

## Clarification Before Action

When a user request is vague, ambiguous, or could be interpreted in multiple ways, **always ask clarifying questions before taking action**. Use the question tool to present concrete options when possible. Do not guess the user's intent — a quick clarification round is faster than redoing wrong work. Only skip clarification when the request is unambiguous and has a single obvious interpretation.

## Universal Rules

- **Match existing conventions** — before writing new code, examine the surrounding codebase and follow its patterns exactly. Never introduce new conventions without explicit instruction.
- **Prefer editing over creating** — always modify existing files rather than creating new ones when possible.
- **Use zsh** — when executing shell commands via the Bash tool, always use `zsh` syntax and builtins. This environment runs zsh as the default shell.
- **Todoist links** — when given a Todoist URL (`app.todoist.com/...`), always load the **tool-todoist-cli** skill and use the `td` CLI to interact with it (e.g., `td view <url>`, `td task view <url>`, `td task complete <url>`). Never use WebFetch or browser tools for Todoist URLs.
- **Always continue** — if there are remaining tasks, todos, or steps left to complete, keep working without stopping to ask for permission to continue. Only pause for user input when you need clarification or a decision, not when you simply have more work to do.
- **Java projects** — when working in a Java project, always load the **java-spring-senior** skill before making changes. Detect Java projects by the presence of `pom.xml`, `build.gradle`, `build.gradle.kts`, or `*.java` files.
- **100% test coverage** — when writing or modifying code, always ensure 100% unit test coverage for all affected code. This includes new code, modified functions, and any code paths touched by the changes. Load the **test** skill, write or update tests, and run them to verify full coverage before considering the task complete.
- **Improve skills from discoveries** — whenever reviewing, analyzing, auditing, fixing, or investigating code and you discover a reusable bug pattern, gotcha, pitfall, anti-pattern, or missing best practice, load the **meta-skill-learnings** skill and improve the relevant skill directly. Do not record learnings to a separate file — update skills so the knowledge is immediately available for future tasks.
- **Save useful scripts to dotfiles** — when creating a reusable utility script during a task, save it to `etc/scripts/ai/` in the dotfiles repo (`~/Programming/JimmyTranDev/dotfiles/etc/scripts/ai/`) rather than leaving it in the project directory. Scripts must follow existing conventions: `set -e`, source `common/logging.sh`, function-based structure. This makes scripts available across all projects.
- **Prefer scripts over pure AI** — when a task involves repeatable operations (data transformations, file processing, API calls, build steps, etc.), prefer creating a reusable script rather than performing the work entirely through AI tool calls. Scripts are version-controlled, reproducible, and runnable without AI. Only skip scripting when the task is truly one-off or exploratory.

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
│   ├── specify-architecture.md
│   ├── specify-audit.md
│   ├── specify-comments.md
│   ├── specify-design.md
│   ├── specify-devtools.md
│   ├── specify-engage.md
│   ├── specify-innovate.md
│   ├── specify-jira.md
│   ├── specify-logic.md
│   ├── specify-quality.md
│   ├── specify-review.md
│   ├── specify-test.md
│   ├── specify-useful.md
│   ├── pr-audit.md
│   ├── pr-group.md
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
    ├── comm-doc-writer/
    ├── comm-fsrs/
    ├── comm-spec-writer/
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
    ├── meta-skill-learnings/
    ├── meta-structure/
    ├── security/
    ├── security-npm-vulnerabilities/
    ├── strategy-career/
    ├── strategy-engager/
    ├── strategy-founding-sales/
    ├── strategy-innovate/
    ├── strategy-pragmatic-programmer/
    ├── strategy-criticize/
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
| `specify-*` | Analysis that writes structured specs to spec/ subfolders | Yes (spec files only) |
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

## `specify-*` Command Conventions

All `specify-*` commands follow these shared conventions. Individual commands only need to define their analysis categories, skill list, agent list, and spec filename prefix.

### Scope Detection
When the command receives `$ARGUMENTS`:
- If the user specifies files or directories, focus on those
- If the user describes a feature or area, search the codebase to locate the relevant code
- If no scope is given, analyze the full codebase (or the current branch's diff against the base branch if the command is review-oriented)

### Analysis-Only Guard
`specify-*` commands do NOT apply any changes — they are analysis-only. The only files they create are spec files.

### Spec File Output
After analysis, write findings to a markdown file in the **project root** `spec/` directory:
- Create the `spec/` directory at the workspace root if it doesn't exist
- Name the file with a clear, descriptive kebab-case name that communicates the analysis subject (e.g., `spec/review-auth-module.md`, `spec/security-payment-api.md`, `spec/quality-data-layer.md`)
- Use the command's prefix (the part after `specify-`) as the filename prefix
- If the filename already exists, append a numeric suffix (e.g., `spec/review-auth-module-2.md`)
- Write findings grouped by category, ranked by severity/impact, with file locations and suggested fixes
- Print a brief summary to chat: the spec file path, total findings count, and the top 3 most critical items

## `pr-*` Command Conventions

All `pr-*` commands follow these shared conventions. Individual commands only need to define their specific workflow.

### Worktree Setup
1. Load the **git-worktree-workflow** and **git-workflows** skills (plus any command-specific skills) in parallel
2. Determine the base branch using the priority order from the **git-workflows** skill (`develop` > `main` > `master`)
3. Derive a kebab-case branch name from the task description
4. Check for uncommitted changes: `git status --porcelain` and `git diff --cached --stat` (in parallel)
5. If there are staged or unstaged changes, stash them: `git stash push -m "<branch-name>"`
6. Create the worktree: `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`
7. If changes were stashed, apply in the worktree: `git stash pop`

### Review-Fix-Verify Cycle
After implementation, run this cycle:
1. Launch **reviewer**, **auditor**, and **tester** agents in parallel on the diff
2. If issues are found, launch **fixer** agents in parallel for independent fixes across different files
3. Stage and commit fixes: `git add -A && git commit -m "🐛 fix: address review and audit findings"`
4. Run **reviewer** once more to verify (max 2 iterations)

### PR Rules
- All work happens in the worktree directory, never in the main repo
- Do not modify the main repo's working tree
- If a stash pop has conflicts, notify the user and stop
- If `gh pr create` fails, report the error and stop
- If `$ARGUMENTS` contains a Todoist URL (`app.todoist.com/...`), complete the task: `td task complete <url>`
