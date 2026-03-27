---
name: explain
description: Explain what a file, function, or code section does
---

Usage: /explain <file, function, or code area>

Explain the specified code clearly and concisely.

$ARGUMENTS

1. Determine the scope:
   - If the user specifies a file, read and explain its purpose, structure, and key logic
   - If the user specifies a function or class, locate it and explain what it does, its inputs/outputs, and side effects
   - If the user describes an area (e.g. "the auth flow"), trace the relevant code paths and explain how they connect

2. Provide the explanation:
   - Start with a one-sentence summary of what the code does
   - Break down the logic step by step
   - Highlight non-obvious behavior, edge cases, and important design decisions
   - Reference specific line numbers and file paths

3. Load applicable skills in parallel:
   - **follower**: Load if explaining why code is structured a certain way
   - **logic-checker**: Load if the code contains complex conditional flows or state management worth annotating

Keep explanations concise and focused on the "why" behind the code, not just restating what each line does.
