---
name: specify-review
description: Specify skill for code review — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`review-`

## Skills to Load

- **code-follower**: Match existing codebase conventions
- **code-logic-checker**: Find contradictions, invalid assumptions, logical gaps
- **code-soundness**: Find suspicious patterns and anomalies
- **code-conventions**: Coding conventions (optional)
- **strategy-pragmatic-programmer**: Design principles (optional)
- **ts-total-typescript**: TypeScript patterns (optional)
- **meta-shell-scripting**: Shell scripting conventions (optional)

## Agents to Launch

- **reviewer**: Catches bugs, design issues, and provides actionable feedback
- **auditor**: Scans for security vulnerabilities and exploitable bugs
- **optimizer**: Identifies performance concerns if potentially expensive operations are introduced

## Analysis Categories

- **Correctness**: Logic errors, wrong return values, incorrect conditionals, missing return paths, flawed comparisons
- **Internal consistency**: Contradictory conditions, mutually exclusive branches that overlap, impossible states not prevented
- **Completeness**: Missing branches, unhandled enum variants, gaps in state transitions, switch/if chains that don't cover all cases
- **Error handling**: Swallowed errors, missing try/catch, catch-all handlers hiding failures, unhandled promise rejections, missing error propagation
- **Edge cases**: Null/undefined access, empty collections, boundary values, zero-length strings, negative numbers, overflow, off-by-one errors
- **Boolean logic**: Flipped conditions, De Morgan's law violations, negation errors, short-circuit evaluation assumptions
- **Data flow**: Inputs not validated, type narrowing lost across boundaries, values that can be stale or undefined
- **Race conditions**: Async ordering bugs, missing awaits, shared mutable state, stale closures, fire-and-forget calls that should be awaited
- **State management**: Impossible states, missing state transitions, stale state reads, derived state that can desync, terminal states with outgoing edges
- **API contracts**: Mismatched types between caller/callee, undocumented assumptions about input shape, missing validation
- **Security**: Injection vectors, auth bypasses, sensitive data exposure, missing input sanitization

### Presentation

- Group by category, rank by severity within each
- Include a "Sound Logic" section noting what is correct and well-reasoned
- Include a "Fragile Assumptions" section for logic that works now but could break
- End with a verdict: Sound / Minor issues / Fundamental flaws

## Severity Classification

- **Critical**: Corrupts data, causes security bypass, or crashes the system
- **Major**: Produces wrong results under common conditions
- **Minor**: Only manifests under rare edge cases
- **Warning**: Valid logic that is fragile and likely to break with future changes

## Scope Overrides

If no scope is given, review the current branch's diff against the base branch:
- Check if `develop` exists (locally or as `origin/develop`) — use as base; otherwise fall back to `main`/`origin/main`
- Run: `git diff <base-branch>...HEAD` and `git log --oneline <base-branch>..HEAD`
- If no commits beyond the base, notify and stop
