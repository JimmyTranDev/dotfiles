---
todoist: https://app.todoist.com/app/section/dotfiles-6f29Fcgcv4993gQG
---

# Worktree, Git & Config Improvements

## Overview

Improve worktree lifecycle management (delete without open PRs, always delete branch on cleanup, recover PRs, open multiple worktrees), fix commit/config conventions (remove emoji from commits, remove jira prefix from spec naming, keep jira code as tab title), add architecture folder convention, add GitHub webhook triggers, and add auto cache invalidation.

## Architecture

Mix of command modifications, new commands, AGENTS.md rule changes, and skill updates. Touches the git-worktree-workflow skill, commit command, specify conventions in AGENTS.md, and adds new utility commands.

## Data flow

- Worktree cleanup: `git worktree list` → filter by `gh pr list` → remove worktrees with no open PR → `git worktree remove` + `git branch -D`
- Recover PR: find orphaned remote branches → recreate worktree → resume work
- GitHub hooks: webhook → n8n/script → trigger OpenCode action in terminal

## Tasks

| # | File | Change | Complexity | Parallel? |
|---|------|--------|------------|-----------|
| 1 | `src/opencode/command/worktree-clean.md` | New file — delete all worktrees that don't have open PRs, always delete the associated branch too | medium | yes |
| 2 | `src/opencode/skills/git-worktree-workflow/SKILL.md` | Modify — add rule that worktree removal always deletes the branch. Update cleanup section | small | yes |
| 3 | `src/opencode/command/recover-pr.md` | New file — recover a PR by recreating worktree from remote branch, handling cases where local worktree was deleted | medium | yes |
| 4 | `src/opencode/command/open-worktrees.md` | New file — open multiple worktrees/projects in editor tabs or splits | small | yes |
| 5 | `src/opencode/command/commit.md` | Modify — remove emoji from commit format. Change from `<type>(<scope>): <emoji> <description>` to `<type>(<scope>): <description>` | small | yes |
| 6 | `src/opencode/AGENTS.md` | Modify — update commit format reference, remove emoji mapping table if present | small | depends on task 5 |
| 7 | `src/opencode/AGENTS.md` or specify conventions | Modify — remove jira prefix from spec file naming. Specs should use descriptive names only | small | yes |
| 8 | `src/opencode/AGENTS.md` | Modify — add rule: when working in a project with Jira integration, keep the Jira ticket code as the terminal/tab title | small | yes |
| 9 | `src/opencode/AGENTS.md` | Modify — add rule: save architecture decisions to `architecture/` folder at project root for significant decisions | small | yes |
| 10 | `src/opencode/command/github-hooks.md` | New file — setup and manage GitHub webhook triggers that invoke OpenCode commands (PR opened → auto-review, PR comment → auto-respond) | large | yes |
| 11 | `src/opencode/AGENTS.md` or cache-related config | Modify — add auto cache invalidation rule: cached data older than 1 week should be refreshed | small | yes |

## API contracts

`worktree-clean.md` workflow:
```
1. git worktree list --porcelain
2. gh pr list --state open --json headRefName
3. For each worktree not matching an open PR branch → remove + delete branch
4. Report: "Removed N worktrees: [list]"
```

`recover-pr.md` workflow:
```
1. gh pr list --author @me --state open --json headRefName,url
2. Show PRs without local worktrees
3. User selects which to recover
4. git worktree add ~/Programming/wcreated/<branch> <branch>
```

## State changes

- New commands: `worktree-clean.md`, `recover-pr.md`, `open-worktrees.md`, `github-hooks.md`
- Modified: `commit.md` (no emoji), `AGENTS.md` (multiple rule updates), `git-worktree-workflow` skill

## Edge cases

- `worktree-clean`: worktree has uncommitted changes — should warn and skip, not force-remove
- `recover-pr`: remote branch was force-pushed or rebased — need to handle divergence
- Commit emoji removal: existing commits in history still have emoji — this is fine, only affects new commits
- GitHub hooks: requires external infrastructure (n8n or similar) — command should handle setup instructions

## Testing approach

- Test `worktree-clean` with mix of worktrees (some with PRs, some without, some with uncommitted changes)
- Test `recover-pr` with an orphaned remote branch
- Test commit command produces emoji-free messages
- Verify AGENTS.md changes don't conflict with other rules

## Open questions

### Decisions
- Q1: Unanswered — default to prompting for confirmation (safer)
- Q2: Decision: GitHub Actions → n8n. GitHub Actions workflow triggers n8n webhook, which invokes OpenCode actions
- Q3: Decision: Todoist and Jira caches in nvim — auto-invalidate after 1 week
- Q4: Decision: Zellij tabs — open new tab per worktree
- Q5: Decision: When Jira URL is detected in the task
- Q6: Decision: Command + nvim keymap reference — update both
