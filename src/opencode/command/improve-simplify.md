---
name: improve-simplify
description: Ask clarifying questions about code intent and usage, then simplify and refactor it
---

Usage: /improve-simplify <files, directories, or description of code to simplify>

Read the target code, ask clarifying questions to understand intent, constraints, and usage patterns, then simplify and refactor based on the answers.

$ARGUMENTS

Load the **code-simplifier**, **code-follower**, **code-conventions**, and **code-deduplicator** skills in parallel.

1. Locate the target code:
   - If the user specifies files or directories, read them
   - If the user describes a pattern or area, search the codebase to locate the relevant code
   - If no arguments are provided, ask the user what code they want simplified

2. Analyze the code for simplification opportunities (run in parallel):
   - Read all target files and their direct dependents (callers, importers)
   - Identify code smells: deep nesting, long functions, redundant abstractions, overly clever logic, duplicated patterns, dead branches, unnecessary indirection
   - Map the public API surface — what do consumers actually use?

3. Ask clarifying questions before making changes:
   - Use the question tool with concrete options where possible
   - Focus on questions that would change the refactoring approach:
     - **Intent**: "This function does X and Y — are both behaviors still needed, or is one legacy?"
     - **Usage**: "This is called from 3 places but only 1 uses parameter Z — can we remove Z?"
     - **Constraints**: "This handles edge case X with 30 lines of special logic — does this case still occur?"
     - **Coupling**: "These two modules share state through X — should they be merged or decoupled?"
     - **Naming**: "This is called `processData` but it actually validates and transforms — should we split or rename?"
   - Skip questions answerable from the code or codebase conventions
   - Limit to 5-8 questions — prioritize by impact on simplification decisions

4. Plan the simplification based on answers:
   - Present a numbered list of proposed changes with before/after descriptions
   - Ask the user to confirm which changes to apply using the question tool with `multiple: true`

5. Apply the simplifications incrementally:
   - One logical change at a time — verify each preserves behavior before moving to the next
   - Match existing codebase conventions exactly (load the **code-follower** skill patterns)
   - Common simplification patterns:
     - Extract repeated logic into shared utilities
     - Flatten deeply nested conditionals with early returns
     - Inline trivial single-use abstractions
     - Remove dead code and unused parameters
     - Replace imperative loops with declarative transforms where clearer
     - Simplify state management by reducing unnecessary intermediaries
     - Rename for clarity when names mislead
   - Update all consumers of changed APIs

6. Verify the results — launch in parallel:
   - **reviewer**: verify correctness, import integrity, and that simplifications preserved behavior
   - **tester**: run tests to confirm no regressions

7. Report a summary:
   - List each simplification applied with a one-line description
   - Lines of code removed or reduced
   - Complexity metrics if measurable (nesting depth, function length, parameter count)
   - Follow-up opportunities that were out of scope or deferred by the user
