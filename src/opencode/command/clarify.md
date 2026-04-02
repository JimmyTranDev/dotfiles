---
name: clarify
description: Analyze a vague request or spec and generate targeted clarifying questions to remove ambiguity
---

Usage: /clarify $ARGUMENTS

Analyze the user's request, spec, or task description and generate targeted clarifying questions that resolve ambiguity before implementation begins.

$ARGUMENTS

1. Parse the input:
   - If the user provides a task description, feature request, or spec — analyze it directly
   - If the user references a file, issue, or PR — read it to understand the full context
   - If no arguments are provided, ask the user what they want clarified

2. Explore relevant context (run in parallel):
   - Search the codebase for existing patterns, conventions, and related implementations that inform the questions
   - Check for AGENTS.md, README, or other project docs that define constraints or conventions
   - Look at recent git history to understand current development direction

3. Identify ambiguity across these dimensions:

   - **Scope**: What's included vs excluded? Where are the boundaries?
   - **Behavior**: What should happen for each user action? What are the expected inputs and outputs?
   - **Edge cases**: What happens with empty input, errors, concurrent access, or unexpected state?
   - **Constraints**: Performance requirements, platform support, backwards compatibility, accessibility?
   - **Dependencies**: What existing code, APIs, or services does this interact with?
   - **Acceptance criteria**: How do we know when this is done? What does "working" look like?
   - **Prioritization**: If this involves multiple sub-tasks, which are must-have vs nice-to-have?

4. Generate clarifying questions:
   - Group questions by dimension
   - Order by importance — questions that would most change the implementation approach come first
   - For each question, explain why it matters (what implementation decision depends on the answer)
   - Where possible, offer concrete options rather than open-ended questions (e.g., "Should X behave like A or B?" rather than "How should X work?")
   - Skip questions that are already answered by the input or discoverable from the codebase

5. Present the questions:
   - Use the question tool for questions with clear option sets
   - Use plain text for open-ended questions that need the user's domain knowledge
   - Limit to 5-10 questions — if more exist, prioritize and note that additional questions may follow

6. After the user answers:
   - Summarize the clarified requirements as a concise spec
   - Suggest which `/command` to run next to begin implementation (e.g., `/implement`, `/fix`, `/design`)

Do not start implementing until all critical ambiguities are resolved.
