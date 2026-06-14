---
name: inline-comments
description: When inline code comments add value versus noise — covers the useful cases (non-obvious why, workarounds, invariants, warnings, magic values) and the cases to avoid (restating code, commented-out code, redundant banners) across TypeScript, Java, and shell
---

Inline comments are not banned. The goal is to use them where they add real value and avoid them where they are noise. A good comment explains *why* the code is the way it is — something the code itself cannot express. A bad comment restates *what* the code already says.

This skill covers strictly **inline `//`-style comments** (and `#` in shell). Docstrings, Javadoc, JSDoc, and public-API doc comments are out of scope.

## Default Stance

- Prefer self-documenting code (clear names, small functions, guard clauses) over comments — see **code-conventions** and **code-naming**.
- Add a comment when the reader would otherwise ask "why is it done this way?" and the answer is non-obvious.
- When a comment is needed, keep it short, accurate, and placed directly above (or at the end of) the line it explains.
- A comment that can be deleted without losing information should be deleted.

## When Inline Comments Add Value

| Case | Why it helps | Example |
|------|--------------|---------|
| Non-obvious **why** | Captures intent or rationale not visible in the code | `// Stripe rounds half-up; match their behavior to avoid reconciliation drift` |
| **Workarounds / hacks** | Explains why a non-idiomatic path exists; link the issue | `// Safari < 16 fires resize twice — debounce to dedupe (see #4821)` |
| **Invariants & assumptions** | States a precondition the code relies on | `// callers must hold the lock before entering` |
| **Warnings** | Flags consequences of changing the code | `// order matters: auth middleware must run before rate limiting` |
| **Magic values** | Explains an otherwise unexplained constant | `// 86400 = seconds in a day` |
| **Complex regex / bitwise / math** | Decodes dense expressions | `// strip zero-width chars (U+200B–U+200D, U+FEFF)` |
| **TODO / FIXME / HACK** | Tracks known debt with context | `// TODO(jimmy): replace with batch endpoint once API ships` |
| **Why NOT** something | Prevents a "helpful" future change that would break things | `// do not memoize — input identity changes every render on purpose` |

## When to Avoid Inline Comments

| Anti-pattern | Problem | Fix |
|--------------|---------|-----|
| Restating the code | Adds noise, drifts out of date | `i++; // increment i` → delete it |
| Commented-out code | Dead weight; git already remembers | Delete it; recover from history if needed |
| Redundant section banners | `// ===== HELPERS =====` adds nothing | Use real structure / file splits instead |
| Obvious intent | `// constructor` above a constructor | Delete it |
| Compensating for bad names | Comment explains a cryptic variable | Rename the variable instead |
| Outdated / lying comments | Worse than no comment | Update or remove when touching the code |
| End-of-line clutter | Long trailing comments hurt readability | Move above the line, or simplify the code |

## Language-Specific Notes

| Language | Inline syntax | Notes |
|----------|---------------|-------|
| TypeScript / JavaScript | `//` | Reserve `/** */` for JSDoc on exported APIs (out of scope here). Keep inline `//` for the *why*. |
| Java | `//` | Use `//` for inline rationale; Javadoc `/** */` is for public API docs (out of scope). |
| Shell (bash/zsh) | `#` | Comment non-obvious flags, subshell tricks, and ordering constraints. The shebang line is not a comment. See **meta-shell-scripting**. |

## Quick Test Before Writing a Comment

1. Does the comment explain *why*, not *what*? If it only restates the code, drop it.
2. Could a better name or a smaller function remove the need? If yes, do that instead.
3. Will it stay true as the code evolves? If it is likely to rot, prefer making the code clearer.
4. Is it commented-out code? Delete it — git is the history.

If the comment survives all four, it earns its place.

## Related Skills

- **code-conventions** — self-documenting code principles (guard clauses, single responsibility, naming).
- **code-naming** — naming that reduces the need for explanatory comments.
- **meta-shell-scripting** — shell-specific conventions, including `#` comment usage.
