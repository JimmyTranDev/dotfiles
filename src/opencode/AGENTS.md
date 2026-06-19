## Critical Code Writing Rules
**ALWAYS USE BRACES**: Never write `if`/`else`/`for`/`while` statements without curly braces `{}`, even for single-line bodies. Braceless control flow is error-prone and fails linting.
- Wrong: `if (!cachedLoans) return [];`
- Right: `if (!cachedLoans) { return []; }`

## Clarification Before Action

When a user request is vague, ambiguous, or could be interpreted in multiple ways, **always ask clarifying questions before taking action**. Use the question tool to present concrete options when possible. Do not guess the user's intent — a quick clarification round is faster than redoing wrong work. Only skip clarification when the request is unambiguous and has a single obvious interpretation.

## Universal Rules

- **Match existing conventions** — before writing new code, examine the surrounding codebase and follow its patterns exactly. Never introduce new conventions without explicit instruction.
- **Prefer editing over creating** — always modify existing files rather than creating new ones when possible.
- **Split files where it makes sense** — when implementing new functionality, prefer splitting into separate files by logical concern (e.g., one file per component, one file per utility, one file per hook) rather than cramming everything into a single file. Follow the single responsibility principle: each file should have one clear purpose. This applies to all code — commands, skills, components, utilities, configs. Only combine into a single file when the pieces are tightly coupled and would not make sense independently.
- **Use zsh** — when executing shell commands via the Bash tool, always use `zsh` syntax and builtins. This environment runs zsh as the default shell.
- **Todoist links** — when given a Todoist URL (`app.todoist.com/...`), always load the **tool-todoist-cli** skill and use the `td` CLI to interact with it (e.g., `td view <url>`, `td task view <url>`, `td task complete <url>`). Never use WebFetch or browser tools for Todoist URLs.
- **Todoist priority filter** — when a `p1`, `p2`, `p3`, or `p4` token appears alongside a Todoist section URL, use `triage-todoist.sh <url> --priority <p1|p2|p3|p4>` to fetch filtered tasks. The script handles the inverted API mapping internally. If no priority token is present, omit `--priority` to fetch all tasks.
- **Always continue** — if there are remaining tasks, todos, or steps left to complete, keep working without stopping to ask for permission to continue. Only pause for user input when you need clarification or a decision, not when you simply have more work to do.
- **Java projects** — when working in a Java project, always load the **java-spring-senior** skill before making changes. Detect Java projects by the presence of `pom.xml`, `build.gradle`, `build.gradle.kts`, or `*.java` files.
- **Save useful scripts to dotfiles** — when creating a reusable utility script during a task, save it to `etc/scripts/src/ai/` in the dotfiles repo (`~/Programming/JimmyTranDev/dotfiles/etc/scripts/src/ai/`) rather than leaving it in the project directory. Scripts must follow existing conventions: `set -e`, source `utils/logging.sh`, function-based structure. This makes scripts available across all projects.
- **Prefer scripts over pure AI** — when a task involves repeatable operations (data transformations, file processing, API calls, build steps, etc.), prefer creating a reusable script rather than performing the work entirely through AI tool calls. Scripts are version-controlled, reproducible, and runnable without AI. Only skip scripting when the task is truly one-off or exploratory.
- **Architecture decisions** — when making significant architectural decisions (technology choices, system design, data model changes), save them to an `architecture/` folder at the project root as ADR files. Use the format from the **comm-adr-writer** skill.
- **Jira tab title** — when a task has an associated Jira URL or ticket code, set the terminal/tab title to the Jira ticket code (e.g., `PROJ-123`) so the user can identify which task each tab is working on.
- **No emoji in commits** — never use emoji in commit messages. Use the format `<type>(<scope>): <description>` without any emoji characters.
- **Spec file naming** — when creating spec files in `plans/`, use descriptive kebab-case names that communicate the subject. Do not prefix with Jira ticket codes — use meaningful names like `plans/auth-session-timeout.md` instead of `plans/PROJ-123-auth-session-timeout.md`.
- **Cache invalidation** — Todoist and Jira caches in nvim should be auto-invalidated after 1 week. When interacting with stale cached data, refresh it.
- **Inline comments** — inline comments are not banned. Use them where they add value (non-obvious *why*, workarounds, invariants, warnings, magic values) and avoid them where they are noise (restating code, commented-out code, redundant banners). Load the **inline-comments** skill for the full policy. This supersedes any blanket no-comment stance.

## OpenCode Config Structure

```
src/opencode/
├── AGENTS.md               # Global LLM rules
├── opencode.jsonc           # OpenCode project config
├── tui.jsonc                # TUI appearance config
├── agent/                   # Specialized subagents
│   ├── auditor.md
│   ├── critic.md
│   ├── designer.md
│   ├── devops.md
│   ├── documenter.md
│   ├── engager.md
│   ├── fixer.md
│   ├── fullstacker.md
│   ├── git.md
│   ├── implementer.md
│   ├── migrator.md
│   ├── optimizer.md
│   ├── planner.md
│   ├── refactorer.md
│   ├── reviewer.md
│   ├── stock-researcher.md
│   └── tester.md
├── command/                 # Slash commands (/name)
│   ├── clarify-todoist.md
│   ├── clarify.md
│   ├── commit.md
│   ├── fix-conflict.md
│   ├── fix.md
│   ├── fms.md
│   ├── implement-frontend.md
│   ├── implement-parallel.md
│   ├── implement-sequential.md
│   ├── implement.md
│   ├── innovate-opencode.md
│   ├── insight.md
│   ├── learn-nvim.md
│   ├── learn-opencode.md
│   ├── learn.md
│   ├── merge.md
│   ├── npm-audit-fix.md
│   ├── opencode.md
│   ├── pr-parallel.md
│   ├── pr-reply.md
│   ├── pr-sequential.md
│   ├── pr.md
│   ├── refactor.md
│   ├── review-plans.md
│   ├── review.md
│   ├── simplify.md
│   ├── specify-parallel.md
│   ├── specify.md
│   ├── stock-advisor.md
│   ├── stock-calendar.md
│   ├── stock-reddit.md
│   ├── stock-research.md
│   ├── structure.md
│   ├── system-design.md
│   ├── triage-comments.md
│   ├── triage-todoist-section.md
│   ├── triage.md
│   ├── tutorial.md
│   └── weekly-summary.md
├── plugins/                 # Event-driven plugins
│   └── notification.js
└── skills/                  # On-demand knowledge (auto-discovered)
    ├── code-consolidator/
    ├── code-conventions/
    ├── code-deduplicator/
    ├── code-follower/
    ├── code-logic-checker/
    ├── code-quality/
    ├── code-simplifier/
    ├── code-soundness/
    ├── comm-doc-writer/
    ├── comm-spec-writer/
    ├── git-conflict-resolution/
    ├── git-gitignore/
    ├── git-workflows/
    ├── git-worktree-workflow/
    ├── implement-sequential/
    ├── inline-comments/
    ├── java-spring-senior/
    ├── mcp-browser/
    ├── mcp-mobile/
    ├── meta-agents-md/
    ├── meta-opencode-authoring/
    ├── meta-parallelization/
    ├── meta-shell-scripting/
    ├── meta-skill-learnings/
    ├── meta-structure/
    ├── performance-patterns/
    ├── pr-parallel/
    ├── pr-sequential/
    ├── review-backend/
    ├── review-output-format/
    ├── security/
    ├── security-npm-vulnerabilities/
    ├── strategy-career/
    ├── strategy-criticize/
    ├── strategy-engager/
    ├── strategy-founding-sales/
    ├── strategy-innovate/
    ├── strategy-pragmatic-programmer/
    ├── test/
    ├── test-android-db-inspector/
    ├── tool-drizzle-orm/
    ├── tool-eslint-config/
    ├── tool-github-actions/
    ├── tool-knip/
    ├── tool-local-ai/
    ├── tool-posthog-cli/
    ├── tool-psql/
    ├── tool-spring-boot/
    ├── tool-storybook-mcp/
    ├── tool-todoist-cli/
    ├── ts-total-typescript/
    ├── ui-accessibility/
    ├── ui-animator/
    ├── ui-designer/
    ├── ui-gamification/
    └── ui-stitch/
```

- `opencode.jsonc` loads `AGENTS.md` via its `instructions` array
- Agents in `agent/` are subagents launched via the Task tool
- Commands in `command/` are slash commands invoked with `/name`
- Skills in `skills/<name>/SKILL.md` are auto-discovered and loaded on demand via the Skill tool
- `~/.claude/` is **generated** on demand from this `src/opencode/` tree by `etc/scripts/src/ai/opencode-to-claude.sh` (default output `~/.claude/`, not tracked in the repo). OpenCode is the single source of truth — never hand-edit `~/.claude/`; edit here and re-run the converter to regenerate it.

## Agent Modes and Permission Matrix

A model's reasoning is sharpest when its context is narrow and focused. Split work across **primary** agents (the tab-cyclable workspace you interact with directly) and **subagents** (background specialists invoked via the Task tool or `@mention`) so each agent runs with a tight, single-intent context instead of one agent juggling mixed intents.

### Primary vs Subagent

| Mode | What it is | When to use |
|------|------------|-------------|
| `primary` | Tab-switchable agent you drive directly during a session | The two foundational loops: implementing (`build`-style) and planning (`plan`-style). Switch to a read-restricted planning mode for vague prompts or large migrations to brainstorm structure without risking destructive edits; switch to the implementing mode to turn a concrete plan into code. |
| `subagent` | Specialist launched in the background to guard the primary's context | Heavy, isolated, or read-only work — review, audit, docs, git/test chores. Delegate so the primary's context stays focused. All current agents in `agent/` are subagents. |

The current setup runs `permission` as `allow` globally (see `opencode.jsonc`) and treats every `agent/*.md` as a subagent. The matrix below is the **target permission profile per role** — apply it when scoping an agent's tools rather than granting blanket access.

### Role → Existing Agent Mapping

The common "global engineering team" roles already map to existing agents — reuse these instead of creating duplicates:

| Proposed role | Existing agent | Recommended permission profile |
|---------------|----------------|--------------------------------|
| `build` (implementer) | **implementer** / **fullstacker** | Full write/edit + raw bash — the workhorse |
| `plan` (strategist) | **planner** | Read-only; `edit`/`bash` set to `ask` or `deny` — outputs blueprints, never mutates |
| `code-reviewer` | **reviewer** | Read-only (`edit: deny`); `bash` limited to `git diff`/`git status` |
| `security-auditor` | **auditor** | Read-only + static-analysis bash only (`npm audit`, `semgrep`, `trivy`) |
| `docs-writer` | **documenter** | Write only to `*.md` / schema files; code files restricted |
| `steward` | **git** | Limited write; `bash` allowed for version control, commits, changelogs, local test runs |

### Guidance

- Prefer a **read-restricted planning pass** before a destructive implementation pass on vague or large-scope work.
- Scope each subagent's tools to the **minimum** its role needs (the matrix above) rather than relying on the global `allow` default.
- Do not create a new agent when an existing one covers the role — extend the existing agent's guardrails instead. See the "When to Use X (vs Y)" differentiation rule in agent files.

## Command Naming Taxonomy

| Prefix | Purpose | Makes Changes? |
|--------|---------|----------------|
| `specify-*` | Analysis that writes structured specs to plans/ subfolders | Yes (spec files only) |
| `fix-*` | Diagnose and fix specific problems | Yes |
| `implement-*` | Build new features or implement tasks | Yes |
| `pr-*` | Create/manage pull requests with worktrees | Yes |
| `tutorial-*` | Step-by-step interactive implementation | Yes |
| `triage-*` | Interactive walk-through of items with per-item decisions | Yes |
| `audit-*` | Analysis and reporting without producing spec files | No (output only) |
| (no prefix) | Utility commands (`commit`, `merge`, `init`, `review`, `clarify`, `quiz`, `fms`, `structure`, `migration-check`, `merge-specs`, `review-plans`) | Varies |

### Utility Command Reference

| Command | Purpose |
|---------|---------|
| `clarify` | Ask clarifying questions before implementation |
| `clarify-todoist` | Walk through Todoist tasks with per-task explain/downgrade/delete/skip options |
| `commit` | Create a well-formatted git commit |
| `fix` | Diagnose and fix a bug or issue |
| `fms` | Generate FMS translation JSON (Norwegian/English i18n keys) |
| `innovate-opencode` | Brainstorm and propose improvements to the local OpenCode config |
| `insight` | Generate insights from codebase patterns |
| `learn` | Create or update skills from session learnings |
| `merge` | Merge current branch into base |
| `npm-audit-fix` | Audit npm/pnpm dependencies and apply safe vulnerability fixes |
| `refactor` | Restructure code (extract, inline, rename, move, split, consolidate) preserving behavior |
| `review` | Review code for correctness |
| `review-plans` | Review plans/spec files for quality and completeness |
| `simplify` | Simplify and reduce complexity of selected code |
| `specify` | Generate implementation specs in plans/ |
| `structure` | Analyze and display project directory layout |
| `system-design` | Generate a system design document |
| `triage` | Interactive walk-through of items with per-item decisions |
| `triage-comments` | Triage PR review comments one by one |
| `triage-todoist-section` | Triage tasks from a Todoist section URL |
| `weekly-summary` | Generate weekly standup summary from git commits and Jira tickets |

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
- Examples: run **reviewer** and **auditor** in parallel on completed code, run **optimizer** and **tester** in parallel when both are explicitly requested
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

### Frontend vs Backend Sanity Check
Before deep analysis, evaluate whether the task is better suited for frontend or backend implementation:
- Consider where the logic naturally belongs (UI/UX vs data/business rules)
- Flag if the task is being assigned to the wrong layer (e.g., complex validation in the frontend that belongs in the backend, or rendering logic leaking into the backend)
- If the task spans both layers, note which parts belong where and call it out in the spec
- Include a brief "Layer recommendation" section at the top of the spec file stating frontend, backend, or full-stack with a one-line rationale

### Analysis-Only Guard
`specify-*` commands do NOT apply any changes — they are analysis-only. The only files they create are spec files.

### Todoist URL in Spec Frontmatter
If `$ARGUMENTS` contains a Todoist URL (`app.todoist.com/...`), embed it as `todoist: <url>` in the spec file's YAML frontmatter. Multiple URLs become a YAML list. Omit frontmatter entirely if no Todoist URL is present.

### Spec File Output
After analysis, write findings to a markdown file in the **project root** `plans/` directory:
- Create the `plans/` directory at the workspace root if it doesn't exist
- Name the file with a clear, descriptive kebab-case name that communicates the analysis subject (e.g., `plans/review-auth-module.md`, `plans/security-payment-api.md`, `plans/quality-data-layer.md`)
- Use the command's prefix (the part after `specify-`) as the filename prefix
- If the filename already exists, append a numeric suffix (e.g., `plans/review-auth-module-2.md`)
- Write findings grouped by category, ranked by severity/impact, with file locations and suggested fixes
- Print a brief summary to chat: the spec file path, total findings count, and the top 3 most critical items

## AI Utility Scripts

Reusable scripts in `~/Programming/JimmyTranDev/dotfiles/etc/scripts/src/ai/` replace common inline operations. Always prefer calling these scripts over reimplementing the same logic with multiple tool calls.

All scripts output **minified JSON** to stdout, log to stderr via `log_*` helpers, exit 0 on success, accept `--help`, and follow the `set -e` / `source utils/logging.sh` / `main "$@"` convention.

| Script | Purpose | Usage |
|--------|---------|-------|
| `detect-stack.sh [dir]` | Full tech stack detection (project type, PM, test runner, linter, CI, framework, monorepo, CSS, DB) | Replaces manual package.json/pom.xml inspection |
| `git-branch-info.sh [dir]` | Branch context (current/base branch, ahead/behind, uncommitted, staged) | Replaces multiple `git` calls for branch detection |
| `install-deps.sh [--frozen] [dir]` | Auto-detect package manager and install dependencies | Replaces manual lockfile inspection + install |
| `lint-check.sh [--fix] [dir]` | Auto-detect linter and run it (eslint/biome/ruff/clippy/checkstyle) | Replaces manual linter detection and execution |
| `run-tests.sh [dir]` | Auto-detect test framework and run tests with coverage | Replaces manual test runner detection |
| `uncommitted-coverage.sh [--no-run] [dir]` | Test coverage of currently-uncommitted (changed) lines vs the project coverage report | Replaces manual diff + coverage cross-referencing |
| `check-deps.sh [dir]` | Dependency outdated check + security audit | Replaces manual `npm outdated` / `npm audit` calls |
| `pr-status.sh [--mine]` | List open PRs with check/review/merge status | Replaces `gh pr list` + `gh pr view` chains |
| `scaffold-spec.sh <prefix> <name> [--todoist url] [--dir path]` | Create plans/*.md with standard sections | Replaces manual spec file boilerplate |
| `changelog.sh [from-ref] [to-ref]` | Generate grouped changelog from git history | Replaces manual commit categorization |
| `security-scan.sh [dir]` | Combined secret scanning + dependency audit | Replaces manual security checks |
| `validate-opencode.sh [opencode-dir]` | Validate skills, commands, agents, AGENTS.md refs, deprecated refs | Replaces manual config validation |
| `weekly-summary.sh [--since date] [--dir path]` | Gather git commits across repos with Jira ticket extraction | Replaces manual git log + Jira lookups |
| `fetch-pr-comments.sh [--resolved] [PR]` | Fetch PR review comments (inline + PR-level) | Replaces multiple `gh api` calls for PR comments |
| `fms-export-new.sh [--check-only] [dir]` | Extract new/modified FMS translation keys from git diffs | Replaces manual FMS key extraction |
| `nvim-open.sh <file...>` | Open files in existing nvim instance or start new one | Replaces manual nvim server detection |
| `diff-summary.sh [--base branch] [dir]` | Structured diff summary against base branch | Replaces 3-4 separate git diff/log calls |
| `fix-checks.sh [--pr number] [dir]` | Fetch failing CI checks with log content from GitHub | Replaces multiple `gh` API calls for CI failures |
| `worktree-clean.sh [--dry-run] [--dir root]` | Scan and auto-clean stale git worktrees | Replaces manual worktree inspection and cleanup |
| `pr-create.sh --branch name --title t --body b [--base] [--draft]` | Create worktree + push + PR via gh | Replaces multi-step git/gh PR creation plumbing |
| `triage-todoist.sh <section-url> [--priority p1-p4]` | Fetch and filter Todoist tasks for triage | Replaces multiple `td` CLI calls |
| `move-todoist-tasks.sh <source-url> <dest-url>` | Move all tasks from one Todoist section to another | Replaces manual task-by-task moving |
| `migration-check.sh [dir]` | Scan migration files for destructive SQL operations | Replaces manual migration file inspection |
| `android-db-inspect.sh <package> <db-name> [--serial serial]` | Pull a SQLite DB from an Android emulator and emit an integrity/FK/row-count report | Replaces manual adb pull + sqlite3 verification queries |
| `recover-pr.sh [--dir root]` | Match orphaned worktrees to PRs | Replaces manual worktree + PR matching |
| `format-check.sh [--fix] [dir]` | Auto-detect and run formatter (prettier/biome/black/gofmt/rustfmt) | Replaces manual formatter detection |
| `type-check.sh [dir]` | Auto-detect and run type checker (tsc/mypy/cargo check) | Replaces manual type checker detection |
| `build-check.sh [dir]` | Auto-detect and run build command | Replaces manual build tool detection |
| `verify-all.sh [--skip check] [dir]` | Run all checks (build, type, lint, format, test) and return aggregate pass/fail | Replaces running 5 check scripts individually |
| `scan-style.sh [dir]` | Gather file stats, naming patterns, and code samples for style analysis | Replaces manual file sampling |
| `spec-cleanup.sh <file>` | Remove consumed spec file after successful implementation with git-aware deletion | Replaces manual spec file cleanup |
| `version-bump.sh [minor\|major] [--dry-run] [--dir path]` | Bump minor or major version across all monorepo workspaces + app.json | Replaces manual version editing |
| `opencode-to-claude.sh [opencode-dir] [out-dir]` | Regenerate `~/.claude/` Claude Code config from `src/opencode/` (agents, commands, skills, CLAUDE.md, settings, hooks/notify.sh, and MCP servers in .mcp.json) | Replaces manual config porting; run after editing `src/opencode/` |

**When to use**: Any time a command or agent needs to detect the tech stack, find the base branch, run tests, run linting, install dependencies, check PR status, or perform any operation listed above — call the script instead of reimplementing with multiple tool calls.

### Script-First for Skills

When authoring or editing a skill, extract any embedded **deterministic, repeatable, multi-step procedure** (a fixed sequence of shell commands, API calls, or data transformations) into a reusable script in `etc/scripts/src/ai/` and have the skill instruct the agent to call the script. Keep prose that explains *judgment* — when to run each step, how to interpret results, decision trees, and reference tables — in the skill itself.

- Extract: mechanical command sequences that produce a deterministic result and are re-derived on every run (e.g., adb pull + sqlite3 verification → `android-db-inspect.sh`).
- Do NOT extract: one-off or exploratory logic, single trivial commands, or judgment-based decision trees and reference material.
- Before writing a new script, check the AI Utility Scripts table above — if an existing script already covers the operation, wire the skill to call it instead of duplicating the logic.
- Every extracted script must follow the convention: `set -e`, source `utils/common.sh` (or `utils/logging.sh`), emit minified JSON to stdout, log via `log_*` to stderr, accept `--help`, and be registered in the AI Utility Scripts table.

## Spec Cleanup and Todoist Completion

After successful implementation, all commands follow this convention for removing consumed spec files and completing Todoist tasks:

1. If `$ARGUMENTS` references a file in `plans/` (path starts with `plans/` or contains a `.md` file inside `plans/`), ask the user for confirmation before deleting the consumed spec file
2. If confirmed and the file is tracked by git, use `git rm`; otherwise use `rm`
3. If the `plans/` directory is empty after deletion, remove it too
4. Note in the final summary: "Removed consumed spec: plans/xyz.md"
5. If the consumed spec contains YAML frontmatter with a `todoist:` field, load the **tool-todoist-cli** skill and run `td task complete "<url>"` for each URL listed. Only complete after successful implementation. If implementation failed, do NOT complete the Todoist task.

## `pr-*` Command Conventions

All `pr-*` commands follow these shared conventions. Individual commands only need to define their specific workflow.

### Worktree Setup
1. Load the **git-worktree-workflow** and **git-workflows** skills (plus any command-specific skills) in parallel
2. Determine the base branch by running `git-branch-info.sh` and reading the `base_branch` field from JSON output
3. Derive a kebab-case branch name from the task description
4. Check for uncommitted changes: `git status --porcelain` and `git diff --cached --stat` (in parallel)
5. If there are staged or unstaged changes, stash them: `git stash push -m "<branch-name>"`
6. Create the worktree: `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`
7. If changes were stashed, apply in the worktree: `git stash pop`

### Review-Fix-Verify Cycle
After implementation, run this cycle:
1. Launch **reviewer** and **auditor** agents in parallel on the diff
2. If issues are found, launch **fixer** agents in parallel for independent fixes across different files
3. Stage and commit fixes: `git add -A && git commit -m "fix: address review and audit findings"`
4. Run **reviewer** once more to verify (max 2 iterations)

### Spec Cleanup
After successful implementation and PR creation, follow the **Spec Cleanup and Todoist Completion** convention above.

### PR Rules
- All work happens in the worktree directory, never in the main repo
- Do not modify the main repo's working tree
- If a stash pop has conflicts, notify the user and stop
- If `gh pr create` fails, report the error and stop
- If `$ARGUMENTS` contains a Todoist URL (`app.todoist.com/...`), complete the task: `td task complete <url>`
