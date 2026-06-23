---
name: worktree-management
description: Manages git worktrees across the ~/Programming/wcreated and ~/Programming/wcheckout directories using raw git commands. Use when creating a new branch worktree (wcreated), checking out an existing remote branch as a worktree (wcheckout), or deleting, updating, or cleaning these worktrees. Triggers on "create a worktree", "wcreated", "wcheckout", "checkout a branch as a worktree", "new worktree for ticket", "delete/prune worktrees", or any path under ~/Programming/wcreated or ~/Programming/wcheckout. Encodes the create-time Jira-ticket prompt (input or skip), the Jira branch naming, base-branch detection, and the wcreated-deletes-remote vs wcheckout-preserves-remote rules. Do NOT use for general commit/branch history work (use git-workflow-and-versioning) or for invoking the repo's worktree shell scripts.
---

# Worktree Management

## Overview

Two directories hold managed git worktrees, and they have **opposite ownership semantics**:

- **`~/Programming/wcreated`** — worktrees for branches **you create**. You own the branch, so deleting the worktree also deletes its **remote** branch.
- **`~/Programming/wcheckout`** — worktrees for **existing remote branches** you check out. Someone else (or a prior you) owns the branch, so deleting the worktree **preserves** the remote branch.

This skill performs every operation with **raw `git` commands**. Never shell out to `etc/scripts/.../worktree` or its command modules — they are reference only.

## When to Use

- Creating a new branch as a worktree (`wcreated`); always prompts for a Jira ticket (input or skip) to name the branch.
- Checking out an existing remote branch as a worktree (`wcheckout`).
- Deleting, updating (pull), or cleaning (prune merged) worktrees under either directory.
- Any task referencing a path under `~/Programming/wcreated` or `~/Programming/wcheckout`.

**Do NOT use when:**

- The task is ordinary commit/branch/merge/history work in a normal clone — use `git-workflow-and-versioning`.
- The user explicitly wants the `worktree` shell script run — this skill replaces it with git.

## Environment & Model

```
PROGRAMMING_DIR = ~/Programming            # source clones live at ~/Programming/<org>/<repo>
WCREATED_DIR    = ~/Programming/wcreated    # new branches you own
WCHECKOUT_DIR   = ~/Programming/wcheckout   # existing remote branches
JIRA_PATTERN    = ^[A-Z]+-[0-9]+$           # e.g. ABC-123
JIRA_HOST       = https://storebrand.atlassian.net/browse/<TICKET>
```

Honor any overriding `WCREATED_DIR` / `WCHECKOUT_DIR` / `PROGRAMMING_DIR` env vars if set. Org scan skips `Worktrees`, `wcreated`, `wcheckout`, `secrets`.

**Conventions:**

- **Base branch** — first that exists, in order: `develop` → `main` → `master` (`git -C <repo> rev-parse --verify <b>`).
- **Branch slug** — lowercase; every non-`[a-z0-9]` run → `-`; trim leading/trailing `-`.
- **Folder from branch** — strip the leading `segment/` (e.g. `feature/login` → `login`).
- **Unique dir** — if the target dir exists, append `-1`, `-2`, … until free.
- **Commit types** — any Conventional Commit type (see `git-workflow-and-versioning`).
- Resolve a worktree's main repo robustly with: `repo=$(dirname "$(git -C <worktree> rev-parse --path-format=absolute --git-common-dir)")` (underlying mechanism: the worktree's `.git` file holds `gitdir: <repo>/.git/worktrees/<name>`).

## Workflow

### A. wcreated — create a new branch worktree

1. **Pick the source repo** at `~/Programming/<org>/<repo>` and confirm it: `git -C <repo> rev-parse --is-inside-work-tree`.
2. **Find the base branch** (`develop`→`main`→`master`).
3. **Refresh base:** `git -C <repo> fetch origin`. If HEAD is on base with a clean tree, `git -C <repo> pull --rebase origin <base>` (stash → pull → `stash pop` if dirty). Otherwise fast-forward the ref only: `git -C <repo> fetch origin <base>:<base>`.
4. **Prompt for the Jira ticket, then decide the branch name.** Always ask first via the `question` tool — even if a ticket or name was already supplied — offering a **Skip (no ticket)** option and letting the user type a ticket key (or branch name) into the answer field. From the reply:
   - **A ticket key** (matches `^[A-Z]+-[0-9]+$`): optionally fetch the summary —
     `acli jira workitem view <TICKET> --json --fields summary | jq -r '.fields.summary'` —
     then `branch=<TICKET>-<slug(summary)>` (fall back to `<TICKET>` if `acli`/`jq` absent or empty).
   - **Skip, or a non-ticket name:** use that name (or the original input) directly. Sanitize to `[A-Za-z0-9._-]`.
5. **Choose a commit type** (any Conventional Commit type — see Conventions above).
6. **Compute the path:** `dir=<WCREATED_DIR>/<branch>` (unique-suffixed); `mkdir -p <WCREATED_DIR>`.
7. **Create worktree + new branch off base:**
   `git -C <repo> worktree add -b <branch> <dir> <base>`
8. **Seed an empty commit** (so the branch is pushable/PR-able immediately):
   ```
   git -C <dir> commit --allow-empty -m "<type>: <TICKET> <summary>

   Jira: https://storebrand.atlassian.net/browse/<TICKET>"
   ```
   Without a ticket: `<type>: <original input>` and no Jira footer.
9. **Install deps** if a lockfile exists: `pnpm-lock.yaml`→pnpm, `yarn.lock`→yarn, `bun.lock`/`bun.lockb`→bun, `package-lock.json`→npm; fall back to `npm install` if the manager is missing.
10. `cd <dir>`.

### B. wcheckout — check out an existing remote branch

1. **Pick the source repo** and confirm it is a git repo.
2. `git -C <repo> fetch origin`.
3. **List remote branches** and choose one:
   `git -C <repo> branch -r | sed -n 's|^[[:space:]]*origin/||p' | grep -vE '^HEAD' | sort`
4. **Compute the path:** `folder=<branch without leading segment/>`; `path=<WCHECKOUT_DIR>/<folder>` (unique-suffixed); `mkdir -p <WCHECKOUT_DIR>`.
5. **Create the worktree:**
   - Local branch already exists: `git -C <repo> worktree add <path> <branch>`.
   - Otherwise create a tracking branch: `git -C <repo> worktree add <path> -b <branch> origin/<branch>`.
6. **Install deps** (same detection as A.9); `cd <path>`.

The defining trait: this worktree tracks an existing `origin/<branch>`. Deletion must **not** touch the remote.

### C. Delete a worktree (ownership-aware)

1. **Classify by location** (this drives remote handling):
   - Path under `WCREATED_DIR` → **delete the remote branch too**.
   - Path under `WCHECKOUT_DIR` → **preserve the remote branch**.
2. **Resolve the main repo:** `repo=$(dirname "$(git -C <path> rev-parse --path-format=absolute --git-common-dir)")`.
3. **Detect the branch:** `branch=$(git -C <path> branch --show-current)`.
4. **Remove the worktree:** `git -C <repo> worktree remove <path>` (add `--force` if dirty); if the dir is already gone, `git -C <repo> worktree prune`.
5. **Delete the local branch:** `git -C <repo> branch -D <branch>`.
6. **wcreated only:** `git -C <repo> push origin --delete <branch>`.
7. Remove any leftover directory.

### D. Update all worktrees (pull)

Enumerate worktrees: `ls -1d <WCREATED_DIR>/*/ <WCHECKOUT_DIR>/*/ 2>/dev/null`. For each:
skip if HEAD is detached, the tree is dirty (`git -C <wt> diff-index --quiet HEAD`), or it has no upstream (`git -C <wt> rev-parse --abbrev-ref '@{u}'`). Otherwise:
`git -C <wt> fetch origin` then `git -C <wt> pull --rebase origin <branch>`; on conflict, `git -C <wt> rebase --abort` and report.

### E. Clean merged worktrees (prune)

For each worktree, fetch its repo, then test whether its branch is merged into the base or `develop`:
`git -C <repo> merge-base --is-ancestor <branch> origin/<base>` (also try `origin/develop` when present). If merged, delete it via **Workflow C** so the wcreated/wcheckout remote semantics still apply. Confirm before batch-deleting.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Deleting a checkout worktree should also delete the remote." | No. `wcheckout` branches are owned elsewhere — only `wcreated` deletions push `--delete`. Location decides. |
| "I'll just call the `worktree` script, it already does this." | The user asked for raw git, not the script. Use the commands here. |
| "Skip the empty seed commit." | The empty commit makes a `wcreated` branch immediately pushable/PR-able; it is part of the flow. |
| "A ticket or name was already given, so I can skip the prompt." | `wcreated` **always** prompts for the Jira ticket first (input or skip) — the prompt is a required step, not an optional nicety. |
| "Put the new branch in wcheckout / the checkout in wcreated." | The directory encodes ownership and deletion behavior. Created → `wcreated`; existing remote → `wcheckout`. |
| "Branch the worktree off the current HEAD." | `wcreated` branches off the freshly-updated base (`develop`/`main`/`master`), not whatever is checked out. |
| "Force-remove the dir with `rm -rf` first." | Use `git worktree remove` so git's metadata stays consistent; only `rm` leftovers afterward. |

## Red Flags

- Running `git push origin --delete` for a worktree under `wcheckout`.
- Invoking `etc/scripts/.../worktree` or sourcing its command modules instead of running git.
- Creating a `wcreated` branch off the current HEAD instead of the updated base branch.
- `rm -rf`-ing a worktree without `git worktree remove` / `git worktree prune`.
- Creating a `wcreated` worktree without first prompting for the Jira ticket (input or skip).
- Naming a Jira branch without checking the `^[A-Z]+-[0-9]+$` pattern.
- Resolving the main repo by hand-parsing `.git` when `git rev-parse --git-common-dir` is available.

## Verification

- [ ] New worktree exists at the correct directory (`wcreated` for created branches, `wcheckout` for checked-out remotes) and `git -C <dir> rev-parse --is-inside-work-tree` succeeds.
- [ ] For `wcreated`: branch was created off the updated base and has an empty seed commit (`git -C <dir> log --oneline -1`).
- [ ] For `wcheckout`: branch tracks `origin/<branch>` (`git -C <dir> rev-parse --abbrev-ref '@{u}'`).
- [ ] On delete: worktree gone from `git -C <repo> worktree list`; local branch removed; remote deleted **only** for `wcreated`.
- [ ] No worktree shell script was invoked; every step used raw `git`.
