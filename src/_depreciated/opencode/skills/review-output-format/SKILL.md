---
name: review-output-format
description: Standard output format for code reviews — severity tiers, finding structure, verdict labels, and suppressed findings section
---

## Review Output Structure

```
## Review Summary
- 🔴 X critical | 🟡 Y important | 💡 Z suggestions
- Files reviewed: [list]
- Verdict: ship ✅ / fix first ⚠️ / needs rework 🚫

## Critical
🔴 **file:line** | Confidence: High
   [Issue description with why it matters]
   Fix: [Concrete fix]

## Important
🟡 **file:line** | Confidence: Medium
   [Issue description]
   Fix: [Concrete fix]

## Suggestions
💡 **file:line** | Confidence: Low
   [Issue description]
   Fix: [Concrete fix]

## Good Patterns Noticed
- [Positive observations]

## Suppressed Findings
- [Findings filtered during self-validation, with reason for suppression]
```

## Confidence Levels

- **High**: Clearly a bug, security issue, or logic error with concrete evidence
- **Medium**: Likely an issue but could be intentional — reviewer should verify
- **Low**: Suspicious but might be acceptable in context

## Verdict Labels

| Label | Meaning |
|-------|---------|
| `ship ✅` | No critical or important findings; ready to merge |
| `fix first ⚠️` | Important findings that should be addressed before merge |
| `needs rework 🚫` | Critical findings; significant changes required |

## Suppressed Findings

Include findings that were filtered during self-validation in the **Suppressed Findings** section with a reason. This ensures nothing is silently lost.

Reasons to suppress:
- Finding is intentional based on surrounding code patterns
- Convention in this codebase, not a bug
- Cosmetic or marginal — fixing would not meaningfully improve the code
