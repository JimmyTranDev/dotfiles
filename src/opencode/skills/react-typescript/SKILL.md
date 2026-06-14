---
name: react-typescript
description: TypeScript React conventions covering component patterns, hooks, Zustand state, React Query data fetching, React Hook Form + Zod validation, shadcn/ui components, Tailwind styling, Vitest + Playwright testing, and ESLint + Prettier setup
---

## Component Patterns

### File Structure

```
components/
  userCard/
    index.tsx        # Component export
    types.ts         # Props and local types
    consts.ts        # Constants
    utils.ts         # Pure helper functions
    hooks.ts         # Component-specific hooks
    userCard.test.tsx # Unit tests
```

### Component Definition

```tsx
import { type ComponentProps } from "react";

type UserCardProps = {
  name: string;
  email: string;
  avatarUrl?: string;
  onSelect?: (id: string) => void;
};

export function UserCard({ name, email, avatarUrl, onSelect }: UserCardProps) {
  return (
    <div className="flex items-center gap-3 rounded-lg border p-4">
      {avatarUrl && <img src={avatarUrl} alt={name} className="h-10 w-10 rounded-full" />}
      <div>
        <p className="font-medium">{name}</p>
        <p className="text-sm text-muted-foreground">{email}</p>
      </div>
    </div>
  );
}
```

### Rules

- Use named function declarations for components (not arrow functions assigned to const)
- Export components as named exports, not default exports
- Props type defined above the component in the same file (or `types.ts` if complex)
- Prefer `type` over `interface` for props (unless extending)
- Destructure props in the function signature
- Always use braces for control flow, even single-line bodies
- Colocate tests alongside the component

### Conditional Rendering

```tsx
// Good — early return for loading/error states
export function UserList({ users, isLoading, error }: UserListProps) {
  if (isLoading) {
    return <Skeleton />;
  }

  if (error) {
    return <ErrorMessage error={error} />;
  }

  if (users.length === 0) {
    return <EmptyState message="No users found" />;
  }

  return (
    <ul>
      {users.map((user) => (
        <li key={user.id}>
          <UserCard {...user} />
        </li>
      ))}
    </ul>
  );
}
```

### Composition Over Configuration

```tsx
// Bad — prop explosion
<Card variant="outlined" size="lg" hasHeader headerTitle="Users" hasFooter />

// Good — compound components
<Card>
  <Card.Header>
    <Card.Title>Users</Card.Title>
  </Card.Header>
  <Card.Content>{children}</Card.Content>
  <Card.Footer>{actions}</Card.Footer>
</Card>
```

---

## Hooks

### Custom Hook Structure

```tsx
// hooks/useDebounce/index.ts
import { useEffect, useState } from "react";

export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(timer);
    };
  }, [value, delay]);

  return debouncedValue;
}
```

### Rules

- Prefix with `use`
- Return a single value, tuple, or object (not arrays of 3+)
- Keep hooks focused — one responsibility per hook
- Extract complex logic from components into hooks
- Always specify cleanup functions for effects with subscriptions/timers
- Never call hooks conditionally

### Effect Patterns

```tsx
// Good — separate effects for separate concerns
useEffect(() => {
  document.title = `${count} items`;
}, [count]);

useEffect(() => {
  const sub = eventBus.subscribe(handler);
  return () => {
    sub.unsubscribe();
  };
}, [handler]);

// Bad — combined unrelated logic in one effect
useEffect(() => {
  document.title = `${count} items`;
  const sub = eventBus.subscribe(handler);
  return () => { sub.unsubscribe(); };
}, [count, handler]);
```

---

## Zustand State Management

One store per domain in `stores/use<Domain>Store.ts`. Define the state type explicitly, keep actions inside the store, and select narrowly.

```tsx
type AuthState = {
  user: User | null;
  token: string | null;
  login: (credentials: Credentials) => Promise<void>;
  logout: () => void;
};

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      login: async (credentials) => {
        const { user, token } = await authApi.login(credentials);
        set({ user, token });
      },
      logout: () => {
        set({ user: null, token: null });
      },
    }),
    { name: "auth-storage" },
  ),
);
```

### React Integration Rules

- **Never put server state in Zustand** — use React Query for fetched data
- Select narrowly (`useAuthStore((s) => s.user?.name)`), not the whole store
- Use `useShallow` for multi-field selects to avoid extra re-renders
- `persist` middleware for state that survives refresh

For slices, subscriptions, middleware, and store testing, see the **tool-zustand** skill.

---

## React Query (TanStack Query)

Use query-key factories, colocate queries per domain in `api/queries/use<Entity>.ts`, and keep `queryFn` thin by delegating to an API layer.

```tsx
const userKeys = {
  all: ["users"] as const,
  lists: () => [...userKeys.all, "list"] as const,
  list: (filters: UserFilters) => [...userKeys.lists(), filters] as const,
  detail: (id: string) => [...userKeys.all, "detail", id] as const,
};

export function useUsers(filters: UserFilters) {
  return useQuery({
    queryKey: userKeys.list(filters),
    queryFn: () => userApi.getUsers(filters),
  });
}

export function useCreateUser() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: userApi.createUser,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: userKeys.lists() });
    },
  });
}
```

### Rules

- Query-key factories — never inline key arrays
- `enabled` to conditionally fetch; set a sensible `staleTime` per query
- Invalidate related queries on mutations — don't refetch everything
- Keep server state here, never in Zustand

For optimistic updates, infinite queries, prefetching, and SSR hydration, see the **tool-react-query** skill.

---

## React Hook Form + Zod

### Form Pattern

```tsx
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

const createUserSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters"),
  email: z.string().email("Invalid email address"),
  role: z.enum(["admin", "user", "viewer"]),
  age: z.coerce.number().min(18).max(120).optional(),
});

type CreateUserForm = z.infer<typeof createUserSchema>;

export function CreateUserForm({ onSubmit }: { onSubmit: (data: CreateUserForm) => void }) {
  const form = useForm<CreateUserForm>({
    resolver: zodResolver(createUserSchema),
    defaultValues: {
      name: "",
      email: "",
      role: "user",
    },
  });

  return (
    <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <label htmlFor="name">Name</label>
        <input id="name" {...form.register("name")} />
        {form.formState.errors.name && (
          <p className="text-sm text-destructive">{form.formState.errors.name.message}</p>
        )}
      </div>
      <button type="submit" disabled={form.formState.isSubmitting}>
        Create User
      </button>
    </form>
  );
}
```

### Rules

- Infer form types from the Zod schema (`z.infer<typeof schema>`)
- Always provide `defaultValues` — never leave fields undefined
- Use `zodResolver` — don't write manual validation
- Use `z.coerce` for string inputs (numbers, dates)
- Show field-level errors inline, not in a toast; disable submit during `isSubmitting`
- For consistent styling, wrap fields in shadcn/ui `<Form>`/`<FormField>` components

Keep reusable schemas in `schemas/`. For schema details (refinements, transforms, unions), see the **tool-zod** skill.

---

## shadcn/ui Components

### Usage Rules

- Import from `@/components/ui/<component>`
- Customize via Tailwind classes and `cn()` utility — don't modify source files
- Compose primitives into domain-specific components
- Use the `variants` pattern (cva/class-variance-authority) for component variations

### cn() Utility

```tsx
// lib/utils.ts
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

### Extending shadcn Components

```tsx
import { Button, type ButtonProps } from "@/components/ui/button";
import { Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

type LoadingButtonProps = ButtonProps & {
  isLoading?: boolean;
};

export function LoadingButton({ isLoading, children, className, disabled, ...props }: LoadingButtonProps) {
  return (
    <Button className={cn(className)} disabled={disabled || isLoading} {...props}>
      {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
      {children}
    </Button>
  );
}
```

---

## Tailwind CSS Styling

- Tailwind utilities only — never inline `style` props
- Use `cn()` for conditional classes; mobile-first responsive (`base sm: md: lg:`)
- Extract repeated class combinations into components, not `@apply`
- Use `group`/`peer` for parent/sibling state; dark mode via `dark:` with the class strategy

```tsx
<div className={cn(
  "rounded-lg border p-4 transition-colors",
  isActive && "border-primary bg-primary/10",
  isDisabled && "cursor-not-allowed opacity-50",
)} />
```

Avoid one-off magic numbers (`w-[347px]`), chaining >8 utilities without extracting a component, and mixing Tailwind with CSS Modules or styled-components. For config, design tokens, plugins, and the `cn()` helper, see the **tool-tailwind** skill.

---

## Testing

Vitest + Testing Library for unit/integration, Playwright for E2E. Test behavior, not implementation.

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { UserCard } from "./index";

describe("UserCard", () => {
  it("calls onSelect when clicked", async () => {
    const user = userEvent.setup();
    const onSelect = vi.fn();

    render(<UserCard name="John" email="john@example.com" onSelect={onSelect} />);
    await user.click(screen.getByRole("button"));

    expect(onSelect).toHaveBeenCalledWith(expect.any(String));
  });
});
```

### Query Priority

1. `getByRole` — matches how users interact (preferred)
2. `getByLabelText` — form fields
3. `getByText` — visible content
4. `getByTestId` — last resort

### Rules

- Use `userEvent` over `fireEvent`; mock API at the network level (MSW)
- Wrap hooks that need providers (React Query, etc.) in a test wrapper
- Reset Zustand state in `beforeEach`; E2E covers critical flows only

For Vitest config, mocking, and coverage, see the **tool-vitest** skill. For cross-stack test strategy, see the **test** skill.

---

## ESLint + Prettier

Prettier handles formatting; ESLint handles correctness. For React + TypeScript, enable:

- `react-hooks/rules-of-hooks` (error) and `react-hooks/exhaustive-deps` (warn)
- `react/jsx-no-leaked-render` to catch `0 && <X />` render bugs
- `@typescript-eslint/consistent-type-imports` to enforce `import type`
- `@typescript-eslint/no-unused-vars` with `argsIgnorePattern: "^_"`
- `prettier-plugin-tailwindcss` for class sorting

For the full flat-config, plugin selection, and typed linting, see the **tool-eslint-config** skill.

---

## Project Structure

```
src/
  app/                    # Pages/routes (framework-specific)
  components/
    ui/                   # shadcn/ui primitives
    <domain>/             # Domain-specific composed components
  hooks/                  # Shared custom hooks
  stores/                 # Zustand stores
  api/
    client.ts             # HTTP client (axios/fetch wrapper)
    queries/              # React Query hooks per entity
  lib/
    utils.ts              # cn() and shared utilities
  schemas/                # Shared Zod schemas
  types/                  # Global TypeScript types
  consts/                 # App-wide constants
```

### Rules

- Feature code goes into `components/<domain>/` — not a flat components folder
- Shared hooks in `hooks/`, component-local hooks in `<component>/hooks.ts`
- API layer is separate from UI — components never call `fetch` directly
- Types that are used across multiple files go in `types/`
- Schemas shared between forms and API validation go in `schemas/`

---

## TypeScript in React

```tsx
// Discriminated unions for async state
type AsyncState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error };

// Extract props from a component
type ButtonProps = React.ComponentProps<typeof Button>;

// Make specific keys optional
type PartialBy<T, K extends keyof T> = Omit<T, K> & Partial<Pick<T, K>>;
```

- Prefer `type` over `interface` for props; use `as const` and `satisfies`
- Use discriminated unions over boolean flags for state
- Never use `any` — use `unknown` and narrow

For generics, conditional/mapped types, branded types, and utility types, see the **ts-total-typescript** skill.

---

## Performance

```tsx
const sortedUsers = useMemo(() => [...users].sort((a, b) => a.name.localeCompare(b.name)), [users]);
const handleSelect = useCallback((id: string) => setSelectedId(id), []);
const MemoizedUserCard = memo(UserCard);
```

- Don't prematurely memoize — measure first
- `useMemo` for expensive computations; `useCallback` for functions passed to memoized children; `memo()` for components re-rendering with stable props
- Virtualize long lists (>100 items) with `@tanstack/react-virtual`
- Lazy-load routes/heavy components with `React.lazy` + `Suspense`; `useTransition` for non-urgent updates

For runtime, bundle, database, and memory optimization across the stack, see the **performance-patterns** skill.

---

## Error Handling

### Error Boundaries

```tsx
import { ErrorBoundary } from "react-error-boundary";

function ErrorFallback({ error, resetErrorBoundary }: FallbackProps) {
  return (
    <div className="flex flex-col items-center gap-4 p-8">
      <h2 className="text-lg font-semibold">Something went wrong</h2>
      <p className="text-sm text-muted-foreground">{error.message}</p>
      <Button onClick={resetErrorBoundary}>Try again</Button>
    </div>
  );
}

// Usage
<ErrorBoundary FallbackComponent={ErrorFallback} onReset={() => queryClient.clear()}>
  <App />
</ErrorBoundary>
```

### Rules

- Wrap route-level components in error boundaries
- Use React Query's `error` state for API errors — don't throw in render
- Show user-friendly messages — never raw stack traces
- Log errors to a monitoring service (Sentry, etc.)
- Use `toast` for transient errors (network retry), error boundary for fatal errors

---

## Related Skills

This skill is the React integration overview. For deep dives, load:

- **tool-react-query** — caching, optimistic updates, infinite queries, SSR hydration
- **tool-zustand** — slices, middleware, store testing
- **tool-zod** — schema refinements, transforms, discriminated unions
- **tool-tailwind** — config, design tokens, plugins
- **tool-vitest** — config, mocking, coverage
- **tool-eslint-config** — flat config and typed linting
- **ts-total-typescript** — advanced type-level patterns
- **performance-patterns** — cross-stack optimization
- **code-conventions** — generic coding conventions
- **ui-designer**, **ui-animator**, **ui-accessibility** — visual design, animation, a11y

Server-side rendering specifics live in framework docs (Next.js, Remix).
