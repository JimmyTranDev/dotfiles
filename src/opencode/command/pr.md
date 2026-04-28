---
name: pr
description: Implement changes in a worktree and create a PR
---

Usage: /pr <description of what to implement>

Implement the described changes in a new git worktree, then create a pull request.

$ARGUMENTS

Load the **git-worktree-workflow**, **git-workflows**, and **tool-todoist-cli** skills in parallel.

1. Set up the worktree per the `pr-*` conventions in AGENTS.md

2. Implement the requested changes — all file reads, edits, and creates happen in `~/Programming/wcreated/<branch-name>/`, not the main repo

3. Stage and commit the changes using the commit format from the **git-workflows** skill:
   - `git add -A`
   - `git commit -m "<emoji> <type>(<scope>): <description>"`

4. Run the review-fix-verify cycle per the `pr-*` conventions in AGENTS.md

5. Push the branch:
   - `git push -u origin <branch-name>`

6. Create the PR:
   - Create the PR with `gh pr create` targeting the base branch, with a title matching the original commit message and a summary body

7. Report the PR URL to the user
