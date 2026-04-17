---
name: comm-spec-writer
description: Implementation spec writing principles covering structure, task decomposition, dependency mapping, complexity estimation, edge case discovery, and quality heuristics
---

## Spec Structure

A spec follows this section order:

| Section | Purpose | Required |
|---------|---------|----------|
| **Title (H1)** | Short name describing the feature or change | Yes |
| **Overview** | 2-3 sentences explaining what and why | Yes |
| **Architecture** | Which files, modules, or systems are involved | Yes |
| **Data Flow** | How data moves through the system for this change | If applicable |
| **Tasks** | Ordered table of implementation steps | Yes |
| **API Contracts** | Interface definitions, request/response shapes, config formats | If applicable |
| **State Changes** | What files are created, modified, or deleted | Yes |
| **Edge Cases** | Scenarios that could break or behave unexpectedly | Yes |
| **Testing Approach** | How to verify the implementation works | Yes |
| **Open Questions** | Ambiguities that need resolution before or during implementation | If any exist |

## Writing Principles

| Principle | Rule | Bad Example | Good Example |
|-----------|------|-------------|--------------|
| **Precision over brevity** | Be exact about file paths, function names, data types | "Update the config" | "Add `timeout_ms: number` field to `src/config/app.ts` `AppConfig` interface" |
| **Concrete over abstract** | Use real names and values, not placeholders | "Handle the error case" | "If `fetchUser` returns 404, redirect to `/login` with `?returnUrl=` param" |
| **Examples over descriptions** | Show what the code/config should look like | "Add a new API endpoint" | Show the route definition, handler signature, and example request/response |
| **Minimal scope** | One spec = one cohesive change | Spec covering auth + billing + UI redesign | Separate specs for each |
| **Dependency-aware** | Tasks list dependencies explicitly | "Do these tasks" | "Task 3 depends on tasks 1 and 2; tasks 4 and 5 are independent" |

## Task Table Format

```markdown
| # | File | Change | Complexity | Dependencies | Parallel? |
|---|------|--------|------------|--------------|-----------|
| 1 | `src/api/users.ts` | Add `GET /users/:id/preferences` endpoint returning `UserPreferences` type | Small | None | Yes |
| 2 | `src/types/user.ts` | Add `UserPreferences` interface with fields: theme, locale, notifications | Small | None | Yes |
| 3 | `src/api/users.test.ts` | Add tests for the new endpoint: happy path, 404, unauthorized | Medium | 1, 2 | Sequential |
```

### Task Fields

| Field | Values | Rule |
|-------|--------|------|
| **#** | Sequential integer | Order of implementation |
| **File** | Relative path in backticks | Exact file being changed — one file per row |
| **Change** | Imperative sentence | What to do, with enough detail to implement without ambiguity |
| **Complexity** | Small / Medium / Large | Small: <30 min, Medium: 30-120 min, Large: >120 min |
| **Dependencies** | Task numbers or "None" | Which tasks must complete first |
| **Parallel?** | Yes / Sequential | Whether this task can run alongside other independent tasks |

## Task Decomposition Heuristics

- **One file per task** — if a change touches 3 files, that's 3 tasks
- **Tests are separate tasks** — never combine implementation and testing
- **Config changes are separate** — environment, build, or infra changes get their own tasks
- **Documentation updates are separate** — AGENTS.md, README, or changelog updates are distinct tasks
- **Prefer small tasks** — if a task is "Large", consider splitting it further
- **Order by dependency** — independent tasks first, dependent tasks after their prerequisites
- **Mark parallelism** — explicitly state which tasks can run concurrently

## Complexity Estimation

| Complexity | Indicators |
|------------|------------|
| **Small** | Single function change, config update, type addition, simple test, file rename |
| **Medium** | New module with multiple functions, integration between two systems, test suite for a feature, refactoring with multiple callers |
| **Large** | New subsystem, database migration with data transformation, cross-cutting concern affecting many files, external API integration with error handling and retries |

## Edge Case Discovery

Ask these questions for every spec:

| Category | Questions |
|----------|-----------|
| **Empty/null input** | What happens with empty strings, null values, missing fields, zero-length arrays? |
| **Boundaries** | What happens at min/max values, array limits, timeout thresholds? |
| **Concurrency** | Can two users/processes trigger this simultaneously? What happens if they do? |
| **Failure modes** | What if the network call fails? The file doesn't exist? The database is down? |
| **State transitions** | Can the system be in an invalid state during this change? What if the process crashes mid-operation? |
| **Backwards compatibility** | Does this break existing callers, configs, or data formats? |
| **Ordering** | Does the order of operations matter? What if events arrive out of order? |
| **Permissions** | Who can trigger this? What if an unauthorized user tries? |

## Open Questions Format

Group by category with a recommendation for each:

```markdown
## Open Questions

### Requirements
- **Question text here?** Context explaining why this matters. (Recommend: specific recommendation)

### Architecture
- **Question text here?** What implementation decision depends on the answer. (Recommend: specific recommendation)

### Risks
- **Risk description** — what could go wrong and how likely it is
```

## Quality Checklist

- [ ] Every task can be implemented without asking clarifying questions
- [ ] File paths are exact and verified to exist (or marked as "new file")
- [ ] Dependencies between tasks are explicitly listed — no hidden ordering assumptions
- [ ] Edge cases cover at least: empty input, failure modes, and concurrent access
- [ ] The testing approach covers happy path, error paths, and edge cases
- [ ] State changes list every file created, modified, or deleted
- [ ] Open questions include a recommendation — don't just list problems
- [ ] The spec is scoped to a single cohesive change — not a grab bag of unrelated tasks

## What Makes a Spec Bad

| Smell | Problem | Fix |
|-------|---------|-----|
| "Update the service layer" | Too vague to implement | Specify exact file, function, and change |
| No edge cases listed | Bugs will be discovered during implementation | Ask the edge case discovery questions |
| Tasks with no dependencies listed | Implementer doesn't know the order | Add explicit dependency numbers |
| Single task covering 5+ files | Task is too large to estimate or review | Split into one task per file |
| Open questions with no recommendations | Blocks implementation | Always include a recommended default |
| Missing testing approach | No way to verify correctness | Add specific test scenarios |
