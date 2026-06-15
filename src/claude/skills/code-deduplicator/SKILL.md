---
name: code-deduplicator
description: Code deduplication guide for extracting repeated patterns into reusable utilities, hooks, and components
---

Find duplicated code patterns and extract them into shared utilities. DRY applied systematically across a codebase without over-engineering.

## What to Hunt

### Duplicated Functions
```typescript
const formatPrice = (amount: number) => `$${amount.toFixed(2)}`   // file1.ts
const displayPrice = (value: number) => `$${value.toFixed(2)}`    // file2.ts
function priceString(num: number) { return '$' + num.toFixed(2) } // file3.ts

export const formatCurrency = (amount: number, currency = '$') =>
  `${currency}${amount.toFixed(2)}`
```

### Repeated React Patterns (loading/error/data)
```tsx
const useAsync = <T>(asyncFn: () => Promise<T>) => {
  const [state, setState] = useState<{
    loading: boolean; error: Error | null; data: T | null
  }>({ loading: true, error: null, data: null })

  useEffect(() => {
    asyncFn()
      .then(data => setState({ loading: false, error: null, data }))
      .catch(error => setState({ loading: false, error, data: null }))
  }, [])
  return state
}
```

### Scattered Validation, API Call Patterns
Extract into shared validators or API client utilities.

## When to Extract

- Same code appears **3+ times**
- Pattern is stable (not changing frequently)
- Abstraction is clear and easily named
- Tests can be written for the shared code

## When NOT to Extract

- Only appears twice (wait for third)
- Variations require complex configuration
- Abstraction is forced or unclear
- Duplication is coincidental, not conceptual

## Extraction Process

1. **Find duplicates** across the codebase
2. **Identify the core** common abstraction
3. **Name it well** — if naming is hard, abstraction is wrong
4. **Extract with tests**
5. **Replace all usages**
6. **Verify** existing tests still pass

## Output Format

```
DUPLICATION FOUND: [description]
OCCURRENCES: [count] in [files]
EXTRACTED TO: lib/[category]/[name].ts
REPLACEMENT: [before -> after]
FILES UPDATED: [list]
```

Find duplication. Extract it cleanly. Keep it simple.
