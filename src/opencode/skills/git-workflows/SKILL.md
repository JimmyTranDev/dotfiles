---
name: git-workflows
description: Branch naming, commit conventions, PR workflows, worktree management, and base branch strategy
---

## Commit Message Format

`<emoji> <type>(<scope>): <description>`

- Scope is optional, in parentheses
- Description is lowercase sentence case, no trailing period
- Single line, no multi-line body (except worktree initial commits which include a JIRA link)

### Emoji Mapping

| Emoji | Type | Meaning |
|-------|------|---------|
| `✨` | `feat` | New features |
| `🐛` | `fix` | Bug fixes |
| `📚` | `docs` | Documentation changes |
| `🔨` | `refactor` | Code refactoring |
| `💎` | `style` | Formatting, styling |
| `🧪` | `test` | Adding/updating tests |
| `🚀` | `perf` | Performance improvements |
| `🔧` | `chore` | Maintenance tasks |
| `👷` | `ci` | CI/CD changes |
| `📦` | `build` | Build system changes |
| `⏪` | `revert` | Reverting changes |

### Examples from History

```
✨ feat(opencode): add pr-fix command and prefer develop as base branch
🐛 fix(zellij): filter nested layout template tabs from awk patterns
🔨 refactor: generate .gitconfig, settings.xml, and .npmrc from templates
🔧 chore(yazi): disable previews for non-plain-text file types
📚 docs: add tech stack section to README and kitty to Brewfile
⏪ revert(yazi): show hidden files by default
```

## Base Branch Strategy

Priority order: **`develop` > `main` > `master`**

- If a `develop` branch exists (locally or as `origin/develop`), it is the primary integration branch
- Feature branches are created from and merged back into `develop`
- Repos without `develop` use `main` as the base
- This applies to: code reviews, PR diffs, worktree creation, branch cleanup

## Branch Naming

- JIRA-based: `ABC-123` or `ABC-123-ticket-summary-text` (kebab-case)
- The pattern `[A-Z]+-[0-9]+` is used to extract ticket IDs from branch names
- Non-JIRA branches can use arbitrary descriptive names

## Worktree Workflow

The full worktree lifecycle is managed via `worktree` CLI (`etc/scripts/worktrees/`):

1. **Create** (`wn`): Select repo -> enter JIRA ticket -> fetch summary -> create branch -> create worktree at `~/Programming/Worktrees/<branch>` -> empty initial commit -> install deps
2. **Checkout** (`wo`): Checkout existing remote branch as worktree
3. **Work**: Branch from `develop` (preferred) or `main`
4. **Commit**: Use `/commit` (staged only) or `/commit-all` (session changes)
5. **Review**: Use `/review` to diff against base branch
6. **PR Fix**: Use `/fix-pr` to auto-fix PR review comments
7. **Clean** (`wC`): Delete worktrees merged into `main` or `develop`
8. **Delete** (`wD`): Manual deletion with multi-select via fzf

### Worktree Aliases

| Alias | Action |
|-------|--------|
| `wn` | Create new worktree (function — sources scripts, uses cd) |
| `wo` | Checkout remote branch as worktree (function) |
| `wD` | Delete worktree(s) |
| `wC` | Clean merged worktrees |
| `wr` | Rename current branch |
| `wu` | Update all worktrees (fetch + pull --rebase) |

## Git Configuration

- Default branch: `main`
- `push.autoSetupRemote = true` (auto upstream on push)
- Pager: `delta` with `catppuccin-mocha` theme, line numbers
- Editor: `nvim`
- Merge conflict style: `diff3`
- Global hooks path: `~/.config/git/hooks`

## Pre-commit Hook

A global pre-commit hook runs **TruffleHog** on all staged files to detect secrets:
- Blocks commit if secrets found (exit code 183)
- Skips if TruffleHog not installed
- Bypass with `git commit --no-verify`

## Files to Never Commit

- Files with `-actx` suffix (temporary symlinks from `select_git_folder_actx.sh`)
- `.env`, `credentials.json`, or other secrets files
- `copilot-instructions.md` (globally gitignored)

## GitHub CLI Usage

- `gh repo create <name> --private --source=. --push` for new repos
- `gh pr view` and `gh api` for PR review workflows
- `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments` for inline review comments
