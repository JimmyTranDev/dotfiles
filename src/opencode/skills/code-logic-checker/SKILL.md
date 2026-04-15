---
name: code-logic-checker
description: Checklist for finding contradictions, invalid assumptions, impossible states, missing edge cases, and logical gaps in code and requirements
---

Verify that logic is sound. Find contradictions, invalid assumptions, flawed reasoning, and logical gaps in code, requirements, and arguments.

## What to Check

| Category | What to Look For |
|----------|-----------------|
| Internal consistency | Contradictory premises, mutually exclusive conditions, impossible states |
| Validity | Does conclusion follow from premises? Hidden assumptions? All cases covered? |
| Completeness | Missing branches, unhandled enum variants, gaps in state transitions |
| Boundary behavior | Off-by-one, empty collections, zero/null/undefined, max values |
| Temporal correctness | Race conditions, stale data, ordering assumptions |

## Logic Bugs in Code

### Dead Code and Unreachable Branches

```typescript
if (user.isAdmin && !user.hasPermissions) { }  // admins always have permissions — dead code

if (score > 80) return "A"
if (score > 60) return "B"
if (score > 80) return "A+"  // never reached — shadowed by first condition
```

### Missing Return Paths

```typescript
function getDiscount(tier: "bronze" | "silver" | "gold") {
  if (tier === "bronze") return 0.05
  if (tier === "silver") return 0.10
  // gold returns undefined
}
```

### Unsafe Assumptions

```typescript
const first = items[0]              // assumes non-empty
const average = sum / items.length  // NaN if empty
const parsed = JSON.parse(input)    // assumes valid JSON
const match = regex.exec(str)![1]   // assumes match exists
```

### Contradictory Conditions

```typescript
if (status === "active" && status === "inactive") { }  // always false

if (count > 0) {
  if (count === 0) { }  // impossible inside parent branch
}
```

### Boolean Logic Errors

```typescript
// intention: deny if NOT admin AND NOT owner
if (!user.isAdmin && !user.isOwner) deny()  // correct

// common mistake: flipped logic (De Morgan's)
if (!(user.isAdmin && user.isOwner)) deny()  // wrong: denies admins who aren't owners
```

### Off-by-One and Boundary Errors

```typescript
for (let i = 0; i <= items.length; i++) { }     // reads past end
const last = items[items.length]                  // undefined, should be length - 1
const page = Math.ceil(total / pageSize) - 1      // off-by-one on last page
```

## Invalid State Transitions

```typescript
const validTransitions: Record<OrderStatus, OrderStatus[]> = {
  pending: ["paid", "cancelled"],
  paid: ["shipped", "refunded"],
  shipped: ["delivered"],
  delivered: [],
  cancelled: [],
  refunded: [],
}
```

Check for:
- Missing states in the transition map
- Transitions that skip required intermediate states
- Terminal states that have outgoing transitions
- States with no incoming transitions (unreachable)

## Analyzing Requirements

### Contradictions
"Users can delete their own posts" vs "Posts older than 30 days cannot be deleted" — which rule wins when a user tries to delete their own 60-day-old post?

### Gaps
"Retry 3 times on failure" — how long between retries? What happens after 3 failures? Is the user notified? Is it logged?

### Ambiguity
"Show recent activity" — how recent? Whose activity? What actions count? What's the sort order?

### Implicit Dependencies
"Send welcome email after registration" — what if email service is down? Does registration still succeed? Is the email queued?

## Data Flow Analysis

1. **Trace inputs to outputs** — follow user input from entry point through transformations to storage/response
2. **Check type narrowing** — verify that type checks actually narrow correctly and aren't lost across function boundaries
3. **Verify error propagation** — ensure errors from deep calls surface correctly, not swallowed by catch-all handlers
4. **Check async ordering** — parallel operations that assume sequential execution, missing `await`, fire-and-forget calls that should be awaited

## Severity Classification

| Severity | Criteria |
|----------|----------|
| Critical | Logic error that corrupts data, causes security bypass, or crashes the system |
| Major | Logic error that produces wrong results under common conditions |
| Minor | Logic error that only manifests under rare edge cases |
| Warning | Valid logic that is fragile — correct now but likely to break with future changes |

## Output Format

```markdown
## Logic Analysis: [Component/Feature]

### Sound Logic
- [What's correct and well-reasoned]

### Issues Found

**CRITICAL: [Title]**
Location: [file:line]
Impact: [consequence]
Fix: [resolution]

**MAJOR: [Title]**
Location: [file:line]
Impact: [consequence]
Fix: [resolution]

### Fragile Assumptions
- [Assumptions that are valid now but could break]

### Verdict
[Sound / Minor issues / Fundamental flaws]
```

## What to Avoid

- Linting code — analyze the reasoning, not the style
- Accepting "it works" as proof of correctness
- Ignoring unlikely edge cases — they become likely at scale
- Validating logic you don't fully understand — trace through it first
- Conflating readability issues with logic errors
