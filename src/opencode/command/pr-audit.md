---
name: pr-audit
description: Bump all packages to latest minor versions, apply scoped audit fixes, and create a PR via a worktree
---

Usage: /pr-audit [$ARGUMENTS]

Bump all packages to their latest minor versions in a new worktree (skipping major bumps unless `--major` is passed), run audit fixes with overrides scoped to vulnerable ranges, validate the results, and open a PR.

$ARGUMENTS

Load the **worktree-workflow**, **git-workflows**, and **npm-vulnerabilities** skills in parallel.

1. Fetch latest changes:
   - Run `git fetch origin`

2. Determine scope from `$ARGUMENTS`:
   - If `$ARGUMENTS` contains `--base=<branch>`, use it as the base branch
   - Otherwise use the priority order from the **git-workflows** skill (`develop` > `main` > `master`)
   - If `$ARGUMENTS` contains `--major`, allow major version bumps (default: skip major bumps)

3. Check supply chain defenses using the **Supply Chain Attack Prevention** section of the **npm-vulnerabilities** skill:
   - Verify all recommended defenses are in place for the detected package manager
   - Run `npm audit signatures` to verify registry signature integrity
   - Report any missing defenses and offer to add them before proceeding

4. Create a branch and worktree:
   - Use branch name `fix-pr-audit-<YYYYMMDD>`
   - If that branch already exists, append `-<HHMMSS>` to keep it unique
   - Create the worktree with `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`

5. Bump all packages to their latest minor versions in the worktree:
   - Detect the package manager and bump all dependencies to latest minor versions (or latest if `--major` is passed)
   - Capture a before/after diff of `package.json` to build the list of bumped packages with `{ package, fromVersion, toVersion }` entries
   - If any package fails to install (e.g., peer dependency conflict), revert that package's bump, mark it as skipped with reason, and continue
   - Stage and commit: `git add -A && git commit -m "⬆️ chore(deps): bump all packages to latest minor versions"`

6. Remove stale overrides in the worktree:
   - Check each existing override in `package.json` to determine if the vulnerability it addressed still exists after the bumps
   - Remove overrides that are no longer needed, reinstall, and commit: `git add -A && git commit -m "🔧 chore(deps): remove stale overrides"`

7. Run dependency audit and apply fixes in the worktree:
   - Run audit, apply fixes, then run audit again to capture before/after vulnerability summaries
   - Scope all overrides to the vulnerable range (e.g., `">=2.3.1 <3"`) rather than blanket replacements — prefer upgrading the direct dependency when possible
   - Flag any major-version transitive overrides as compatibility risks in the PR body
   - If audit fixes or overrides changed files, stage and commit: `git add -A && git commit -m "🐛 fix(deps): resolve audit vulnerabilities"`
   - If no bumps were applied, no overrides were removed, and audit fixes produced no file changes, remove the worktree and local branch, notify the user, and stop

8. Run final validation in the worktree before creating the PR:
   - Run lint, tests, and type checks
   - If any check fails, use **fixer** to resolve the issue, stage and commit the fix, then re-run the failing check
   - Do not proceed to PR creation until all three checks pass

9. Review all changes before creating the PR:
   - Run `git diff <base-branch>...HEAD` in the worktree to capture the full diff
   - Launch **reviewer** and **auditor** agents in parallel against the diff
   - If either agent reports critical issues, use **fixer** to resolve them, stage and commit the fix, then re-run validation (step 8)
   - Include a summary of review findings in the PR body

10. Push the branch:
    - `git push -u origin <branch-name>`

11. Create the PR:
    - Create a PR against `<base-branch>` with `gh pr create`
    - Use title `chore(deps): bump minor versions and apply audit fixes`
    - Include in the PR body: version bump table grouped by dependency type, audit before/after summary, validation outcomes, and review findings

12. Report outcome to the user:
    - Branch name and worktree path
    - Created PR URL
    - Count of minor version bumps applied and skipped bumps
    - Count of stale overrides removed
    - Audit vulnerabilities resolved (if any)

Important:
- All work happens in the worktree directory, never in the main repo
- Never force push
- If `gh pr create` fails, report the error and stop
- Do not modify the main repo's working tree
