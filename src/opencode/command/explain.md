---
name: explain
description: Explain a file, function, or architectural pattern in plain language
---

Usage: /explain [file path, function name, or concept]

Locate the specified target in the codebase and produce a clear, plain-language explanation of how it works, why it exists, and how it connects to the rest of the system.

Load the **code-follower** skill to understand the codebase's conventions and patterns before explaining.

$ARGUMENTS

1. Parse the target from arguments — it may be a file path, function name, class name, or architectural concept
2. Search the codebase for the target using glob and grep tools
3. If the target is not found, list the closest matching files or symbols and notify the user — do not proceed
4. Read the target file(s) and surrounding context (imports, callers, dependents)
5. Identify the data flow: what inputs it receives, what it transforms, and what outputs it produces
6. Identify dependencies: what it imports, what external services or modules it relies on
7. Identify dependents: what other code calls or imports this target
8. Produce a structured explanation covering:
   - Purpose: why this exists and what problem it solves
   - Data flow: inputs → transformations → outputs
   - Dependencies: what it relies on
   - Dependents: what relies on it
   - Key design decisions: any non-obvious choices and their rationale
9. Keep the explanation concise and jargon-free — target audience is a developer new to this codebase

Constraints:
- Do not modify any files
- If the target is ambiguous (multiple matches), present the options and ask the user to clarify
- For architectural concepts (e.g., "auth flow", "caching strategy"), trace the pattern across multiple files
