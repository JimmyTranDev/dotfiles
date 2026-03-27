---
name: react-patterns
description: React component conventions including styling with Tailwind, hook patterns, state management, and performance
---

## Component Structure

```tsx
const MyComponent = ({ variant = 'primary', size = 'md', ...props }: MyComponentProps) => {
  return (
    <div className={cn('base-classes', variants[variant], sizes[size])} {...props} />
  )
}
```

- Prefer function components with arrow syntax
- Destructure props with defaults inline
- Spread remaining props onto the root element
- Use `cn()` (clsx/tailwind-merge) for conditional class merging

## Styling

- **Tailwind CSS** utility classes — never custom CSS unless absolutely necessary
- CSS custom properties for theming
- Mobile-first responsive: base -> `md:` -> `lg:`
- No inline `style` except for dynamic values
- Use Tailwind's `cn()` pattern for conditional classes:

```tsx
className={cn(
  'inline-flex items-center justify-center rounded-md font-medium',
  'focus-visible:outline-none focus-visible:ring-2',
  'disabled:pointer-events-none disabled:opacity-50',
  variants[variant],
  sizes[size]
)}
```

## State Management

- Local state with `useState` for component-scoped data
- `useReducer` for complex state logic
- Context for cross-component data that doesn't change frequently
- External stores (Zustand/Redux) for global state
- Derive state from existing state — never duplicate

## Hook Patterns

- Custom hooks start with `use` prefix
- Extract shared logic into custom hooks
- Always include cleanup in `useEffect` return
- Specify dependency arrays explicitly — never lie about deps
- Prefer `useMemo`/`useCallback` only when needed (expensive computations, stable references for children)

## Form Patterns

```tsx
const TextField = ({ label, error, ...props }: TextFieldProps) => (
  <div className="space-y-1">
    <label htmlFor={props.id} className="text-sm font-medium">{label}</label>
    <input
      className={cn('w-full rounded-md border px-3 py-2', error && 'border-red-500')}
      aria-invalid={!!error}
      aria-describedby={error ? `${props.id}-error` : undefined}
      {...props}
    />
    {error && (
      <p id={`${props.id}-error`} className="text-sm text-red-500" role="alert">{error}</p>
    )}
  </div>
)
```

## Performance

- Virtualize long lists (react-window/react-virtuoso)
- Lazy load heavy components with `React.lazy()` + `Suspense`
- Avoid creating new object/array refs in render — use `useMemo`
- Never mutate state directly — spread or use `structuredClone`
- Debounce expensive handlers (search, resize)
