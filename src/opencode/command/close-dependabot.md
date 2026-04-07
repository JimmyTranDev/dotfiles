---
name: close-dependabot
description: Close all open Dependabot PRs targeting the base branch
---

Usage: /close-dependabot [--base=<branch>] [--match=<text>]

Close all open Dependabot PRs targeting the base branch. Use this after running `/pr-audit` to clean up Dependabot PRs whose version bumps are now covered by the audit PR.

$ARGUMENTS

Load the **git-workflows** skill.

1. Determine the base branch:
   - If `$ARGUMENTS` contains `--base=<branch>`, use it
   - Otherwise use the priority order from the **git-workflows** skill (`develop` > `main` > `master`)

2. Discover open Dependabot PRs:
   - Run `gh pr list --state open --base <base-branch> --limit 200 --json number,title,url,author,headRefName`
   - Keep only PRs where `author.login` is `app/dependabot` or `dependabot[bot]`
   - If `$ARGUMENTS` contains `--match=<text>`, filter PRs to only those whose title contains the match text
   - If no Dependabot PRs are found, notify the user and stop

3. Confirm with the user:
   - List all Dependabot PRs that will be closed (number, title, URL)
   - Show the total count
   - Ask the user to confirm before proceeding

4. Close each PR:
   - For each PR, run `gh pr close <number> --delete-branch`
   - If closing fails, report the error and continue to the next PR

5. Report a summary:
   - List each closed PR (number, title)
   - List any PRs that failed to close and why
   - Total closed vs total attempted

Important:
- Always confirm with the user before closing PRs
- Continue closing remaining PRs even if one fails
- Delete the remote branch with `--delete-branch` to keep the repo clean
