---
name: worktree-workflow
description: Git worktree lifecycle for OpenCode — creating, working in, committing, rebasing, and cleaning up worktrees
---

## When to Use Worktrees

Use worktrees when the user explicitly mentions worktrees, asks to work in isolation, or references worktree-related aliases (`wn`, `wo`, `wD`, `wC`, `wu`, `wr`).

## Directory Layout

| Path | Purpose |
|------|---------|
| `~/Programming/Worktrees/<branch>` | All worktrees live here |
| `~/Programming/{Org}/{Repo}` | Main repository clones |
| `etc/scripts/worktrees/` | Worktree CLI scripts (zsh) |

## OpenCode Worktree Lifecycle

### 1. Create a Worktree

```bash
git worktree add ~/Programming/Worktrees/<branch-name> -b <branch-name>
```

- Detect the base branch: check for `develop` first (local or `origin/develop`), fall back to `main`
- Branch name: short kebab-case description (e.g., `add-dark-mode-toggle`, `fix-auth-race-condition`)
- JIRA ticket format: `ABC-123-short-description`

### 2. Work in the Worktree

- All file reads, edits, and creates happen in `~/Programming/Worktrees/<branch-name>/`, not the main repo
- Install dependencies if `package.json` exists (auto-detect npm/pnpm/yarn from lockfile)

### 3. Commit

Use the commit format from the `git-workflows` skill.

### 4. Rebase onto Base Branch

```bash
git rebase <base-branch>
```

### 5. Fast-forward the Base Branch

```bash
git checkout <base-branch>
git rebase <branch-name>
```

### 6. Clean Up

```bash
git worktree remove ~/Programming/Worktrees/<branch-name>
git branch -d <branch-name>
```

## Cleanup Operations

### Remove Specific Worktrees

1. Run `git worktree list` to show all active worktrees
2. For each worktree (excluding the main working tree), check for uncommitted changes via `git -C <path> status --porcelain`
3. Never remove the main working tree or the current working directory
4. If a worktree has uncommitted changes, warn and ask for confirmation
5. Capture the branch name before removing: `git worktree remove <path>`
6. Delete the associated branch: `git branch -d <branch-name>`
7. If branch is not fully merged, warn and ask before `git branch -D <branch-name>`
8. Run `git worktree prune` to remove stale references

### Clean Merged Worktrees

Check if each worktree's branch is an ancestor of `main` or `develop` (i.e., merged), then batch-delete confirmed ones.

## Shell Aliases

| Alias | Action |
|-------|--------|
| `wn` | Create new worktree (function — sources scripts, uses cd) |
| `wo` | Checkout remote branch as worktree (function) |
| `wD` | Delete worktree(s) with multi-select via fzf |
| `wC` | Clean merged worktrees |
| `wr` | Rename current branch (with optional JIRA integration) |
| `wu` | Update all worktrees (fetch + pull --rebase) |
| `Ctrl+G` | fzf widget to select and cd into a worktree |

## Safety Rules

- Never remove the main working tree
- Never remove the current working directory
- Always warn before removing worktrees with uncommitted changes
- Always warn before force-deleting unmerged branches
- Default to the safe option (skip) if the user declines confirmation
