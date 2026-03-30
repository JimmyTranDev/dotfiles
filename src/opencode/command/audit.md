---
name: audit
description: Scan npm dependencies for vulnerabilities, apply fixes in a worktree, and create a draft PR
---

Audit npm dependencies for known vulnerabilities, triage by severity, apply fixes in a worktree, and create a draft PR.

Usage: /audit [scope]

$ARGUMENTS

Load the **npm-vulnerabilities**, **worktree-workflow**, **git-workflows**, and **follower** skills in parallel.

1. Determine the scope:
   - If the user specifies a severity filter (e.g., "critical only"), apply `--audit-level` accordingly
   - If the user specifies `--omit=dev`, audit production dependencies only
   - If no scope is given, run a full audit of all dependencies

2. Run the audit:
   - Execute `npm audit --json` to get machine-readable vulnerability data
   - Parse the output to extract vulnerability count, severity breakdown, affected packages, and fix availability
   - If no vulnerabilities are found, notify the user and stop

3. Triage using the **npm-vulnerabilities** skill decision tree:
   - Classify each vulnerability by severity (critical, high, moderate, low)
   - Determine if each is a direct or transitive dependency
   - Check if a fix is available (`fixAvailable` field)
   - Separate production vulnerabilities from dev-only vulnerabilities

4. Present findings to the user:
   - Summary table: count by severity, direct vs transitive, fix available vs no fix
   - For each critical/high vulnerability: package name, advisory URL, affected version range, and recommended action
   - Ask the user to confirm before applying fixes

5. Set up the worktree:
   - Determine the base branch using the priority order from the **git-workflows** skill (`develop` > `main` > `master`)
   - Derive a branch name from the audit scope (e.g., `fix-npm-audit-vulnerabilities`, `fix-critical-npm-vulnerabilities`)
   - Create the worktree: `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`
   - Install dependencies in the worktree: `npm install` (run from the worktree directory)
   - All subsequent file edits happen in `~/Programming/wcreated/<branch-name>/`, not the main repo

6. Apply fixes incrementally in the worktree, starting with the safest:
   - **Phase 1**: Run `npm audit fix` for semver-compatible auto-fixes
   - **Phase 2**: For remaining transitive vulnerabilities, add `overrides` to `package.json`
   - **Phase 3**: For direct dependencies with major version bumps available, present breaking changes and ask the user before upgrading
   - Skip `npm audit fix --force` unless the user explicitly requests it

7. After each phase, verify:
   - Run `npm audit` to confirm vulnerability count decreased
   - Run `npm test` and `npm run build` (if available) to catch regressions
   - If a fix introduces test failures, revert the change and report the conflict to the user

8. Stage and commit the changes using the commit format from the **git-workflows** skill:
   - `git add -A`
   - `git commit -m "🐛 fix: resolve npm audit vulnerabilities"`

9. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **reviewer**: Verify that `package.json` and `package-lock.json` changes are correct and overrides are properly scoped
   - **tester**: Run the full test suite to confirm no regressions from dependency updates

10. If issues were found:
    - Use **fixer** to address each finding
    - Stage and commit fixes: `git add -A && git commit -m "🐛 fix: address review findings"`
    - Run **reviewer** once more to verify (max 2 iterations)

11. Push and create the draft PR:
    - `git push -u origin <branch-name>`
    - Create the PR with `gh pr create --draft` targeting the base branch
    - Title: `🐛 fix: resolve npm audit vulnerabilities`
    - Body: summary of vulnerabilities found, fixes applied, overrides added, and any unresolved vulnerabilities with explanations

12. Report the PR URL to the user and summarize:
    - Packages upgraded, overrides added, packages replaced
    - Remaining unresolved vulnerabilities with explanation of why they can't be auto-fixed and recommended manual actions

Important:
- All work happens in the worktree directory, never in the main repo
- If `gh pr create` fails, report the error but do not retry
- Do not modify the main repo's working tree
