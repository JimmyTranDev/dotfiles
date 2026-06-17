---
name: rewrite-commits
model: github-copilot/claude-haiku-4.5
description: Scan git history for vague commit messages and rewrite them into conventional-commit format
---

Usage: /rewrite-commits [count | commit-range | branch]

Scan recent git history for vague, low-information commit messages (e.g. `update`, `wip`, `fix`, `stuff`, single-word messages) and rewrite them into descriptive `<type>(<scope>): <description>` messages based on each commit's actual diff.

$ARGUMENTS

Load the **git-workflows** skill for the commit message format and conventional-commit types.

## Scope

- If `$ARGUMENTS` is a number `N`, scan the last `N` commits.
- If `$ARGUMENTS` is a commit range (`A..B`) or a single ref, scan that range.
- If `$ARGUMENTS` is empty, scan only commits **ahead of upstream** (un-pushed): `git log @{upstream}..HEAD --oneline`. If there is no upstream, fall back to commits ahead of the base branch (`develop` > `main` > `master`, via `git-branch-info.sh`). Never scan beyond un-pushed commits by default — rewriting pushed history requires a force-push and breaks collaborators.

## Workflow

1. **Safety check**: Determine which commits are un-pushed.
   - If the requested scope includes commits that already exist on the remote (`git branch -r --contains <sha>` is non-empty), WARN the user that rewriting them rewrites published history and requires a force-push. List the affected commits and use the question tool to confirm before proceeding. Default to NO.
   - If the working tree is dirty, warn and stop — the rebase needs a clean tree.

2. **Identify vague commits**: For each commit in scope, run `git log --format=%H%x09%s` and flag a message as vague when it:
   - Is a single word (`update`, `wip`, `fix`, `stuff`, `misc`, `temp`, `test`, `changes`, `cleanup`).
   - Is shorter than ~15 characters or has no scope/description detail.
   - Does not already follow `<type>(<scope>): <description>` with a meaningful description.
   - Skip merge commits (`git rev-list --merges`) and commits whose diff is empty.
   - Leave already-descriptive conventional-commit messages unchanged.

3. **Generate replacements**: For each vague commit, read its diff (`git show <sha> --stat` plus `git show <sha> -- . ':!*.csv'` for content) and compose a new message:
   - Format: `<type>(<scope>): <description>` — lowercase description, no trailing period, single line, no emoji.
   - Pick the type from the diff (feat/fix/refactor/docs/style/test/perf/chore/ci/build/revert).
   - Preserve any `[A-Z]+-[0-9]+` Jira ticket key already present in the old message by placing it after the colon: `<type>(<scope>): TICKET-123 description`.

4. **Confirm**: Present the proposed `old -> new` mapping for every commit to be reworded. Use the question tool to get final approval before touching history.

5. **Rewrite**: Apply the approved rewordings.
   - For the single most-recent commit only: `git commit --amend -m "<new message>"`.
   - For older commits: perform a non-interactive reword via `git rebase`. Set the sequence/commit editors so the rebase rewords only the targeted SHAs and leaves every other commit untouched, e.g.:
     `GIT_SEQUENCE_EDITOR='sed -i "" -E "s/^pick (<sha7>)/reword \1/"' GIT_EDITOR='<script that writes the new message>' git rebase -i <base>`
   - Apply one commit at a time and stop on any rebase conflict; report the conflict and do not continue automatically.

6. **Report**: Summarize each commit reworded (old -> new), any skipped (merge/empty/already-good), and remind the user to force-push **with lease** (`git push --force-with-lease`) only if they explicitly chose to rewrite already-pushed commits.

## Constraints

- Default to un-pushed commits only. Never force-push automatically.
- Never rewrite merge commits or commits with no diff.
- Never change commit content, author, or dates — only the message.
- No emoji in commit messages.
- If any rebase step conflicts, stop and report; do not abort or improvise.
