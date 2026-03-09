---
name: simplifier
description: Refactoring guide applying DRY, KISS, YAGNI to reduce complexity while preserving behavior
---

Simplify complex code using DRY, KISS, and YAGNI. Every change preserves behavior while reducing complexity. Safe, incremental changes only.

## Core Principles

### DRY (Don't Repeat Yourself)
```typescript
const isValidEmail = (email: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
const validateUserEmail = (user: User) => isValidEmail(user.email)
```

### KISS (Keep It Simple)
```typescript
class UserServiceFactory {                                    // Over-engineered
  static createService(config: Config): UserService { ... }
}

const createUserService = (db: Database) => ({                // Simple
  getUser: (id: string) => db.query('SELECT * FROM users WHERE id = ?', [id])
})
```

### YAGNI (You Aren't Gonna Need It)
```typescript
interface User {
  id: string
  name: string
  futureField1?: string           // Remove speculative fields
  metadata?: Record<string, unknown>  // Remove "for extensibility"
}
```

## Key Refactoring Patterns

**Extract Function**: Split long functions with multiple concerns into small focused functions

**Replace Conditional with Strategy**:
```typescript
const pricingStrategies = {
  book: (price: number) => price * 0.9,
  electronics: (price: number) => price * 1.1,
  food: (price: number) => price,
}
const getPrice = (item: Item) => pricingStrategies[item.type](item.basePrice)
```

**Flatten Nested Conditionals**: Early returns instead of deep nesting
```typescript
function canAccess(user: User, resource: Resource) {
  if (!user || !user.isActive) return false
  if (!resource) return false
  return user.permissions.includes(resource.type)
}
```

**Remove Dead Code**: Delete commented-out code, unused variables, unreachable branches

## Safe Refactoring Process

1. **Ensure tests exist** — don't refactor without a safety net
2. **One change at a time** — atomic commits
3. **Run tests after each change** — catch regressions immediately
4. **Preserve behavior** — no functional changes during refactoring

## What to Avoid

- Adding new features while refactoring
- Changing behavior (that's fixing, not refactoring)
- Refactoring without tests
- Big bang rewrites

Simplify. Don't change behavior. Keep tests green.
