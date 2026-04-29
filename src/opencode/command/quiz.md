---
name: quiz
description: Generate a spec then quiz the user step-by-step on what they would do, scoring answers before implementing
---

Usage: /quiz [$ARGUMENTS]

Quiz the user on implementation decisions for a spec or plan file. Generate a spec if none exists, then walk through each task asking "what would you do here?" and score their answers.

1. Find or generate the spec:
   - If `$ARGUMENTS` points to a file in `spec/` or `plans/`, read it as the quiz source
   - If `$ARGUMENTS` describes a feature, run `/specify` to generate a spec first
   - If no arguments provided, list available files in `spec/` and `plans/` and let the user pick via the question tool
   - If no spec or plan files exist, ask the user to describe a feature and generate a spec

2. Parse the spec into quiz steps:
   - Extract each task/change from the spec
   - For each task, prepare the expected answer (what changes to make, which file, what approach)

3. Run the quiz loop — for each task:
   - Present the task context: what the spec says needs to happen, which files are involved
   - Ask the user: "What would you do here?" via the question tool with 3-4 concrete options (one correct, others plausible but wrong)
   - After the user answers, reveal the correct approach and explain why
   - Score: correct or incorrect

4. Present final results:
   - Total score (e.g., 7/10)
   - List of tasks with correct/incorrect status
   - Highlight tasks the user got wrong with explanations

5. Offer next steps:
   - "Would you like to implement this spec now?" → run `/implement` with the spec
   - "Would you like to retry the questions you got wrong?" → re-quiz missed items only
   - "Done" → exit

Important:
- Make wrong options plausible — they should represent common mistakes or alternative approaches
- Explain the reasoning behind the correct answer, not just "this is right"
- If the user's custom answer is valid but different from the spec, accept it and explain the tradeoff
