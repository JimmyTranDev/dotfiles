---
name: review
description: Review local uncommitted changes, a PR diff, or a branch diff for correctness and quality
---

Usage: /review [PR URL, branch name, or file/directory path]

$ARGUMENTS

## Mode Detection

Parse `$ARGUMENTS` to determine what to review:
- **PR mode** — argument is a GitHub PR URL or PR number → fetch the PR diff
- **Branch mode** — argument is a branch name → diff between that branch and base branch (`develop` > `main` > `master`)
- **File/directory mode** — argument is an existing file or directory path → review only changes in that path
- **Local mode** — no arguments → review the last commit's diff (`git diff HEAD~1..HEAD`). If the current branch has uncommitted changes, include those too by diffing against `HEAD~1`.

## Tech Stack Detection

Run `detect-stack.sh` to detect the project's tech stack and load skills accordingly:
- Java files (`.java`, `pom.xml`, `build.gradle`) → load **review-backend**
- TypeScript/React files (`.ts`, `.tsx`, `.jsx`) → load **review-frontend**
- React Native (`react-native` in package.json) → load **review-mobile**
- Shell scripts (`.sh`, `.zsh`) → load **meta-shell-scripting**
- Always load **code-follower**

Load all applicable skills in a single parallel batch.

## Local Mode

1. Get the last commit diff: `git diff HEAD~1..HEAD`
2. If there are uncommitted changes (`git status --porcelain`), also include `git diff` in the review
3. If no commits exist and no changes, notify the user and stop
4. Launch the **reviewer** agent on the diff

## Branch Mode

1. Run `git-branch-info.sh` and use the `BASE_BRANCH` value
2. Run `git diff <base-branch>...<branch-name>` to gather the full feature diff
3. Launch the **reviewer** agent on the diff

## File/Directory Mode

1. Run `git diff` and `git diff --cached` filtered to the specified path
2. If no changes in that path, notify the user and stop
3. Launch the **reviewer** agent on the filtered diff

## PR Mode

1. Fetch the PR diff using `gh pr diff <ref>`
2. Launch the **reviewer** and **auditor** agents in parallel on the diff
3. Deduplicate findings across agents before presenting

## Large Diff Handling

If the diff exceeds 1000 lines:
1. Split the diff by file
2. Review each file's changes separately
3. Combine findings at the end
4. Skip binary files and generated/vendored code with a note

## Output Format

Present findings with this structure:

```
## Review Summary
- 🔴 X critical | 🟡 Y important | 💡 Z suggestions
- Files reviewed: [list]
- Verdict: ship ✅ / fix first ⚠️ / needs rework 🚫

## Critical
🔴 **file.ts:45** — SQL injection via string concatenation
   Fix: Use parameterized query

## Important
🟡 **file.ts:78-92** — Function does 3 things, hard to test
   Fix: Split into separate functions

## Suggestions
💡 **file.ts:12** — Variable name `data` is vague
   Fix: Rename to `userProfile`

## Good Patterns Noticed
- Clean error handling in auth module
```

## Post-Review Fix Offer

IMPORTANT: Present all review findings first, then ask the user what to do. Wait for the user's response before making any edits. Never start fixing before the user has answered.

If any critical, important, or suggestion findings were reported, use the question tool to ask the user:
- **Yes, fix all** — launch the **fixer** agent on all findings (critical, important, and suggestions)
- **Yes, walk through one by one** — present each finding individually (critical first, then important, then suggestions) using the question tool, letting the user choose "Fix this", "Skip", or "Stop" for each one. Only fix the ones the user approves.
- **No** — end the review

Do NOT auto-stage or commit anything — this is review-only unless the user explicitly opts into fixing.

## Post-Review Checks

After the fix offer is resolved (or if no findings were reported), use the question tool to ask: "Run test, lint, and typecheck?" Options: "Yes, run all checks" / "No, skip checks".

If yes:
1. Run `detect-stack.sh` to determine available check commands
2. Run the following in parallel where available:
   - Tests: `run-tests.sh`
   - Lint: `lint-check.sh`
   - Typecheck: TypeScript projects use `npx tsc --noEmit`, Java projects use `mvn compile`, others skip
3. Report pass/fail for each check
4. If any check fails, update the review verdict to "fix first" and offer to fix the failures
5. If a check tool is not detected (no test runner, no linter, no typecheck), skip it and report "not available"
