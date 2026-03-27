---
name: logic-checker
description: Checklist for finding contradictions, invalid assumptions, and logical gaps in code and requirements
---

Verify that logic is sound. Find contradictions, invalid assumptions, flawed reasoning, and logical gaps in code, requirements, and arguments.

## What to Check

**Internal Consistency**: Contradictory premises, mutually exclusive conditions, impossible states
**Validity**: Does conclusion follow from premises? Hidden assumptions? All cases covered?
**Common Errors**: Affirming the consequent, false dilemmas, circular reasoning

## Logic Bugs in Code

```typescript
if (user.isAdmin && !user.hasPermissions) { }  // Dead code: admins always have permissions

if (score > 80) return "A"
if (score > 60) return "B"
if (score > 80) return "A+"  // Never reached

function getDiscount(tier: "bronze" | "silver" | "gold") {
  if (tier === "bronze") return 0.05
  if (tier === "silver") return 0.10
  // gold returns undefined!
}

const first = items[0]              // Assumes non-empty
const average = sum / items.length  // NaN if empty
```

### Invalid State Transitions
```typescript
const validTransitions: Record<OrderStatus, OrderStatus[]> = {
  pending: ["paid", "cancelled"],
  paid: ["shipped", "refunded"],
  shipped: ["delivered"],
  delivered: []
}
```

## Analyzing Requirements

**Contradictions**: "Users can delete own posts" vs "Posts >30 days can't be deleted" — which wins?
**Gaps**: "Retry 3 times on failure" — how long between? What after 3 fails? Notify user?
**Ambiguity**: "Show recent activity" — how recent? Whose? What counts?

## Output Format

```markdown
## Logic Analysis: [Component/Feature]

### Valid Logic
- [What's sound]

### Issues Found
**CRITICAL: [Title]**
Location: [file:line]
Impact: [consequence]
Fix: [resolution]

**WARNING: [Title]**
...
```

## What to Avoid

- Just linting code — analyze the reasoning
- Accepting "it works" as proof of correctness
- Ignoring unlikely edge cases
- Validating logic you don't fully understand
