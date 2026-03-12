---
name: suggest
description: Suggest improvements, next steps, or actions for the current project state
---

Usage: /suggest [focus area]

Analyze the current project state and suggest actionable next steps or improvements.

$ARGUMENTS

1. Assess the current state (run independent commands in parallel):
   - Run `git status` to see uncommitted changes
   - Run `git diff` and `git diff --cached` to understand in-progress work
   - Run `git log --oneline -10` to see recent activity
   - Check for failing tests or build errors if a test/build command is available

2. Determine focus:
   - If the user specifies a focus area, narrow suggestions to that scope
   - If no focus is given, analyze the overall project state and suggest the most impactful next actions

3. Generate suggestions across these categories (only include categories that are relevant):
   - **Immediate actions**: Unstaged changes to commit, failing tests to fix, build errors to resolve
   - **Code quality**: Files or patterns that could benefit from refactoring, simplification, or deduplication
   - **Missing coverage**: Areas lacking tests, error handling, or validation
   - **Performance**: Obvious bottlenecks or inefficient patterns spotted during analysis
   - **Security**: Exposed secrets, missing input validation, or unsafe patterns
   - **Documentation**: Missing or outdated AGENTS.md, config files, or inline documentation

4. Present suggestions:
   - Rank by impact (high, medium, low)
   - For each suggestion: one sentence describing what to do and why
   - Reference specific files and line numbers where applicable
   - Suggest which `/command` to run for each action when one exists (e.g., `/fix`, `/improve`, `/review`, `/test`, `/security`)

Do not apply changes. Present suggestions only so the user can decide what to tackle next.
