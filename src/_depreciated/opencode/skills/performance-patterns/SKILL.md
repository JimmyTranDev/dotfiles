---
name: performance-patterns
description: Performance optimization patterns for TypeScript, React, database queries, bundle size, memory management, and shell scripts — with before/after examples
---

## Runtime (TypeScript / JavaScript)

```typescript
// O(n²) — avoid
items.filter(item => otherItems.includes(item.id))

// O(n) — prefer
const set = new Set(otherItems.map(o => o.id))
items.filter(item => set.has(item.id))

// String concatenation in loop — slow
let result = ''
for (const item of items) { result += item }

// Join — fast
const result = items.join('')
```

## React

```tsx
// New object reference every render — causes unnecessary re-renders
<Child style={{ color: 'red' }} />

// Stable reference — memoize
const style = useMemo(() => ({ color: 'red' }), [])

// Sorting on every render
const sorted = items.sort((a, b) => a.name.localeCompare(b.name))

// Memoized sort
const sorted = useMemo(() => [...items].sort((a, b) => a.name.localeCompare(b.name)), [items])

// Rendering all items in a large list
{items.map(item => <Item key={item.id} {...item} />)}

// Virtualized list
<VirtualList itemCount={items.length} itemSize={50} />
```

## Bundle Size

```typescript
// Entire library imported
import _ from 'lodash'

// Only what you need
import debounce from 'lodash/debounce'

// Upfront — blocks initial load
import { HeavyChart } from './charts'

// Code split — loaded on demand
const HeavyChart = lazy(() => import('./charts'))
```

## Database / API

```typescript
// N+1 query — one DB call per post
for (const post of posts) {
  post.author = await db.users.findUnique({ where: { id: post.authorId } })
}

// Single joined query
const posts = await db.posts.findMany({ include: { author: true } })
```

## Memory

```typescript
// Event listener leak — no cleanup
useEffect(() => {
  window.addEventListener('resize', handler)
}, [])

// Cleanup on unmount
useEffect(() => {
  window.addEventListener('resize', handler)
  return () => window.removeEventListener('resize', handler)
}, [])
```

## Shell / CLI

```bash
# 3 processes — wasteful
cat file | grep pattern | wc -l

# 1 process
grep -c pattern file

# Word splitting + subshell per iteration — slow
for f in $(find . -name "*.log"); do
  rm "$f"
done

# Single process
find . -name "*.log" -delete

# Subshell per iteration — slow
echo "$data" | while read line; do
  process "$line"
done

# No subshell — fast
while IFS= read -r line; do
  process "$line"
done <<< "$data"
```

## Optimization Approach

1. **Measure first**: Use profilers, not intuition — never optimize without a measurement
2. **Find the bottleneck**: 80% of time is in 20% of code
3. **Fix the biggest issue**: One optimization at a time
4. **Measure again**: Prove the improvement with numbers
5. **Document**: Record current perf, fix applied, and new perf

## Output Format for Optimization Reports

```
BOTTLENECK: [What's slow]
MEASUREMENT: [Current performance — ms, MB, requests/s]
CAUSE: [Why it's slow]
FIX: [Code change]
RESULT: [New performance]
IMPROVEMENT: [X% faster / X MB saved]
```
