---
name: pr
description: Implement changes in a worktree and create a PR
---

Usage: /pr [description or task list]

$ARGUMENTS

## Mode Detection

Parse `$ARGUMENTS` to determine the mode:
- **Sequential mode** — any of: `--sequential` flag, phrases like "sequentially", "one by one", "one at a time", "in order", "step by step", or a numbered/bulleted list of ordered tasks
- **Parallel mode** — any of: `--parallel` flag, phrases like "in parallel", "simultaneously", "at the same time", "concurrently", or explicit grouping of independent tasks
- **Single mode** — everything else (a single task description)
- If no arguments are provided, ask the user what they want to implement

## Skill Loading

Load skills based on mode:
- **All modes**: Load **git-worktree-workflow**, **git-workflows**, and **tool-todoist-cli** in parallel
- **Sequential mode**: Also load the **pr-sequential** skill
- **Parallel mode**: Also load the **pr-parallel** skill

## Single Mode

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
