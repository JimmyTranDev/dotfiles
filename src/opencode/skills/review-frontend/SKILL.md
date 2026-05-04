---
name: review-frontend
description: "Frontend review checklist covering XSS prevention, bundle size, accessibility, performance, state management anti-patterns, and render optimization"
---

## XSS Prevention

### Critical Checks
- Never use `dangerouslySetInnerHTML` without sanitization (DOMPurify)
- Never interpolate user input into `href`, `src`, or `style` attributes
- Validate URLs start with `https://` or `/` — reject `javascript:` protocol
- Never use `eval()`, `new Function()`, or `document.write()`
- Sanitize rich text before rendering (DOMPurify with ALLOWED_TAGS)
- Check for `innerHTML` assignments in vanilla JS sections

### URL Handling
- Validate external URLs with `new URL()` constructor
- Reject `javascript:`, `data:`, `vbscript:` protocols
- Use `rel="noopener noreferrer"` on external links with `target="_blank"`

### Template Injection
- Never pass user input as template literal expressions in tag functions
- Avoid string concatenation for HTML generation

## Bundle Size

### Red Flags
- Importing entire library when tree-shakeable export exists (`import _ from 'lodash'` vs `import debounce from 'lodash/debounce'`)
- Moment.js (use date-fns or dayjs instead)
- Large dependencies in client bundle that should be server-only
- Missing dynamic imports for heavy components (modals, charts, editors)
- Barrel files re-exporting everything (`index.ts` with `export * from`)
- Images/assets imported directly without optimization

### Checks
- Verify `next/dynamic` or `React.lazy` for routes and heavy components
- Confirm CSS-in-JS libraries aren't duplicating styles
- Check for duplicate dependencies in lockfile (different versions of same package)
- Verify `sideEffects: false` in package.json for tree shaking
- Look for unused dependencies in package.json

## Accessibility

### Semantic HTML
- Interactive elements use `<button>` or `<a>`, never `<div onClick>`
- Form inputs have associated `<label>` elements (htmlFor/id match)
- Headings follow hierarchy (h1 > h2 > h3, no skipping levels)
- Lists use `<ul>`/`<ol>`/`<li>`, not styled divs
- Tables use `<table>` with `<thead>`, `<th scope>`, `<caption>`

### ARIA
- `aria-label` on icon-only buttons
- `aria-expanded` on toggles/accordions
- `aria-live="polite"` on dynamic content regions
- `role="alert"` for error messages
- `aria-describedby` linking inputs to error text
- Never use `aria-hidden="true"` on focusable elements

### Keyboard
- All interactive elements reachable via Tab
- Custom components handle Enter/Space for activation
- Escape closes modals/dropdowns
- Focus trapped inside open modals
- Focus restored after modal close
- Visible focus indicators (never `outline: none` without replacement)

### Color and Contrast
- Text contrast ratio >= 4.5:1 (3:1 for large text)
- Information not conveyed by color alone
- Focus indicators have 3:1 contrast against adjacent colors

## Performance

### Rendering
- No layout thrashing (reading then writing DOM in loops)
- Images have explicit `width`/`height` or aspect-ratio to prevent CLS
- Fonts use `font-display: swap` or `next/font`
- Above-the-fold content doesn't depend on JavaScript
- Critical CSS is inlined or loaded first

### Loading
- Images below fold use `loading="lazy"`
- Third-party scripts use `async` or `defer`
- Prefetch/preload for critical resources
- API calls deduplicated (React Query, SWR, or framework cache)
- No waterfall requests (parallel fetch where possible)

### Core Web Vitals Targets
| Metric | Good | Needs Work | Poor |
|--------|------|------------|------|
| LCP | < 2.5s | 2.5-4s | > 4s |
| INP | < 200ms | 200-500ms | > 500ms |
| CLS | < 0.1 | 0.1-0.25 | > 0.25 |

## State Management Anti-Patterns

### Prop Drilling
- More than 3 levels of prop passing = extract to context or state library
- Components receiving props they don't use (just forwarding)

### Over-Global State
- UI state (modal open, dropdown) stored in global store
- Form state in global store instead of local/form library
- Derived values stored as state instead of computed on render

### State Duplication
- Same data stored in multiple places (local + global + URL)
- Cache and state out of sync (stale data displayed)
- Copying props into state unnecessarily

### Missing URL State
- Filters, pagination, sort order not in URL (lost on refresh)
- Tab/accordion state not in URL when shareable

## Render Optimization

### Unnecessary Re-renders
- Missing `React.memo` on expensive pure components
- Inline object/array literals in JSX props (new reference every render)
- Inline function definitions in JSX without `useCallback`
- Context providers wrapping too much of the tree
- Context value changing reference on every render

### Patterns to Check
```tsx
// BAD: new object every render
<Component style={{ color: 'red' }} />

// GOOD: stable reference
const style = useMemo(() => ({ color: 'red' }), [])
<Component style={style} />
```

### Lists
- Missing `key` prop or using array index as key on dynamic lists
- Large lists without virtualization (react-window, tanstack-virtual)
- Entire list re-renders when single item changes

### Expensive Computations
- Heavy filtering/sorting without `useMemo`
- Complex derived state recalculated on unrelated state changes

## Error Handling

- Error boundaries wrapping route segments and critical UI
- Fallback UI for failed network requests (not just console.error)
- Form validation errors displayed inline near inputs
- Loading states for all async operations
- Empty states for lists with no data
- Timeout handling for slow network requests

## TypeScript Strictness

- No `any` types (use `unknown` + type narrowing)
- No non-null assertions (`!`) without proven safety
- Event handler types explicitly typed (not `any`)
- API response types validated at runtime (zod, valibot)
- Generic components properly constrained

## Testing Gaps

- Missing tests for error/loading/empty states
- Testing implementation details instead of behavior
- Missing accessibility assertions (`toBeInTheDocument`, role queries)
- No integration tests for critical user flows
- Mocking too much (testing mock, not real behavior)
