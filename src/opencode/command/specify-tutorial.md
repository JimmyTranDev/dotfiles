---
name: specify-tutorial
description: Break a task into step-by-step instructions with before/after code examples and write spec to `spec/`
---

Usage: /specify-tutorial <what to implement or change>

Analyze the requested change and produce a step-by-step tutorial spec showing exactly what needs to be done, with before and after code for each step.

$ARGUMENTS

1. Parse the request and understand the scope:
   - Read the relevant files and their dependents to understand the current state
   - If the request is vague, ask clarifying questions before proceeding
   - Load applicable skills: **code-follower** and any domain-relevant skills

2. Break the work into small, logical steps:
   - Each step should be a single focused change (one function, one file modification, one configuration change)
   - Order steps so each builds on the previous — the reader should be able to follow the progression
   - Each step must be independently understandable

3. For each step, document:

   a. **What**: A short title describing the change

   b. **Why**: Why this step is needed and how it connects to the overall goal

   c. **Where**: The file path and location within the file

   d. **Before**: The exact code that exists now (or "new file" if creating)

   e. **After**: The exact code it should become after the change

   f. **Explanation**: What changed between before and after — highlight the key differences and the reasoning behind each change

4. Present the analysis:
   - Number each step sequentially
   - Include a summary at the top listing all steps so the reader sees the full plan
   - After all steps, include a final summary of all files touched and the cumulative effect

5. Launch agents in parallel:
   - **reviewer**: Verify the proposed steps are correct, complete, and in the right order

6. Write findings to a spec file using the `tutorial-` prefix per the `specify-*` conventions in AGENTS.md.
