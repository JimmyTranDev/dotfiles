---
name: suggest
description: Suggest approaches, solutions, or next steps based on what the user is asking
---

Usage: /suggest [question, goal, or topic]

Analyze the user's question or goal and suggest practical approaches, solutions, or actions they can take.

$ARGUMENTS

1. Understand the context (run independent commands in parallel):
   - Read the user's request to identify what they're trying to accomplish or decide
   - Explore relevant parts of the codebase — project structure, key files, recent changes
   - Run `git log --oneline -20` and `git diff --stat` to understand current state and momentum
   - If the user specifies a topic or goal, focus suggestions on that scope

2. Generate suggestions:
   - Provide 3-5 concrete, actionable suggestions ranked by practicality
   - For each suggestion:
     - Give it a short, clear name
     - Explain the approach in 1-3 sentences — what to do and why it works
     - List specific files, tools, or commands involved
     - Note tradeoffs or considerations (effort, risk, complexity)
   - Tailor suggestions to the project's existing patterns, stack, and conventions

3. Load applicable skills in parallel based on the topic:
   - **follower**: Load when suggestions involve writing new code to ensure they align with existing patterns
   - **logic-checker**: Load when suggestions involve complex decisions or architectural tradeoffs

4. Delegate to specialized agents where applicable — maximize parallelism per the Parallelization section in AGENTS.md:
   - **explorer**: Use to gather deeper context about relevant parts of the codebase
   - **reviewer**: Use if the user is asking about an existing approach and wants to know if it's good or what alternatives exist

5. Present suggestions:
   - Rank by impact-to-effort ratio (quick wins first)
   - Highlight the recommended approach and explain why
   - Suggest which `/command` to run to act on each suggestion (e.g., `/implement`, `/fix`, `/improve`)

Do not apply changes. Present suggestions only so the user can decide how to proceed.
