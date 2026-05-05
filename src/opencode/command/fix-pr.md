---
name: fix-pr
description: Address PR review feedback, resolve merge conflicts, and update the PR description
---

Usage: /fix-pr [$ARGUMENTS]

Take care of PR review feedback, clean up merge conflicts, and keep the PR description fresh. If `$ARGUMENTS` is given, focus on those specific things. Otherwise, go through all open review comments and handle them one by one.

Load the **git-workflows** skill for commit conventions.

1. Make sure there's actually a PR for this branch:
   - Run `gh pr view --json number,title,url,state,headRefName,baseRefName,reviewDecision`
   - If there's no PR, let the user know and stop
   - If the PR is already merged or closed, let the user know and stop

2. Pull together all the context (run these in parallel):
   - `gh pr view --json comments,reviews,reviewRequests` to grab PR-level comments and reviews
   - `gh api repos/{owner}/{repo}/pulls/{number}/comments` to grab inline review comments
   - `git diff $(gh pr view --json baseRefName -q .baseRefName)...HEAD` to see what's changed
   - `git log --oneline $(gh pr view --json baseRefName -q .baseRefName)..HEAD` to see the commit history on this branch

3. Look through all the feedback:
   - Go through review comments, inline code comments, and requested changes
   - Figure out which ones are still unresolved
   - If `$ARGUMENTS` was provided, focus on those first
   - If there are no `$ARGUMENTS` and nothing unresolved, run **reviewer** and **auditor** in parallel on the diff to spot any improvements
   - If a review comment is unclear, ask the user what the reviewer likely meant before trying to fix it

4. Walk through each unresolved comment — show the comment text and file location, then let the user pick how to handle it:
   - **Fix it**: Apply the suggested change (move on to step 5)
   - **Answer it**: Offer 3-5 thoughtful reply options as a multiple-choice list. Include responses like "Already handled by X", "This is intentional — here's why", "Good catch, will address in a follow-up PR", "Out of scope for this change", or a custom response. Post the chosen reply via `gh api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies -f body="<reply>"`
   - **Close it**: Offer 3-5 polite dismissal options as a multiple-choice list. Include responses like "Considered this — acceptable trade-off for now", "Not applicable to this particular change", "Covered by a different comment above", "Respectfully disagree — here's my reasoning", or a custom response. Post the chosen reply via `gh api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies -f body="<reply>"`

5. Check for merge conflicts:
   - Run `git fetch origin` then `git merge origin/<base-branch> --no-commit --no-ff` to test
   - If there are conflicts:
     - Show all conflicted files
     - Resolve each one by looking at both sides and picking the right resolution
     - Stage resolved files with `git add <file>`
     - Wrap up with `git commit -m "🔨 refactor: resolve merge conflicts with <base-branch>"`
   - If everything merges cleanly, abort the test merge with `git merge --abort`

6. Plan the fixes:
   - Group related issues together so they make sense as a unit
   - Show the user a summary of what's about to change
   - Get a thumbs-up before moving forward

7. Make the fixes:
   - Apply changes to address each issue
   - Launch **fixer** agents in parallel for independent fixes across different files

8. Double-check everything — launch **reviewer** and **auditor** in parallel:
   - Both look at the updated diff from `git diff <base-branch>...HEAD`
   - If they spot new issues, fix those too (up to 2 rounds)

9. Stage and commit:
   - `git add -A`
   - `git commit -m "<emoji> <type>(<scope>): <description>"` following the **git-workflows** skill format
   - Write a commit message that captures what was fixed (e.g., `🐛 fix(auth): address pr review feedback`)

10. Push it up:
    - `git push`
    - If the push fails, let the user know what went wrong

11. Freshen up the PR description:
    - Generate an updated PR body from the branch's commit history: `git log --oneline $(gh pr view --json baseRefName -q .baseRefName)..HEAD`
    - Include a clear summary of the overall changes
    - Update with `gh pr edit <number> --body "<updated body>"`

12. Wrap up with a summary:
    - What issues were addressed
    - Whether merge conflicts were resolved
    - Which commit(s) were created
    - A link to the updated PR

Ground rules:
- Never force push unless the user explicitly asks for it
- If a push fails because of remote changes, pull and retry once before flagging it
- If the PR has required checks failing, mention that in the summary
- After fixing a comment, draft a friendly reply explaining what was done and show it to the user for approval before posting via `gh api`
- Never close or resolve review comment threads — only reply to them. Let the original reviewer resolve their own threads.
- Each reply must be specific to the comment it addresses — never post the same generic "Addressed in <sha>" message to multiple comments. Mention the exact change made (e.g., "Moved `getEquitySourceOptions` to `@/app/utils/equityUtils.ts`" not "Addressed in f8d72ecb").
- When a reviewer asks to deduplicate or move code, search the entire codebase for ALL instances of that pattern before fixing. Do not fix one occurrence and miss others — reviewers will catch this and require another round.
- When moving code to a new location, verify the destination file's existing conventions. Do not put functions in data-only files, logic in type files, etc.
- After applying fixes, re-read the full review thread top-to-bottom to catch follow-up comments that build on earlier ones (e.g., "you also need to deduplicate X" after an initial dedup request).
