---
name: simplifier
description: Comprehensive refactoring and simplification guide with code smell detection, systematic patterns, complexity reduction strategies, and safe incremental transformation techniques
---

Simplify complex code by reducing complexity. Every change preserves behavior. Safe, incremental changes only.

## Code Smell Detection

### Complexity Smells

| Smell | Signal | Action |
|-------|--------|--------|
| Long function | > 20 lines or multiple concerns | Extract focused functions |
| Deep nesting | > 2 levels of indentation | Early returns, extract helpers |
| Long parameter list | > 3 parameters | Use options object |
| Boolean parameters | `fn(true, false)` | Split into named functions |
| Feature envy | Method uses another object's data more than its own | Move logic to that object |
| Shotgun surgery | One change requires editing many files | Consolidate related logic |
| Primitive obsession | Strings/numbers used for domain concepts | Extract value types |

### Structural Smells

| Smell | Signal | Action |
|-------|--------|--------|
| God object | Class/module doing too many things | Split by responsibility |
| Speculative generality | "Might need this later" code | Delete it (YAGNI) |
| Dead code | Unreachable branches, unused exports | Delete it |
| Duplicate logic | Same pattern in 3+ places | Extract shared utility |
| Middle man | Class that only delegates | Remove and call directly |
| Inappropriate intimacy | Modules reaching into each other's internals | Define clean interfaces |
| Data clumps | Same group of variables passed together | Extract into a type |

## Refactoring Patterns

For DRY extraction patterns (3+ occurrences), see the `deduplicator` skill.
For inlining trivial abstractions and removing pass-through layers, see the `consolidator` skill.

### Extract Function

```typescript
// before
function processOrder(order: Order) {
  const subtotal = order.items.reduce((sum, item) => sum + item.price * item.qty, 0)
  const tax = subtotal * 0.08
  const shipping = subtotal > 100 ? 0 : 9.99
  const total = subtotal + tax + shipping

  if (!order.customer.email) throw new Error('Missing email')
  if (!order.customer.address) throw new Error('Missing address')

  return { total, tax, shipping }
}

// after
const calculateSubtotal = (items: OrderItem[]) =>
  items.reduce((sum, item) => sum + item.price * item.qty, 0)

const calculateShipping = (subtotal: number) => subtotal > 100 ? 0 : 9.99

const validateCustomer = (customer: Customer) => {
  if (!customer.email) throw new Error('Missing email')
  if (!customer.address) throw new Error('Missing address')
}

function processOrder(order: Order) {
  validateCustomer(order.customer)
  const subtotal = calculateSubtotal(order.items)
  const tax = subtotal * 0.08
  const shipping = calculateShipping(subtotal)
  return { total: subtotal + tax + shipping, tax, shipping }
}
```

### Flatten Nested Conditionals

```typescript
// before
function getDiscount(user: User, order: Order) {
  if (user) {
    if (user.isPremium) {
      if (order.total > 100) {
        return 0.2
      } else {
        return 0.1
      }
    } else {
      if (order.total > 100) {
        return 0.05
      }
    }
  }
  return 0
}

// after
function getDiscount(user: User, order: Order) {
  if (!user) return 0
  if (user.isPremium) return order.total > 100 ? 0.2 : 0.1
  if (order.total > 100) return 0.05
  return 0
}
```

### Replace Conditional with Lookup

```typescript
// before
function getStatusLabel(status: string) {
  if (status === 'active') return 'Active'
  if (status === 'inactive') return 'Inactive'
  if (status === 'pending') return 'Pending Review'
  if (status === 'suspended') return 'Suspended'
  return 'Unknown'
}

// after
const STATUS_LABELS: Record<string, string> = {
  active: 'Active',
  inactive: 'Inactive',
  pending: 'Pending Review',
  suspended: 'Suspended',
}

const getStatusLabel = (status: string) => STATUS_LABELS[status] ?? 'Unknown'
```

### Replace Conditional with Strategy

```typescript
const pricingStrategies: Record<string, (price: number) => number> = {
  book: (price) => price * 0.9,
  electronics: (price) => price * 1.1,
  food: (price) => price,
}

const getPrice = (item: Item) => pricingStrategies[item.type](item.basePrice)
```

### Reduce Parameter Count

```typescript
// before
function createUser(
  name: string,
  email: string,
  age: number,
  role: string,
  department: string,
  isActive: boolean
) { ... }

// after
interface CreateUserInput {
  name: string
  email: string
  age: number
  role: string
  department: string
  isActive: boolean
}

function createUser(input: CreateUserInput) { ... }
```

### Replace Boolean Params with Named Functions

```typescript
// before
function fetchUsers(includeInactive: boolean) { ... }
fetchUsers(true)

// after
function fetchAllUsers() { ... }
function fetchActiveUsers() { ... }
```

### Eliminate Temporary Variables

```typescript
// before
function getFullName(user: User) {
  const first = user.firstName
  const last = user.lastName
  const full = `${first} ${last}`
  return full
}

// after
const getFullName = (user: User) => `${user.firstName} ${user.lastName}`
```

### Replace Imperative with Declarative

```typescript
// before
function getActiveEmails(users: User[]) {
  const result: string[] = []
  for (let i = 0; i < users.length; i++) {
    if (users[i].isActive) {
      result.push(users[i].email)
    }
  }
  return result
}

// after
const getActiveEmails = (users: User[]) =>
  users.filter(u => u.isActive).map(u => u.email)
```

### Consolidate Duplicate Branches

```typescript
// before
function handleResponse(res: Response) {
  if (res.status === 400) {
    logError(res)
    showToast('Request failed')
    return null
  }
  if (res.status === 401) {
    logError(res)
    showToast('Request failed')
    redirectToLogin()
    return null
  }
  if (res.status === 403) {
    logError(res)
    showToast('Request failed')
    return null
  }
  return res.data
}

// after
function handleResponse(res: Response) {
  if (res.status >= 400) {
    logError(res)
    showToast('Request failed')
    if (res.status === 401) redirectToLogin()
    return null
  }
  return res.data
}
```

### Derive State Instead of Storing It

```typescript
// before
interface Cart {
  items: CartItem[]
  itemCount: number
  totalPrice: number
  isEmpty: boolean
}

// after
interface Cart {
  items: CartItem[]
}

const getItemCount = (cart: Cart) => cart.items.length
const getTotalPrice = (cart: Cart) => cart.items.reduce((sum, i) => sum + i.price, 0)
const isEmpty = (cart: Cart) => cart.items.length === 0
```

### Simplify Async Chains

```typescript
// before
function loadUserProfile(userId: string) {
  return fetchUser(userId)
    .then(user => {
      return fetchUserPosts(user.id)
        .then(posts => {
          return fetchUserSettings(user.id)
            .then(settings => {
              return { user, posts, settings }
            })
        })
    })
}

// after
async function loadUserProfile(userId: string) {
  const user = await fetchUser(userId)
  const [posts, settings] = await Promise.all([
    fetchUserPosts(user.id),
    fetchUserSettings(user.id),
  ])
  return { user, posts, settings }
}
```

## Complexity Reduction Decision Tree

```
Is the function > 20 lines?
├─ Yes → Can it be split into independent concerns?
│        ├─ Yes → Extract each concern into its own function
│        └─ No  → Can some logic become a utility?
│                 ├─ Yes → Extract utility
│                 └─ No  → Leave it, but add early returns to flatten
└─ No → Is there deep nesting (> 2 levels)?
         ├─ Yes → Apply guard clauses / early returns
         └─ No  → Is there duplication?
                  ├─ Yes (3+) → Extract shared function
                  └─ No  → Code is likely fine
```

## Safe Refactoring Process

1. **Ensure tests exist** — don't refactor without a safety net
2. **Identify the smell** — name the specific problem before changing code
3. **One change at a time** — atomic commits, single pattern per step
4. **Run tests after each change** — catch regressions immediately
5. **Preserve behavior** — no functional changes during refactoring
6. **Review the diff** — verify the change is purely structural

## Refactoring Prioritization

| Priority | Criteria |
|----------|----------|
| High | Blocks current feature work or causes bugs |
| Medium | Duplicated logic (3+ occurrences), deeply nested code |
| Low | Style inconsistencies, minor naming improvements |
| Skip | Working code that is rarely touched |

## What to Avoid

- Adding new features while refactoring
- Changing behavior (that's fixing, not refactoring)
- Refactoring without tests
- Big bang rewrites — always incremental
- Over-abstracting — don't create abstractions for single-use cases
- Refactoring code that is rarely read or changed
- Renaming things just for preference when existing names are clear

Simplify. Don't change behavior. Keep tests green.
