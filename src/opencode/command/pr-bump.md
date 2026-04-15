---
name: pr-bump
description: Bump all packages to latest minor versions and create a PR via a worktree
---

Usage: /pr-bump [$ARGUMENTS]

Bump all packages to their latest minor versions in a new worktree (skipping major bumps unless `--major` is passed), validate the results, and open a PR.

$ARGUMENTS

Load the **git-worktree-workflow**, **git-workflows**, and **security-npm-vulnerabilities** skills in parallel.

1. Fetch latest changes:
   - Run `git fetch origin`

2. Determine scope from `$ARGUMENTS`:
   - If `$ARGUMENTS` contains `--base=<branch>`, use it as the base branch
   - Otherwise use the priority order from the **git-workflows** skill (`develop` > `main` > `master`)
   - If `$ARGUMENTS` contains `--major`, allow major version bumps (default: skip major bumps)

3. Create a branch and worktree:
   - Use branch name `chore-pr-bump-<YYYYMMDD>`
   - If that branch already exists, append `-<HHMMSS>` to keep it unique
   - Create the worktree with `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`

4. Bump all packages to their latest minor versions in the worktree:
   - Detect the package manager and bump all dependencies to latest minor versions (or latest if `--major` is passed)
   - Capture a before/after diff of `package.json` to build the list of bumped packages with `{ package, fromVersion, toVersion }` entries
   - If any package fails to install (e.g., peer dependency conflict), revert that package's bump, mark it as skipped with reason, and continue
   - If no bumps were applied, remove the worktree and local branch, notify the user, and stop
   - Stage and commit: `git add -A && git commit -m "⬆️ chore(deps): bump all packages to latest minor versions"`

5. Run final validation in the worktree before creating the PR:
   - Run lint, tests, and type checks
   - If any check fails, use **fixer** to resolve the issue, stage and commit the fix, then re-run the failing check
   - Do not proceed to PR creation until all three checks pass

6. Review all changes before creating the PR:
   - Run `git diff <base-branch>...HEAD` in the worktree to capture the full diff
   - Launch **reviewer** and **auditor** agents in parallel against the diff
   - If either agent reports critical issues, use **fixer** to resolve them, stage and commit the fix, then re-run validation (step 5)
   - Include a summary of review findings in the PR body

7. Push the branch:
   - `git push -u origin <branch-name>`

8. Create the PR:
   - Create a PR against `<base-branch>` with `gh pr create`
   - Use title `chore(deps): bump all packages to latest minor versions`
   - Include in the PR body: version bump table grouped by dependency type, skipped bumps with reasons, validation outcomes, and review findings

9. Report outcome to the user:
   - Branch name and worktree path
   - Created PR URL
   - Count of minor version bumps applied and skipped bumps

Important:
- All work happens in the worktree directory, never in the main repo
- Never force push
- If `gh pr create` fails, report the error and stop
- Do not modify the main repo's working tree
