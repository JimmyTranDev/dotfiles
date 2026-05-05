---
name: triage-todoist-section
description: Clarify and consolidate Todoist tasks in a section by asking about each task then merging/reorganizing
---

Usage: /triage-todoist-section $ARGUMENTS

Walk through all tasks in a Todoist section, ask clarifying questions about ambiguous or overlapping tasks, then consolidate duplicates, remove irrelevant items, and reorganize the section.

$ARGUMENTS should be a Todoist section URL, section name (with project), or project URL with section specified.

1. Load the **tool-todoist-cli** skill.

2. Identify the section:
   - If `$ARGUMENTS` is a section URL, extract the section ID from the URL (last segment after final `-`)
   - If `$ARGUMENTS` is a section name, ask for the project name if not provided
   - If no arguments, ask the user which project and section to triage

3. List all tasks in the section:
   - Use `td section list "<project>" --json --show-urls` to find the section ID
   - Use `td task list --project "<project>" --json --full --show-urls` and filter by `sectionId`
   - Present the task list to the user with indices for reference

4. Clarify ambiguous tasks:
   - Group tasks that appear to be duplicates or overlapping
   - For each ambiguous group or unclear task, ask the user:
     - What does this task actually mean? Is it still relevant?
     - Should duplicates be merged? Which title/description to keep?
     - Should any tasks be broken down or combined?
   - Use the question tool with concrete options where possible
   - Process in batches of 3-5 tasks to avoid overwhelming the user

5. Consolidate based on answers:
   - **Merge duplicates**: Complete the duplicate tasks, update the surviving task with combined context
   - **Remove irrelevant**: Complete or delete tasks the user says are no longer needed
   - **Rewrite unclear**: Update task content/description to be clear and actionable
   - **Reorder**: Move tasks to reflect priority (use `td task update` for order if needed)
   - **Reparent**: If tasks should be subtasks of another, use `td task move --parent`

6. Execute changes:
   - For each change, use the appropriate `td` command:
     - `td task complete <ref>` for duplicates/irrelevant tasks
     - `td task update <ref> --content "new title"` for rewrites
     - `td task update <ref> --description "new desc"` for added context
     - `td task move <ref> --parent <ref>` for reparenting
     - `td task delete <ref>` only if user explicitly requests deletion
   - Show a summary of all changes made

7. Present the final state:
   - List the remaining tasks in the section after consolidation
   - Show a before/after count

Do not delete tasks unless the user explicitly asks — prefer completing them to preserve history.
Do not move tasks out of the section unless the user requests it.
