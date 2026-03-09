---
name: refactor
description: Refactor and simplify code by applying DRY, KISS, and YAGNI principles
---

Analyze the specified code (files, directories, or the area described in the user's prompt) and refactor it for simplicity, clarity, and maintainability.

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes an area or pattern, search the codebase to locate the relevant code
   - Run tests or build commands if available to establish a working baseline before making changes

2. Analyze the code for refactoring opportunities:
   - **Duplication**: Repeated logic, copy-pasted blocks, similar functions that can be unified
   - **Complexity**: Deeply nested conditionals, long functions, overly clever abstractions
   - **Dead code**: Unused imports, unreachable branches, commented-out code, unused variables or functions
   - **Over-engineering**: Unnecessary abstractions, premature generalization, layers that add no value
   - **Naming**: Unclear or misleading variable, function, or file names
   - **Structure**: Functions or modules doing too many things, poor separation of concerns

3. Apply refactoring principles:
   - **DRY** (Don't Repeat Yourself): Extract shared logic into reusable functions or modules
   - **KISS** (Keep It Simple, Stupid): Replace complex solutions with simpler alternatives
   - **YAGNI** (You Aren't Gonna Need It): Remove speculative features and unused abstractions
   - Preserve existing behavior — refactoring must not change what the code does

4. Delegate to specialized agents in parallel where applicable:
   - **follower**: Always use first to learn codebase conventions so refactored code matches the existing style
   - **pragmatic**: Use as the primary agent for applying DRY, KISS, YAGNI to reduce complexity
   - **reuser**: Use to extract repeated patterns into reusable utilities, hooks, or components
   - **re-export-destroyer**: Use if barrel files, circular dependencies, or re-export chains are found
   - **optimizer**: Use if performance-sensitive code is identified during refactoring
   - **sounder**: Use if refactored logic involves complex conditionals or state to verify correctness
   - **reviewer**: Use after refactoring is complete to verify the changes are sound and nothing was broken
   - **tester**: Use to run existing tests or add tests if coverage is missing for refactored code

5. After refactoring:
   - Run the project's test suite and build to confirm nothing is broken
   - Summarize what was changed and why
   - List any follow-up improvements that were out of scope but worth noting
