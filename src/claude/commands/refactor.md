---
description: Restructure code by extracting, inlining, renaming, moving, splitting, and consolidating while preserving behavior
argument-hint: [file path, directory, or description of area to refactor]
---

Usage: /refactor [file path, directory, or description of area to refactor]

$ARGUMENTS

## Scope Detection

Parse `$ARGUMENTS` to determine what to refactor:

| Argument | Mode | Action |
|----------|------|--------|
| File path | File | Refactor that file |
| Directory path | Directory | Scan that directory for structural problems |
| Feature/area description | Description | Search the codebase to locate the relevant code |
| (none) | Local | Refactor uncommitted changes (`git diff` + `git diff --cached`). If none, fall back to the last commit (`git diff HEAD~1..HEAD`). |

## Skills and Stack Detection

Run `detect-stack.sh`, then load the matching skills in a single parallel batch:

- **Always**: code-follower, code-deduplicator, code-consolidator, code-simplifier, code-naming, meta-structure, code-quality
- Java files → also **java-spring-senior**
- TypeScript/React files → also **ts-total-typescript**
- Shell scripts → also **meta-shell-scripting**

## Analysis

### 1. Identify structural problems

Read the target files and look for these smells:

| Smell | What it is | Typical fix |
|-------|------------|-------------|
| Duplication | Same logic across 3+ sites | Extract a shared utility |
| Misplaced responsibility | Code living in the wrong file/module/layer | Move it to where it belongs |
| Over-separation | Abstraction or indirection that adds no value | Inline it |
| God file/function | One large unit doing several unrelated things | Split by responsibility |
| Poor name | Symbol name doesn't reflect its purpose | Rename to match intent |
| Tangled coupling | Modules reaching into each other's internals | Introduce a clean boundary |
| Inconsistent structure | Files/folders that diverge from project layout | Realign to convention |

### 2. Prioritize findings

| Priority | Criteria |
|----------|----------|
| High | Duplication or misplaced code that causes bugs or blocks current work |
| Medium | God files/functions, tangled coupling, over-separation |
| Low | Naming improvements, minor structural inconsistencies |
| Skip | Stable code that is rarely touched |

### 3. Present findings

```
## Refactoring Opportunities

### High Priority
- **order/service.ts:45-120** — `OrderService` mixes pricing, persistence, and notification logic
  Suggested: Extract `PricingCalculator`, `OrderRepository`, `OrderNotifier`

### Medium Priority
- **utils.ts:30-80** — Date formatting duplicated across 4 call sites
  Suggested: Extract `formatDate` into a shared utility and update call sites

### Low Priority
- **handlers.ts:12** — Function `doIt` has an unclear name
  Suggested: Rename to `processWebhookEvent`
```

## Apply Refactorings

IMPORTANT: Present all findings first. Wait for the user's response before editing.

Use the question tool to ask how to proceed:

- **Refactor all** — launch the **refactorer** agent on every finding
- **Walk through one by one** — present each finding in priority order (high → medium → low), offering "Refactor this", "Skip", or "Stop"
- **No** — end the command

Delegate all restructuring to the **refactorer** agent. Launch multiple agents in parallel when findings are independent and touch different files.

## Constraints

- **Preserve behavior** — every change is purely structural: no functional changes, no new features
- **One transformation at a time** — apply each as an atomic step and verify before the next
- **Update all references** — fix imports, usages, and type references across the codebase after every move/rename/extraction
- **No dead code** — remove anything orphaned by a move or extraction
- **Match conventions** — follow the existing codebase patterns and project layout exactly
- **Do not change public API contracts** — unless the user explicitly asks
- **Do not add tests** — unless the user explicitly asks
- **Do not refactor rarely-touched working code** — focus on code under active development

## Post-Refactoring Checks

Use the question tool to ask: "Run test, lint, and typecheck?" Options: "Yes, run all checks" / "No, skip checks".

If yes:

1. Run `detect-stack.sh` to determine available check commands
2. Run these in parallel where available: `run-tests.sh`, `lint-check.sh`, `type-check.sh`
3. Report pass/fail for each check
4. If any check fails, offer to fix the failures
