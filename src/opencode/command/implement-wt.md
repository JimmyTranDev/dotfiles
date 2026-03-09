---
name: implement-wt
description: Implement changes in a git worktree with full lifecycle management
---

Usage: /implement-wt <description of what to implement>

Implement the required changes described below using a git worktree:

$ARGUMENTS

1. Parse the prompt to understand what needs to be implemented
2. Check if the changes described are already present in the codebase
3. If the changes are missing or incomplete, implement them according to the description
4. If the changes are already present, verify they match the description and suggest improvements if needed

After understanding the intent, load relevant skills and delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

Skills to load (load all applicable skills in a single parallel batch):
- **convention-matcher**: Always load to study existing codebase conventions (naming, imports, file structure, patterns) so all new code matches the established style
- **file-organizer**: Load when the task describes adding new modules, reorganizing files, or restructuring project layout
- **logic-checker**: Load when the task involves business logic, state machines, or complex conditional flows to verify logical soundness and catch impossible states
- **deduplicator**: Load when the task describes extracting shared utilities or reducing duplication across the codebase
- **simplifier**: Load when the task describes refactoring or simplification work — apply DRY, KISS, YAGNI principles
- **import-optimizer**: Load when the task describes cleaning up barrel files, fixing circular dependencies, or optimizing imports
- **prompt-writer**: Load when the task describes writing or updating AI system prompts or agent instructions

Agents to delegate to (launch independent agents in parallel — only serialize when one depends on another's output):
- **designer**: Use when the task describes UI component work, accessibility improvements, or frontend feature additions
- **fixer**: Use when the task describes a bug fix — let it trace the root cause and apply the minimal surgical fix
- **solver**: Use when the task describes a complex or multi-layered problem where the cause is unclear and deeper investigation is needed
- **tester**: Use when the task mentions adding or updating tests, or after implementing a feature to ensure proper test coverage
- **reviewer**: Use after implementation is complete to catch bugs, design issues, and maintainability problems before finalizing
- **optimizer**: Use when the task describes performance improvements — profile and implement measurable optimizations
- **auditor**: Use when the task describes security-related changes, authentication flows, or data handling to scan for vulnerabilities

Worktree Workflow:

1. **Detect the base branch**: Check for `develop` first (local or `origin/develop`), fall back to `main`
2. **Create a worktree**:
   ```bash
   git worktree add ~/Programming/Worktrees/<branch-name> -b <branch-name>
   ```
   - Branch name should be a short kebab-case description of the work (e.g., `add-dark-mode-toggle`, `fix-auth-race-condition`)
   - If the user provides a JIRA ticket, use the format `ABC-123-short-description`
3. **Do all work in the worktree directory** — read, edit, and create files in `~/Programming/Worktrees/<branch-name>/`, not the main repo
4. Analyze the prompt to categorize the type of work (feature, fix, refactor, test, security, performance, etc.)
5. Load all applicable skills in parallel (always include **convention-matcher**, add others based on task type)
6. Implement the changes in the worktree, delegating to the appropriate specialized agents based on the work type — launch independent agents in parallel
7. Run post-implementation agents in parallel where independent (e.g., **reviewer** + **auditor** together, **tester** + **optimizer** together)
8. If the reviewer surfaces problems, use the **fixer** agent to address them (sequential — depends on reviewer output)
9. **Commit** in the worktree using the `git-workflows` skill commit format
10. **Merge back** into the base branch:
    ```bash
    git checkout <base-branch>
    git merge <branch-name>
    ```
11. **Clean up** the worktree and branch:
    ```bash
    git worktree remove ~/Programming/Worktrees/<branch-name>
    git branch -d <branch-name>
    ```
