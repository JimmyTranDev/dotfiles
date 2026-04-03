---
name: soundness
description: Checklist for finding suspicious patterns, anomalies, inconsistencies, accidental behavior, and things that look wrong across a codebase
---

Find things that are weird. Code that technically works but looks wrong, smells accidental, or suggests a misunderstanding.

## What to Look For

| Category | Examples |
|----------|---------|
| Inconsistencies | Same concept handled differently in different places, mixed conventions within a module |
| Suspicious patterns | Swallowed errors, unused return values, conditions that are always true/false |
| Accidental behavior | Copy-paste artifacts, leftover debugging code, TODO/FIXME/HACK markers |
| Mismatched intent | Variable name says one thing, code does another; function signature suggests purity but has side effects |
| Silent failures | Operations that fail without logging, notification, or error propagation |
| Vestigial code | Feature flags that are always on, config options that are never read, parameters always passed the same value |
| Asymmetry | Resource acquired but never released, event subscribed but never unsubscribed, lock taken but not always freed |

## Anomaly Detection Checklist

### Naming vs Behavior Mismatch

- [ ] Does `getX()` only get, or does it also modify state?
- [ ] Does `isValid()` have side effects?
- [ ] Does a variable named `count` ever hold a non-numeric value?
- [ ] Does a variable named `users` ever hold a single user?
- [ ] Does a function named `create` sometimes return an existing record?
- [ ] Are there boolean variables that are always true or always false?

### Suspicious Control Flow

- [ ] Are there empty `catch` blocks or catches that only log?
- [ ] Are there `if` blocks with identical `then` and `else` branches?
- [ ] Are there return values that are never used by any caller?
- [ ] Are there awaited calls where the result is immediately discarded?
- [ ] Are there conditions that short-circuit before reaching important logic?
- [ ] Are there fallthrough `switch` cases that look accidental?
- [ ] Is there a `default` case that silently does nothing?

### Copy-Paste Artifacts

- [ ] Are there duplicated blocks with only one variable changed — but the wrong one?
- [ ] Are there array indices that repeat (e.g., `items[0]` used twice where `items[0]` and `items[1]` was intended)?
- [ ] Are there string literals that look like they were copied and not updated (e.g., error messages that reference the wrong entity)?
- [ ] Are there functions that share a name pattern but one is subtly different in behavior without clear reason?

### Resource and Lifecycle Issues

- [ ] Are there event listeners added in setup but not removed in teardown?
- [ ] Are there intervals/timeouts set but never cleared?
- [ ] Are there database connections opened but not closed in error paths?
- [ ] Are there file handles or streams that leak on early return?
- [ ] Are there subscriptions created in loops (accumulating per iteration)?

### Config and Environment Smells

- [ ] Are there environment variables read but never set in any `.env` or deployment config?
- [ ] Are there config values with defaults that shadow actual configuration?
- [ ] Are there feature flags checked but never toggled (always on or always off)?
- [ ] Are there hardcoded values that look like they should be configurable?
- [ ] Are there secrets or credentials in non-secret files?

### Data Integrity

- [ ] Are there writes without corresponding validation?
- [ ] Are there reads that assume data exists without null checks?
- [ ] Are there concurrent mutations to shared state without synchronization?
- [ ] Are there transformations that silently drop fields?
- [ ] Are there numeric operations that don't account for floating-point precision?
- [ ] Are there date operations that ignore timezones?

### Debugging Leftovers

- [ ] `console.log`, `console.debug`, `print()`, `debugger` statements
- [ ] `TODO`, `FIXME`, `HACK`, `XXX`, `TEMP`, `WIP` markers
- [ ] Commented-out code blocks
- [ ] Test data or mock values in production code
- [ ] Hardcoded `localhost` or `127.0.0.1` URLs

## Weirdness Severity

| Level | Meaning | Action |
|-------|---------|--------|
| Suspicious | Looks wrong, probably a bug | Investigate immediately |
| Inconsistent | Works but conflicts with patterns elsewhere | Align with codebase conventions |
| Fragile | Correct now but will break when assumptions change | Add guards or document the assumption |
| Vestigial | Leftover from a previous implementation | Remove if confirmed unused |
| Cosmetic | Misleading but harmless (e.g., wrong variable name) | Rename for clarity |

## Output Format

```markdown
## Soundness Analysis: [Scope]

### Suspicious
- **[Title]** — `file:line` — [why it looks wrong and what might actually happen]

### Inconsistent
- **[Title]** — `file:line` vs `file:line` — [how they differ and which is likely correct]

### Fragile
- **[Title]** — `file:line` — [what assumption it depends on and when it breaks]

### Vestigial
- **[Title]** — `file:line` — [what it was probably for and why it's no longer needed]

### Verdict
[Clean / Minor weirdness / Needs investigation]
```

## What This Skill Does NOT Cover

- Logical correctness (contradictions, invalid state machines, missing branches) — load the **logic-checker** skill
- Structural code quality (naming conventions, function design, duplication) — load the **quality** skill
- Security vulnerabilities (injection, auth bypass, data exposure) — load the **security** skill
- Performance issues (bottlenecks, memory leaks, algorithmic complexity) — not in scope
