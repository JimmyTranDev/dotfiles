---
name: pr-audit
description: Fix npm vulnerabilities in a worktree and create a PR with the dependency updates
---

Usage: /pr-audit [$ARGUMENTS]

Fix npm dependency vulnerabilities in a new git worktree, then create a pull request with the changes. If `$ARGUMENTS` is provided, use it as additional scope (e.g., "critical only", "--omit=dev").

$ARGUMENTS

Load the **worktree-workflow**, **git-workflows**, and **npm-vulnerabilities** skills.

1. Determine the base branch using the priority order from the **git-workflows** skill (`develop` > `main` > `master`)

2. Use `fix-npm-audit` as the branch name

3. Check for uncommitted changes on the current branch (run in parallel):
   - `git status --porcelain`
   - `git diff --cached --stat`

4. If there are staged or unstaged changes:
   - Stash them with `git stash push -m "fix-npm-audit"`

5. Create the worktree:
   - `git worktree add ~/Programming/wcreated/fix-npm-audit -b fix-npm-audit`

6. If changes were stashed in step 4:
   - Apply the stash in the worktree: `git stash pop` (run from the worktree directory)

7. Run the npm audit in the worktree directory:
   - Determine the scope from `$ARGUMENTS` (severity filter, `--omit=dev`, etc.). If no scope given, run a full audit.
   - Execute `npm audit --json` to get machine-readable vulnerability data
   - Parse the output to extract vulnerability count, severity breakdown, affected packages, and fix availability
   - If no vulnerabilities are found, notify the user, remove the worktree and branch, and stop

8. Triage using the **npm-vulnerabilities** skill decision tree:
   - Classify each vulnerability by severity (critical, high, moderate, low)
   - Determine if each is a direct or transitive dependency
   - Check if a fix is available (`fixAvailable` field)
   - Separate production vulnerabilities from dev-only vulnerabilities

9. Present findings to the user:
   - Summary table: count by severity, direct vs transitive, fix available vs no fix
   - For each critical/high vulnerability: package name, advisory URL, affected version range, and recommended action
   - Ask the user to confirm before applying fixes

10. Apply fixes incrementally, starting with the safest:
    - **Phase 1**: Run `npm audit fix` for semver-compatible auto-fixes
    - **Phase 2**: For remaining transitive vulnerabilities, add `overrides` to `package.json`
    - **Phase 3**: For direct dependencies with major version bumps available, present breaking changes and ask user before upgrading
    - Skip `npm audit fix --force` unless the user explicitly requests it

11. After each phase, verify:
    - Run `npm audit` to confirm vulnerability count decreased
    - Run `npm test` and `npm run build` (if available) to catch regressions
    - If a fix introduces test failures, revert the change and report the conflict to the user

12. Stage and commit the changes:
    - `git add -A`
    - `git commit -m "🔒 fix(deps): resolve npm audit vulnerabilities"`
    - If multiple phases produced separate logical changes, use separate commits per phase

13. Review and fix — launch **reviewer** and **auditor** agents in parallel:
    - Both agents analyze the diff from `git diff <base-branch>...HEAD`
    - **reviewer**: verify `package.json` and `package-lock.json` changes are correct and overrides are properly scoped
    - **auditor**: confirm no new security concerns were introduced by the dependency changes
    - Collect all issues found by both agents

14. If issues were found:
    - Launch **fixer** agents in parallel for independent fixes
    - After fixes are applied, stage and commit: `git add -A && git commit -m "🐛 fix(deps): address review findings"`
    - Run **reviewer** once more to verify (max 2 iterations)

15. Push and create the PR:
    - `git push -u origin fix-npm-audit`
    - Create the PR with `gh pr create` targeting the base branch:
      - Title: `🔒 fix(deps): resolve npm audit vulnerabilities`
      - Body: summary of vulnerabilities found, fixes applied, remaining unresolved issues, and verification results
    - Include a section listing any unresolved vulnerabilities with explanation

16. Report the PR URL to the user

Important:
- All work happens in the worktree directory, never in the main repo
- If the stash pop has conflicts, notify the user and stop
- If `gh pr create` fails, report the error but do not retry
- Do not modify the main repo's working tree
- If no vulnerabilities exist, clean up the worktree and branch before stopping
