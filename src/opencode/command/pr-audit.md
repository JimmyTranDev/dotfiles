---
name: pr-audit
description: Run dependency audit fixes with scoped overrides and create a PR via a worktree
---

Usage: /pr-audit [$ARGUMENTS]

Run dependency audit in a new worktree, apply fixes with overrides scoped to vulnerable ranges, validate the results, and open a PR.

$ARGUMENTS

Load the **git-worktree-workflow**, **git-workflows**, and **security-npm-vulnerabilities** skills in parallel.

1. Fetch latest changes:
   - Run `git fetch origin`

2. Determine scope from `$ARGUMENTS`:
   - If `$ARGUMENTS` contains `--base=<branch>`, use it as the base branch
   - Otherwise use the priority order from the **git-workflows** skill (`develop` > `main` > `master`)

3. Check supply chain defenses using the **Supply Chain Attack Prevention** section of the **security-npm-vulnerabilities** skill:
   - Verify all recommended defenses are in place for the detected package manager
   - Run `npm audit signatures` to verify registry signature integrity
   - Report any missing defenses and offer to add them before proceeding

4. Create a branch and worktree:
   - Use branch name `fix-pr-audit-<YYYYMMDD>`
   - If that branch already exists, append `-<HHMMSS>` to keep it unique
   - Create the worktree with `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`

5. Clean up stale overrides and age bypasses in the worktree:
   - Check each existing override in `package.json` to determine if the vulnerability it addressed still exists — remove overrides that are no longer needed
   - Check each `minimumReleaseAgeExclude` entry that was added as a temporary bypass (marked with a TODO in the PR body or commit history) — if the package version now satisfies the minimum release age, remove the exclusion
   - If any overrides or bypasses were removed, reinstall and commit: `git add -A && git commit -m "🔧 chore(deps): remove stale overrides and age bypasses"`

6. Run dependency audit and resolve vulnerabilities in the worktree using this priority order:
   a. **Bump the direct dependency** that pulls the vulnerable transitive — this is always preferred
   b. **Add a scoped override** pinning the transitive to a safe version within the vulnerable range (e.g., `">=2.3.1 <3"`) — use when the direct dependency hasn't released a fix yet
   c. **Bypass minimum release age** — if the only safe version is too new to pass `minimumReleaseAge`, add the package to `minimumReleaseAgeExclude` and add a `TODO: remove <package> from minimumReleaseAgeExclude after <date 7 days from now>` entry to the PR body so the next audit run cleans it up
   - Run audit, apply fixes using the priority order above, then run audit again to capture before/after vulnerability summaries
   - Flag any major-version transitive overrides as compatibility risks in the PR body
   - If audit fixes or overrides changed files, stage and commit: `git add -A && git commit -m "🐛 fix(deps): resolve audit vulnerabilities"`
   - If no overrides were removed, no bypasses were cleaned up, and audit fixes produced no file changes, remove the worktree and local branch, notify the user, and stop

7. Run final validation in the worktree before creating the PR:
   - Run lint, tests, and type checks
   - If any check fails, use **fixer** to resolve the issue, stage and commit the fix, then re-run the failing check
   - Do not proceed to PR creation until all three checks pass

8. Review all changes before creating the PR:
   - Run `git diff <base-branch>...HEAD` in the worktree to capture the full diff
   - Launch **reviewer** and **auditor** agents in parallel against the diff
   - If either agent reports critical issues, use **fixer** to resolve them, stage and commit the fix, then re-run validation (step 7)
   - Include a summary of review findings in the PR body

9. Push the branch:
   - `git push -u origin <branch-name>`

10. Create the PR:
    - Create a PR against `<base-branch>` with `gh pr create`
    - Use title `fix(deps): resolve audit vulnerabilities`
    - Include in the PR body:
      - Audit before/after summary
      - Stale overrides removed
      - Age bypasses added (with TODO dates for removal)
      - Age bypasses cleaned up from previous runs
      - Compatibility risks from major-version overrides
      - Validation outcomes and review findings

11. Report outcome to the user:
    - Branch name and worktree path
    - Created PR URL
    - Count of stale overrides removed
    - Count of age bypasses added and cleaned up
    - Audit vulnerabilities resolved

## Skill Improvement

After completing the work, load the **meta-skill-learnings** skill and improve any relevant skills with reusable patterns, gotchas, or anti-patterns discovered during the audit.

Important:
- All work happens in the worktree directory, never in the main repo
- Never force push
- If `gh pr create` fails, report the error and stop
- Do not modify the main repo's working tree
- Always prefer bumping the direct dependency over adding overrides
- Age bypasses are a last resort — always include a TODO with a removal date so the next `/pr-audit` run cleans them up
