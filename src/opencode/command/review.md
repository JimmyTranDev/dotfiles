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
- **Local mode** — no arguments → review all local uncommitted changes
- If no arguments and no local changes exist, notify the user and stop

## Tech Stack Detection

Detect the project's tech stack from the diff and load skills accordingly:
- Java files (`.java`, `pom.xml`, `build.gradle`) → load **review-backend**
- TypeScript/React files (`.ts`, `.tsx`, `.jsx`) → load **review-frontend**
- React Native (`react-native` in package.json) → load **review-mobile**
- Shell scripts (`.sh`, `.zsh`) → load **meta-shell-scripting**
- Always load **code-follower**

Load all applicable skills in a single parallel batch.

## Local Mode

1. Run `git diff` and `git diff --cached` to gather all staged and unstaged changes
2. If no changes exist, notify the user and stop
3. Launch the **reviewer** agent on the combined diff

## Branch Mode

1. Determine the base branch (`develop` > `main` > `master`)
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

If any critical or important findings were reported, ask the user:
- **Yes, fix all** — launch the **fixer** agent on each critical/important finding
- **Yes, fix specific** — let the user pick which findings to fix
- **No** — end the review

Do NOT auto-stage or commit anything — this is review-only unless the user opts into fixing.
