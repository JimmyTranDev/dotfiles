## Critical Code Writing Rule
**NO COMMENTS POLICY**: When writing, modifying, or generating code, do NOT add any comments. Write clean, self-documenting code with clear variable names, function names, and code structure that makes the intent obvious without explanatory comments. Comments clutter code, become outdated, and can mislead. Focus on readability through code structure, not comments.

## Universal Rules

- **Match existing conventions** — before writing new code, examine the surrounding codebase and follow its patterns exactly. Never introduce new conventions without explicit instruction.
- **Never create documentation files** (README, docs, markdown) unless explicitly asked.
- **Prefer editing over creating** — always modify existing files rather than creating new ones when possible.
- **Catppuccin Mocha** is the unified color theme across all tools.

## Worktree Workflow

**All code changes MUST happen in a git worktree.** Never modify code directly on `main` or `develop`. This applies to every task that modifies files — features, bug fixes, refactors, test additions, security fixes, and any other code changes.

### Process

1. **Detect the base branch**: Check for `develop` first (local or `origin/develop`), fall back to `main`
2. **Create a worktree**:
   ```bash
   git worktree add ~/Programming/Worktrees/<branch-name> -b <branch-name>
   ```
   - Branch name should be a short kebab-case description of the work (e.g., `add-dark-mode-toggle`, `fix-auth-race-condition`)
   - If the user provides a JIRA ticket, use the format `ABC-123-short-description`
3. **Do all work in the worktree directory** — read, edit, and create files in `~/Programming/Worktrees/<branch-name>/`, not the main repo
4. **Commit** in the worktree using the `git-workflows` skill commit format
5. **Merge back** into the base branch:
   ```bash
   git checkout <base-branch>
   git merge <branch-name>
   ```
6. **Clean up** the worktree and branch:
   ```bash
   git worktree remove ~/Programming/Worktrees/<branch-name>
   git branch -d <branch-name>
   ```

### When the User Overrides

If the user explicitly says to work in-place, skip the worktree workflow. Otherwise, always use it — even for small changes.
