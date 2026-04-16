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
   - If `$ARGUMENTS` contains `--major`, allow major version bumps (default: minor only)

3. Create a branch and worktree:
   - Use branch name `chore-pr-bump-<YYYYMMDD>`, append `-<HHMMSS>` if it already exists
   - Create the worktree with `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`

4. Bump packages in the worktree:
   - Run `npx npm-check-updates -u --target minor --jsonUpgraded` (or without `--target minor` if `--major`)
   - Parse the JSON output to build the bumped packages list with `{ package, fromVersion, toVersion }` entries
   - Detect the package manager and run install
   - If install fails, revert `package.json` changes, re-run ncu with `--reject <failing-packages>`, and install again — mark rejected packages as skipped with reason
   - If no bumps were applied, remove the worktree and local branch, notify the user, and stop
   - Stage and commit: `git add -A && git commit -m "⬆️ chore(deps): bump all packages to latest minor versions"`

5. Validate and review in the worktree:
   - Run lint, tests, and type checks
   - Launch **reviewer** and **auditor** agents in parallel against `git diff <base-branch>...HEAD`
   - If any check or agent reports critical issues, use **fixer** to resolve, stage and commit the fix, then re-run (max 2 iterations)
   - Do not proceed to PR creation until all checks pass

6. Push the branch:
   - `git push -u origin <branch-name>`

7. Create the PR:
   - Create a PR against `<base-branch>` with `gh pr create`
   - Use title `chore(deps): bump all packages to latest minor versions`
   - Include in the PR body: version bump table grouped by dependency type, skipped bumps with reasons, validation outcomes, and review findings

8. Report outcome to the user:
   - Branch name and worktree path
   - Created PR URL
   - Count of bumps applied and skipped

Important:
- All work happens in the worktree directory, never in the main repo
- Never force push
- If `gh pr create` fails, report the error and stop
- Do not modify the main repo's working tree
