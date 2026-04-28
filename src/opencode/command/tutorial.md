---
name: tutorial
description: Implement changes one step at a time, explaining each step before and after, pausing for questions between steps
---

Usage: /tutorial [description]

Implement the requested changes one step at a time. Before each step, explain what you're about to do and why. After each step, show what changed and ask if the user has questions or wants to continue.

## Mode Detection

Detect Jira mode from `$ARGUMENTS` using any of these signals:
- Explicit flag: `--jira`
- Contains a Jira URL (e.g., `*.atlassian.net/browse/*`, `*/jira/*/browse/*`)
- Natural language: phrases like "jira ticket", "from jira", "jira issue", "jira story"

If Jira mode is detected, load the **tutorial-jira** skill and run its Jira Ticket Preamble before proceeding. The fetched ticket becomes the implementation description.

If no arguments are provided, ask the user what they want to learn/implement.

Otherwise, use `$ARGUMENTS` directly as the implementation description.

$ARGUMENTS

1. Parse the request and break it into small, logical implementation steps:
   - Each step should be a single focused change (one function, one file modification, one configuration change)
   - Order steps so each builds on the previous — the user should be able to follow the progression
   - Present the full list of steps upfront so the user sees the plan

2. Use the TodoWrite tool to create a todo for each step with a descriptive name.

3. For each step:

   a. **Explain before doing**: Describe what you're about to change, which file it's in, why this change is needed, and how it connects to the overall goal. If there are design decisions or tradeoffs, explain them.

   b. **Implement the change**: Make the single focused change. Keep it small enough that the user can follow along.

   c. **Show what changed**: Summarize what was modified — file path, what was added/removed/changed, and what the code does.

   d. **Mark the todo as completed**.

   e. **Pause and ask**: Stop and ask the user:
      - "Any questions about this step?"
      - "Ready for the next step, or want to go deeper into something?"
      - Do NOT proceed to the next step until the user confirms

4. If the user asks a question:
   - Answer it thoroughly — explain the why, show relevant code, connect it to the broader picture
   - After answering, ask again if they're ready to continue

5. After all steps are complete:
   - Summarize everything that was changed across all steps
   - Highlight the key patterns and decisions the user should remember
   - Ask if there's anything they want to revisit or understand better

Important:
- Never skip the pause between steps — the whole point is interactive, paced learning
- Never batch multiple changes into one step to "save time" — small steps are the goal
- If a step turns out to be more complex than expected, split it into sub-steps on the fly
- Adjust explanation depth based on the user's questions — if they ask basic questions, explain more fundamentals; if they ask advanced questions, go deeper
