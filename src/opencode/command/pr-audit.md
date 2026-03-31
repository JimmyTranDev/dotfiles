---
name: pr-audit
description: Apply Dependabot version bumps and audit fixes in a worktree, then create a draft PR
---

Usage: /pr-audit [$ARGUMENTS]

Read open Dependabot PRs for version bump info, apply those bumps to `package.json` in a new worktree, run audit fixes, and open one draft rollup PR. Dependabot PRs are not merged or closed — they will auto-close when the rollup PR merges the same version changes into the base branch.

$ARGUMENTS

Load the **worktree-workflow**, **git-workflows**, and **npm-vulnerabilities** skills in parallel.

1. Pull latest changes:
   - Run `git fetch origin` then pull `develop` and `main` (or `master`) branches to ensure they are up to date with the remote before auditing
   - For each branch that exists locally: `git checkout <branch> && git pull`
   - Return to the original branch after pulling

2. Determine scope from `$ARGUMENTS`:
   - If `$ARGUMENTS` contains `--base=<branch>`, use it as the base branch
   - Otherwise use the priority order from the **git-workflows** skill (`develop` > `main` > `master`)
   - If `$ARGUMENTS` contains `--match=<text>`, use it to filter Dependabot PRs by title/body

3. Check supply chain defenses (using the **Supply Chain Attack Prevention** section of the **npm-vulnerabilities** skill):
   - Detect package manager: check for `pnpm-lock.yaml` (pnpm) or `package-lock.json` (npm)
   - For pnpm projects: check `pnpm-workspace.yaml` for `minimumReleaseAge` (should be >= 10080) and `trustPolicy: no-downgrade`
   - For GitHub-hosted projects: check `.github/dependabot.yml` for `cooldown.default-days` (should be >= 7)
   - Run `npm audit signatures` to verify registry signature integrity
   - Report any missing supply chain defenses and offer to add them before proceeding

4. Discover open Dependabot PRs targeting the base branch:
   - Run `gh pr list --state open --base <base-branch> --limit 200 --json number,title,url,author,labels,body`
   - Keep only PRs where `author.login` is `app/dependabot` or `dependabot[bot]`
   - Split matches into:
     - Vulnerability PRs: title, body, or labels include `security`, `vulnerability`, `cve`, `ghsa`, or `dependabot alerts`
     - Update PRs: all remaining Dependabot PRs
   - Apply `--match=<text>` filter to both groups when provided
   - If no Dependabot PRs are found, continue with audit-only flow

5. Extract version bump info from each Dependabot PR:
   - Parse the PR title and body to identify the package name and target version (e.g., "Bump express from 4.18.2 to 4.19.2")
   - Build a list of `{ package, fromVersion, toVersion, prNumber, prTitle, isVulnerability }` entries
   - If a package appears in multiple PRs, use the highest target version

6. Create a rollup branch and worktree:
   - Use branch name `fix-pr-audit-<YYYYMMDD>`
   - If that branch already exists, append `-<HHMMSS>` to keep it unique
   - Create the worktree with `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`

7. Apply all version bumps in the worktree:
   - For each extracted bump, update the version in `package.json` (`dependencies`, `devDependencies`, or `peerDependencies` as appropriate)
   - Always apply all Dependabot bumps — do not ask for confirmation
   - Reinstall dependencies: `pnpm install` or `npm install` depending on the detected package manager
   - If any bump fails to install (e.g., peer dependency conflict), revert that bump, mark it as skipped, and continue
   - Stage and commit: `git add -A && git commit -m "⬆️ fix(deps): bump dependencies from dependabot PRs"`

8. Run dependency audit and apply fixes in the worktree:
   - If `pnpm-lock.yaml` exists, run `pnpm audit --json`, `pnpm audit --fix`, then `pnpm audit --json` again
   - Else if `package-lock.json` exists, run `npm audit --json`, `npm audit fix`, then `npm audit --json` again
   - Else skip audit and report that no supported lockfile was found
   - Capture before/after vulnerability summaries
   - If audit fixes changed files, stage and commit with `git add -A && git commit -m "🐛 fix(deps): resolve audit vulnerabilities"`

9. Verify results:
   - If no bumps were applied and audit fixes produced no file changes, remove the worktree and local branch, notify the user, and stop

10. Run final validation in the worktree before creating the PR:
    - Run lint (`npm run lint` or `pnpm lint`), tests (`npm test` or `pnpm test`), and type checks (`npx tsc --noEmit` or `pnpm tsc --noEmit`)
    - If any check fails, use **fixer** to resolve the issue, stage and commit the fix, then re-run the failing check
    - Do not proceed to PR creation until all three checks pass

11. Review all changes before creating the PR:
    - Run `git diff <base-branch>...HEAD` in the worktree to capture the full diff
    - Launch **reviewer** and **auditor** agents in parallel against the diff
    - **reviewer**: evaluate code quality, correctness, and potential regressions introduced by the dependency changes
    - **auditor**: scan for security concerns such as new transitive dependencies, suspicious version jumps, or known vulnerability patterns
    - If either agent reports critical issues, use **fixer** to resolve them, stage and commit the fix, then re-run validation (step 10)
    - Include a summary of review findings in the PR body

12. Push and create the draft rollup PR:
    - `git push -u origin <branch-name>`
    - Create a draft PR against `<base-branch>` with `gh pr create --draft`
    - Use title `fix(deps): roll up dependency bumps and audit fixes`
    - Include in the PR body:
      - Group bumps by dependency type (`dependencies`, `devDependencies`, `peerDependencies`) with a summary header and markdown table for each group, e.g.:
        ```
        ## Bumps the development-dependencies group with 6 updates

        | Package | From | To |
        |---------|------|----|
        | @vitejs/plugin-react | 5.2.0 | 6.0.1 |
        | eslint | 9.39.4 | 10.1.0 |
        ```
      - If vulnerability bumps exist, list them in a separate section above update bumps with a `## Vulnerability fixes` header using the same table format
      - Skipped bump list with reason (if any)
      - Audit before/after summary
      - Supply chain defense status (missing configurations noted)
      - Validation commands and outcomes
      - Review findings summary from **reviewer** and **auditor** agents
      - Note: open Dependabot PRs will auto-close when this PR merges

13. Report outcome to the user:
    - Rollup branch name and worktree path
    - Created PR URL
    - Count of applied vulnerability bumps, applied update bumps, and skipped bumps
    - Remaining open Dependabot PRs that were not addressed (if any)

Important:
- All work happens in the worktree directory, never in the main repo
- Never force push
- Do not merge or close Dependabot PRs — they auto-close when the base branch contains the same version bumps
- If `gh pr create` fails, report the error and stop
- Do not modify the main repo's working tree
