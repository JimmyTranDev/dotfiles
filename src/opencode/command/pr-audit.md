---
name: pr-audit
description: Roll up Dependabot PRs, apply audit fixes, and create a draft PR
---

Usage: /pr-audit [$ARGUMENTS]

Create a new worktree branch, merge open Dependabot dependency PRs into it, apply dependency audit fixes, and open one draft rollup PR.

$ARGUMENTS

Load the **worktree-workflow**, **git-workflows**, and **npm-vulnerabilities** skills in parallel.

1. Determine scope from `$ARGUMENTS`:
   - If `$ARGUMENTS` contains `--base=<branch>`, use it as the base branch
   - Otherwise use the priority order from the **git-workflows** skill (`develop` > `main` > `master`)
   - If `$ARGUMENTS` contains `--match=<text>`, use it to filter Dependabot PRs by title/body

2. Check supply chain defenses (using the **Supply Chain Attack Prevention** section of the **npm-vulnerabilities** skill):
   - Detect package manager: check for `pnpm-lock.yaml` (pnpm) or `package-lock.json` (npm)
   - For pnpm projects: check `pnpm-workspace.yaml` for `minimumReleaseAge` (should be >= 10080) and `trustPolicy: no-downgrade`
   - For GitHub-hosted projects: check `.github/dependabot.yml` for `cooldown.default-days` (should be >= 7)
   - Run `npm audit signatures` to verify registry signature integrity
   - Report any missing supply chain defenses and offer to add them before proceeding

3. Discover open Dependabot PRs targeting the base branch:
   - Run `gh pr list --state open --base <base-branch> --limit 200 --json number,title,url,author,labels,body`
   - Keep only PRs where `author.login` is `app/dependabot` or `dependabot[bot]`
   - Split matches into:
     - Vulnerability PRs: title, body, or labels include `security`, `vulnerability`, `cve`, `ghsa`, or `dependabot alerts`
     - Update PRs: all remaining Dependabot PRs
   - Apply `--match=<text>` filter to both groups when provided
   - If no Dependabot PRs are found, continue with audit-only flow

4. Create a rollup branch and worktree:
   - Use branch name `fix-pr-audit-<YYYYMMDD>`
   - If that branch already exists, append `-<HHMMSS>` to keep it unique
   - Create the worktree with `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`

5. Merge each Dependabot PR in ascending PR number from inside the worktree:
   - If both Dependabot groups are empty, skip this step
   - Fetch each PR head with `git fetch origin pull/<pr-number>/head:dependabot-pr-<pr-number>`
   - Merge with `git merge --no-ff --no-edit dependabot-pr-<pr-number>`
   - Delete the temporary branch with `git branch -D dependabot-pr-<pr-number>`
   - If a merge conflicts, run `git merge --abort`, mark that PR as skipped, delete the temporary branch, and continue

6. Run dependency audit and apply fixes in the worktree:
   - If `pnpm-lock.yaml` exists, run `pnpm install`, `pnpm audit --json`, `pnpm audit --fix`, then `pnpm audit --json` again
   - Else if `package-lock.json` exists, run `npm install`, `npm audit --json`, `npm audit fix`, then `npm audit --json` again
   - Else skip audit and report that no supported lockfile was found
   - Capture before/after vulnerability summaries
   - If audit fixes changed files, stage and commit with `git add -A && git commit -m "🐛 fix(deps): resolve audit vulnerabilities"`

7. Verify results:
   - If no Dependabot PR was merged and audit fixes produced no file changes, remove the worktree and local branch, notify the user, and stop
   - Run available project checks in the worktree (tests/build/lint) and report any failures

8. Push and create the draft rollup PR:
   - `git push -u origin <branch-name>`
   - Create a draft PR against `<base-branch>` with `gh pr create --draft`
   - Use title `fix(deps): roll up dependabot updates and audit fixes`
   - Include in the PR body:
     - Merged vulnerability PR list (`#number title`)
     - Merged update PR list (`#number title`)
     - Skipped PR list with conflict reason (if any)
     - Audit before/after summary
     - Supply chain defense status (missing configurations noted)
     - Validation commands and outcomes

9. Close merged Dependabot update PRs:
   - For each merged update PR, run `gh pr close <pr-number> --comment "Superseded by <rollup-pr-url>"`
   - If closing any PR fails, report it and continue closing the rest

10. Report outcome to the user:
    - Rollup branch name and worktree path
    - Created PR URL
    - Count of merged vulnerability PRs, merged update PRs, and skipped PRs
    - Count of update PRs successfully closed

Important:
- All work happens in the worktree directory, never in the main repo
- Never force push
- If `gh pr create` fails, report the error and stop
- Do not modify the main repo's working tree
