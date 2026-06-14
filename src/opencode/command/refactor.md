---
name: refactor
description: Restructure code by extracting, inlining, renaming, moving, splitting, and consolidating while preserving behavior
---

Usage: /refactor [file path, directory, or description of area to refactor]

$ARGUMENTS

## Scope Detection

Parse `$ARGUMENTS` to determine what to refactor:
- **File mode** — argument is a file path → refactor that file
- **Directory mode** — argument is a directory path → scan for structural problems in that directory
- **Description mode** — argument describes a feature or area → search the codebase to locate the relevant code
- **Local mode** — no arguments → check for uncommitted changes (`git diff` + `git diff --cached`). If changes exist, refactor the changed files. If no changes, fall back to the last commit's diff (`git diff HEAD~1..HEAD`) and refactor those files.

## Skills and Stack Detection

Run `detect-stack.sh` to detect the project's tech stack and load skills accordingly:
- Java files → load **java-spring-senior**
- TypeScript/React files → load **ts-total-typescript**
- Shell scripts → load **meta-shell-scripting**
- Always load in parallel: **code-follower**, **code-deduplicator**, **code-consolidator**, **code-simplifier**, **code-naming**, **meta-structure**, **code-quality**

Load all applicable skills in a single parallel batch.

## Analysis

1. Read the target files and identify structural problems:
   - **Duplication** — repeated logic across 3+ sites that belongs in a shared utility
   - **Misplaced responsibilities** — code living in the wrong file/module/layer
   - **Over-separation** — over-abstracted layers or indirection that add no value
   - **God files/functions** — large units doing multiple unrelated things that should be split
   - **Poor names** — symbols (variables, functions, files, types) whose names don't reflect their purpose
   - **Tangled coupling** — modules that reach into each other's internals
   - **Inconsistent structure** — files or folders that diverge from the project's established layout

2. Prioritize findings:
   - **High** — duplication or misplaced code that actively causes bugs or blocks current work
   - **Medium** — god files/functions, tangled coupling, over-separation
   - **Low** — naming improvements, minor structural inconsistencies
   - **Skip** — stable code that is rarely touched

3. Present findings in this format:

```
## Refactoring Opportunities

### High Priority
- **order/service.ts:45-120** — `OrderService` mixes pricing, persistence, and notification logic
  Suggested: Extract `PricingCalculator`, `OrderRepository`, `OrderNotifier`

### Medium Priority
- **utils.ts:30-80** — Date formatting duplicated in 4 call sites
  Suggested: Extract `formatDate` into a shared utility and replace call sites

### Low Priority
- **handlers.ts:12** — Function `doIt` has an unclear name
  Suggested: Rename to `processWebhookEvent`
```

## Apply Refactorings

IMPORTANT: Present all findings first, then ask the user what to do. Wait for the user's response before making any edits.

Use the question tool to ask the user:
- **Yes, refactor all** — launch the **refactorer** agent on all findings
- **Yes, walk through one by one** — present each finding individually (high first, then medium, then low) using the question tool, letting the user choose "Refactor this", "Skip", or "Stop" for each one
- **No** — end the command

Delegate the actual restructuring to the **refactorer** agent. When findings are independent and touch different files, launch multiple **refactorer** agents in parallel.

## Constraints

- **Preserve behavior** — every change must be purely structural. No functional changes, no new features.
- **One transformation at a time** — apply each refactoring as an atomic step, verify before moving to the next
- **Update all references** — imports, usages, and type references must be updated across the codebase after every move/rename/extraction
- **No dead code** — remove anything left orphaned by a move or extraction
- **Match conventions** — follow the existing codebase patterns and project layout exactly
- **Do not change public API contracts** — unless the user explicitly asks
- **Do not add tests** — unless the user explicitly asks
- **Do not refactor working code that is rarely touched** — focus on code with active development

## Post-Refactoring Checks

After all refactorings are applied, use the question tool to ask: "Run test, lint, and typecheck?" Options: "Yes, run all checks" / "No, skip checks".

If yes:
1. Run `detect-stack.sh` to determine available check commands
2. Run the following in parallel where available:
   - Tests: `run-tests.sh`
   - Lint: `lint-check.sh`
   - Typecheck: `type-check.sh`
3. Report pass/fail for each check
4. If any check fails, offer to fix the failures
