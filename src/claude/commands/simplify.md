---
description: Simplify complex code by reducing nesting, extracting functions, and removing unnecessary abstractions
argument-hint: "[file path, directory, or description of area to simplify]"
---

Usage: /simplify [file path, directory, or description of area to simplify]

$ARGUMENTS

## Scope Detection

Parse `$ARGUMENTS` to determine what to simplify:
- **File mode** — argument is a file path → simplify that file
- **Directory mode** — argument is a directory path → scan for complexity hotspots in that directory
- **Description mode** — argument describes a feature or area → search the codebase to locate the relevant code
- **Local mode** — no arguments → check for uncommitted changes (`git diff` + `git diff --cached`). If changes exist, simplify the changed files. If no changes, fall back to the last commit's diff (`git diff HEAD~1..HEAD`) and simplify those files.

## Skills and Stack Detection

Run `detect-stack.sh` to detect the project's tech stack and load skills accordingly:
- Java files → load **java-spring-senior**
- TypeScript/React files → load **ts-total-typescript**
- Shell scripts → load **meta-shell-scripting**
- Always load in parallel: **code-simplifier**, **code-follower**, **code-deduplicator**, **code-consolidator**, **code-quality**

Load all applicable skills in a single parallel batch.

## Analysis

1. Read the target files and identify complexity smells using the **code-simplifier** skill:
   - Long functions (> 20 lines or multiple concerns)
   - Deep nesting (> 2 levels)
   - Long parameter lists (> 3 parameters)
   - Boolean parameters
   - Duplicate logic (3+ occurrences)
   - Imperative loops replaceable with declarative alternatives
   - Unnecessary temporary variables
   - Stored state that could be derived
   - Overly complex async chains
   - Dead code and speculative generality

2. Prioritize findings:
   - **High** — blocks current work or causes bugs
   - **Medium** — duplicated logic, deeply nested code
   - **Low** — style inconsistencies, minor naming improvements
   - **Skip** — working code that is rarely touched

3. Present findings in this format:

```
## Simplification Opportunities

### High Priority
- **file.ts:45-78** — Function `processOrder` (34 lines) does 3 things: validation, calculation, and formatting
  Suggested: Extract `validateOrder`, `calculateTotal`, `formatReceipt`

### Medium Priority
- **file.ts:12-30** — 4 levels of nested conditionals in `getDiscount`
  Suggested: Flatten with early returns

### Low Priority
- **file.ts:92** — Temporary variable `temp` used once
  Suggested: Inline the expression
```

## Apply Simplifications

IMPORTANT: Present all findings first, then ask the user what to do. Wait for the user's response before making any edits.

Use the question tool to ask the user:
- **Yes, simplify all** — launch the **refactorer** agent on all findings
- **Yes, walk through one by one** — present each finding individually (high first, then medium, then low) using the question tool, letting the user choose "Simplify this", "Skip", or "Stop" for each one
- **No** — end the command

## Constraints

- **Preserve behavior** — every change must be purely structural. No functional changes.
- **One change at a time** — apply each simplification as an atomic edit, verify before moving to the next
- **Match conventions** — follow the existing codebase patterns exactly
- **Do not add tests** — unless the user explicitly asks
- **Do not refactor working code that is rarely touched** — focus on code with active development

## Post-Simplification Checks

After all simplifications are applied, use the question tool to ask: "Run test, lint, and typecheck?" Options: "Yes, run all checks" / "No, skip checks".

If yes:
1. Run `detect-stack.sh` to determine available check commands
2. Run the following in parallel where available:
   - Tests: `run-tests.sh`
   - Lint: `lint-check.sh`
   - Typecheck: `type-check.sh`
3. Report pass/fail for each check
4. If any check fails, offer to fix the failures
