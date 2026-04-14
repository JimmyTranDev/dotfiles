---
name: pr-audit
description: Bump all packages to latest minor versions, apply scoped audit fixes, and create a PR via a worktree
---

Usage: /pr-audit [$ARGUMENTS]

Bump all packages to their latest minor versions in a new worktree (skipping major bumps unless `--major` is passed), run audit fixes with overrides scoped to vulnerable ranges, validate the results, and open a PR.

$ARGUMENTS

Load the **worktree-workflow**, **git-workflows**, and **npm-vulnerabilities** skills in parallel.

1. Pull latest changes:
   - Run `git fetch origin` then pull `develop` and `main` (or `master`) branches to ensure they are up to date with the remote before auditing
   - For each branch that exists locally: `git checkout <branch> && git pull`
   - Return to the original branch after pulling

2. Determine scope from `$ARGUMENTS`:
   - If `$ARGUMENTS` contains `--base=<branch>`, use it as the base branch
   - Otherwise use the priority order from the **git-workflows** skill (`develop` > `main` > `master`)
   - If `$ARGUMENTS` contains `--major`, allow major version bumps (default: skip major bumps)

3. Check supply chain defenses (using the **Supply Chain Attack Prevention** section of the **npm-vulnerabilities** skill):
   - Detect package manager: check for `pnpm-lock.yaml` (pnpm) or `package-lock.json` (npm)
   - For pnpm projects: ensure `pnpm-workspace.yaml` matches this structure (preserving any existing `packages` entries but enforcing these fields):
     ```yaml
     packages:
       - 'packages/*'
     minimumReleaseAge: 10080
     minimumReleaseAgeExclude:
       - '@storeblocks/*'
       - '@storebrand-digital/*'
     trustPolicy: no-downgrade
     trustPolicyExclude: []
     ```
   - **Never** add new packages to `minimumReleaseAgeExclude` or `trustPolicyExclude` — keep only the existing entries shown above. If a package is too new to pass the minimum release age, wait for it to age out naturally or pin to an older version that already satisfies the age requirement. If a package fails the trust policy, investigate why (e.g., missing provenance, changed registry) and resolve at the source rather than excluding it.
   - Never add packages to `skipMinimumAge`
   - Never change `minimumReleaseAge` from `10080` -- this value is mandatory
   - For GitHub-hosted projects: ensure each entry in `.github/dependabot.yml` `updates` has `cooldown.default-days: 7` -- this value is mandatory
   - Run `npm audit signatures` to verify registry signature integrity
   - Report any missing supply chain defenses and offer to add them before proceeding

4. Create a branch and worktree:
   - Use branch name `fix-pr-audit-<YYYYMMDD>`
   - If that branch already exists, append `-<HHMMSS>` to keep it unique
   - Create the worktree with `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`

5. Bump all packages to their latest minor versions in the worktree:
   - For pnpm projects: run `pnpm update --no-save` to discover available updates, then `pnpm update` to apply all semver-compatible bumps
   - For npm projects: run `npx npm-check-updates --target minor -u` to update `package.json` to latest minor versions, then `npm install`
   - If `npx npm-check-updates` is not available, use `npm update` as a fallback
   - If `$ARGUMENTS` contains `--major`, use `--target latest` (npm-check-updates) or allow major bumps accordingly
   - Capture a before/after diff of `package.json` to build the list of bumped packages with `{ package, fromVersion, toVersion }` entries
   - If any package fails to install (e.g., peer dependency conflict), revert that package's bump, mark it as skipped with reason, and continue
   - Stage and commit: `git add -A && git commit -m "⬆️ chore(deps): bump all packages to latest minor versions"`

6. Run dependency audit and apply fixes in the worktree:
   - If `pnpm-lock.yaml` exists, run `pnpm audit --json`, `pnpm audit --fix`, then `pnpm audit --json` again
   - Else if `package-lock.json` exists, run `npm audit --json`, `npm audit fix`, then `npm audit --json` again
   - Else skip audit and report that no supported lockfile was found
   - After audit fix, inspect any `overrides` (pnpm) or `overrides` (npm) added to `package.json`:
     - If an override forces a major version jump on a transitive dependency (e.g., `picomatch 2.x→4.x`, `brace-expansion 2.x→5.x`), scope the override to only the vulnerable range instead of a blanket replacement — use `>=<minSafeVersion> <currentMajor+1` (e.g., `">=2.3.1 <3"` instead of `"4"`)
     - If scoping is not possible because no safe version exists within the current major, prefer upgrading the upstream direct dependency that pulls the vulnerable transitive, rather than forcing a cross-major override
     - If neither scoping nor upstream upgrade resolves the vulnerability, keep the major-version override but flag it in the PR body as a compatibility risk
   - Capture before/after vulnerability summaries
   - If audit fixes changed files, stage and commit with `git add -A && git commit -m "🐛 fix(deps): resolve audit vulnerabilities"`

7. Verify results:
   - If no bumps were applied and audit fixes produced no file changes, remove the worktree and local branch, notify the user, and stop

8. Run final validation in the worktree before creating the PR:
   - Run lint (`npm run lint` or `pnpm lint`), tests (`npm test` or `pnpm test`), and type checks (`npx tsc --noEmit` or `pnpm tsc --noEmit`)
   - If any check fails, use **fixer** to resolve the issue, stage and commit the fix, then re-run the failing check
   - Do not proceed to PR creation until all three checks pass

9. Review all changes before creating the PR:
   - Run `git diff <base-branch>...HEAD` in the worktree to capture the full diff
   - Launch **reviewer** and **auditor** agents in parallel against the diff
   - **reviewer**: evaluate code quality, correctness, and potential regressions introduced by the dependency changes
   - **auditor**: scan for security concerns such as new transitive dependencies, suspicious version jumps, or known vulnerability patterns
   - If either agent reports critical issues, use **fixer** to resolve them, stage and commit the fix, then re-run validation (step 8)
   - Include a summary of review findings in the PR body

10. Push the branch:
    - `git push -u origin <branch-name>`

11. Create the PR:
    - Create a PR against `<base-branch>` with `gh pr create`
    - Use title `chore(deps): bump minor versions and apply audit fixes`
    - Include in the PR body:
      - A `## Minor version bumps` section listing all packages bumped in step 5, grouped by dependency type (`dependencies`, `devDependencies`, `peerDependencies`) with a markdown table showing package, from, and to versions
      - Skipped bump list with reason (if any)
      - Major-version transitive overrides flagged as compatibility risks (if any)
      - Audit before/after summary
      - Supply chain defense status (missing configurations noted)
      - Validation commands and outcomes
      - Review findings summary from **reviewer** and **auditor** agents

12. Report outcome to the user:
    - Branch name and worktree path
    - Created PR URL
    - Count of minor version bumps applied and skipped bumps
    - Audit vulnerabilities resolved (if any)

Important:
- All work happens in the worktree directory, never in the main repo
- Never force push
- If `gh pr create` fails, report the error and stop
- Do not modify the main repo's working tree
