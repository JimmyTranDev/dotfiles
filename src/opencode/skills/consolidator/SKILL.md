---
name: consolidator
description: Patterns for merging over-separated code including file consolidation, layer collapsing, abstraction inlining, and config unification
---

Identify code that is split into more pieces than necessary and merge it back together. Over-separation adds indirection, increases cognitive load, and makes navigation harder.

## Over-Separation Smells

| Smell | Signal | Action |
|-------|--------|--------|
| Thin file | File has < 20 lines of actual logic | Merge into the nearest related file |
| Single-use wrapper | Function/component wraps another with no added logic | Inline the wrapper |
| Pointless layer | Module passes through calls without transformation | Remove the layer, call directly |
| Fragmented config | Related settings scattered across multiple files | Unify into one config file |
| One-item module | Directory contains a single file | Move file up and delete the directory |
| Premature split | Feature split into files before complexity warrants it | Merge until complexity actually demands splitting |
| Proxy component | Component renders another component with identical props | Inline or delete the proxy |
| Trivial abstraction | Helper function called once, body is 1-3 lines | Inline at the call site |

## Decision Tree

```
Is this file < 20 lines of logic?
├─ Yes → Does another file in the same module handle related concerns?
│        ├─ Yes → Merge into that file
│        └─ No  → Is it the only file in its directory?
│                 ├─ Yes → Move up one level, delete empty directory
│                 └─ No  → Leave it (it's part of a coherent module)
└─ No → Is this module a pass-through layer?
         ├─ Yes → Are callers using it just to reach the layer below?
         │        ├─ Yes → Remove layer, connect callers directly
         │        └─ No  → Layer adds value, keep it
         └─ No → Does this abstraction have only one caller?
                  ├─ Yes → Is the abstraction trivial (< 5 lines)?
                  │        ├─ Yes → Inline at the call site
                  │        └─ No  → Keep it (complex logic benefits from a name)
                  └─ No → Keep it (multiple callers = shared utility)
```

## File Consolidation

### When to Merge Files

- File has a single export used by one consumer
- Two files always change together (high coupling)
- Combined file would still be < 150 lines
- Files share the same domain and responsibility level

### When NOT to Merge

- Files represent genuinely different concerns (types vs. logic vs. constants)
- Combined file would exceed 200 lines
- Files have different change frequencies (stable types vs. volatile logic)
- Files are consumed by different parts of the codebase independently

### Merge Pattern

```
feature/
├── helpers.ts    (30 lines, used only by index.ts)
├── transform.ts  (15 lines, used only by index.ts)
└── index.ts      (50 lines)

→ Merge helpers.ts and transform.ts into index.ts (95 lines total)

feature/
└── index.ts      (95 lines)
```

## Layer Collapsing

### Identify Unnecessary Layers

```typescript
// service.ts — pure pass-through
const getUser = (id: string) => repository.getUser(id)
const saveUser = (user: User) => repository.saveUser(user)

// Fix: delete service.ts, import repository directly
```

### Keep Layers When

| Keep If | Example |
|---------|---------|
| Layer adds validation | Service validates before calling repo |
| Layer adds transformation | Controller maps DTO to domain model |
| Layer adds orchestration | Service coordinates multiple repos |
| Layer enforces boundaries | API layer hides internal implementation |

## Abstraction Inlining

### Inline When

- Function has a single call site
- Function body is 1-3 lines
- Function name doesn't add clarity beyond the code itself
- Function exists only because "everything should be a function"

```typescript
// before: trivial abstraction
const isPositive = (n: number) => n > 0
const result = items.filter(item => isPositive(item.count))

// after: inline
const result = items.filter(item => item.count > 0)
```

### Keep Abstraction When

- Called from 2+ locations
- Name communicates domain intent (`isEligibleForDiscount` vs `amount > 100`)
- Logic is likely to change (single point of modification)
- Body is complex enough that a name aids readability

## Config Consolidation

### Merge Fragmented Configs

```
// before: scattered
database.config.ts
cache.config.ts
queue.config.ts

// after: unified (if all are small and related)
config.ts
```

### Keep Configs Separate When

- Each config file is > 50 lines
- Configs are loaded independently at different times
- Configs belong to different deployment targets

## Component Consolidation

### Merge When

- Wrapper adds no props, state, or styling
- Two components always render together and share the same data
- Variant component differs by < 5 lines from the base

```tsx
// before: unnecessary split
const UserName = ({ name }: { name: string }) => <span>{name}</span>
const UserCard = ({ user }: { user: User }) => (
  <div>
    <UserName name={user.name} />
    <span>{user.email}</span>
  </div>
)

// after: inline trivial component
const UserCard = ({ user }: { user: User }) => (
  <div>
    <span>{user.name}</span>
    <span>{user.email}</span>
  </div>
)
```

### Keep Separate When

- Component has its own state or effects
- Component is reused across multiple parents
- Component has distinct styling or accessibility concerns
- Component is independently testable for complex logic

## Consolidation Process

1. **Identify** — find the over-separation smell
2. **Verify** — confirm the pieces aren't independently consumed or tested
3. **Measure** — check that merged result stays under 200 lines
4. **Merge** — combine the code, remove dead files/directories
5. **Update imports** — fix all consumers to use the new location
6. **Test** — verify no behavior changed

## What to Avoid

- Merging files that represent different concerns just because they're small
- Creating a single god file by consolidating too aggressively
- Inlining abstractions that communicate domain intent
- Removing layers that enforce architectural boundaries
- Consolidating without checking all import consumers first
