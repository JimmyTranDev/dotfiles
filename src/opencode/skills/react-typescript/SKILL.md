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

### Store Definition

```tsx
// stores/authStore.ts
import { create } from "zustand";
import { persist } from "zustand/middleware";

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

### Rules

- One store per domain (auth, cart, ui, etc.)
- Store files live in `stores/` directory
- Name the hook `use<Domain>Store`
- Define the state type explicitly (no inference for the full type)
- Use `useShallow` when selecting multiple fields to prevent unnecessary re-renders
- Keep stores flat — avoid deep nesting
- Actions live inside the store, not outside
- Use `persist` middleware for data that survives page refresh
- Never put server-state in Zustand — use React Query for that

### Selectors

```tsx
import { useShallow } from "zustand/react/shallow";

// Good — select only what you need
const userName = useAuthStore((state) => state.user?.name);

// Good — multiple fields with useShallow
const { user, logout } = useAuthStore(
  useShallow((state) => ({ user: state.user, logout: state.logout })),
);

// Bad — selecting the entire store
const store = useAuthStore();
```

---

## React Query (TanStack Query)

### Query Structure

```tsx
// api/queries/useUsers.ts
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

const userKeys = {
  all: ["users"] as const,
  lists: () => [...userKeys.all, "list"] as const,
  list: (filters: UserFilters) => [...userKeys.lists(), filters] as const,
  details: () => [...userKeys.all, "detail"] as const,
  detail: (id: string) => [...userKeys.details(), id] as const,
};

export function useUsers(filters: UserFilters) {
  return useQuery({
    queryKey: userKeys.list(filters),
    queryFn: () => userApi.getUsers(filters),
  });
}

export function useUser(id: string) {
  return useQuery({
    queryKey: userKeys.detail(id),
    queryFn: () => userApi.getUser(id),
    enabled: !!id,
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

- Use query key factories — never inline key arrays
- Colocate queries with their domain (`api/queries/use<Entity>.ts`)
- Use `enabled` to conditionally fetch
- Invalidate related queries on mutations — don't refetch everything
- Use optimistic updates for instant UI feedback on mutations
- Keep `queryFn` thin — delegate to an API layer function
- Separate API layer (`api/client.ts`) from query hooks
- Set sensible `staleTime` per query (default 0 is often too aggressive)

### Optimistic Updates

```tsx
export function useUpdateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: userApi.updateUser,
    onMutate: async (updatedUser) => {
      await queryClient.cancelQueries({ queryKey: userKeys.detail(updatedUser.id) });
      const previous = queryClient.getQueryData(userKeys.detail(updatedUser.id));
      queryClient.setQueryData(userKeys.detail(updatedUser.id), updatedUser);
      return { previous };
    },
    onError: (_err, updatedUser, context) => {
      if (context?.previous) {
        queryClient.setQueryData(userKeys.detail(updatedUser.id), context.previous);
      }
    },
    onSettled: (_data, _err, updatedUser) => {
      queryClient.invalidateQueries({ queryKey: userKeys.detail(updatedUser.id) });
    },
  });
}
```

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

- Define Zod schemas in a separate `schemas.ts` file if reused across forms/API
- Infer form types from Zod schema (`z.infer<typeof schema>`)
- Always provide `defaultValues` — never leave fields undefined
- Use `zodResolver` — don't write manual validation
- Use `z.coerce` for inputs that come as strings (numbers, dates)
- Show field-level errors inline, not in a toast
- Disable submit button during `isSubmitting`
- Use shadcn/ui `<Form>` components for consistent styling

### With shadcn/ui Form

```tsx
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";

export function CreateUserForm({ onSubmit }: Props) {
  const form = useForm<CreateUserForm>({
    resolver: zodResolver(createUserSchema),
    defaultValues: { name: "", email: "", role: "user" },
  });

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Name</FormLabel>
              <FormControl>
                <Input {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
      </form>
    </Form>
  );
}
```

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

### Rules

- Never use inline `style` props — Tailwind utilities only
- Use `cn()` for conditional classes
- Extract repeated class combinations into component abstractions, not `@apply`
- Use design tokens from `tailwind.config.ts` (colors, spacing, etc.)
- Mobile-first responsive: `base sm: md: lg: xl:`
- Use `group` and `peer` for parent/sibling state styling
- Dark mode via `dark:` prefix with class strategy

### Patterns

```tsx
// Conditional classes
<div className={cn(
  "rounded-lg border p-4 transition-colors",
  isActive && "border-primary bg-primary/10",
  isDisabled && "cursor-not-allowed opacity-50",
)} />

// Responsive
<div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3" />

// Group hover
<div className="group cursor-pointer">
  <span className="group-hover:text-primary">Hover parent</span>
</div>
```

### Do Not

- Don't use Tailwind for one-off magic numbers (`w-[347px]`) — use design tokens
- Don't chain more than ~8 utilities without extracting a component
- Don't use `@apply` in CSS files — extract a React component instead
- Don't mix Tailwind with CSS Modules or styled-components

---

## Testing

### Vitest Unit/Integration Tests

```tsx
// userCard/userCard.test.tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { UserCard } from "./index";

describe("UserCard", () => {
  it("renders user name and email", () => {
    render(<UserCard name="John" email="john@example.com" />);

    expect(screen.getByText("John")).toBeInTheDocument();
    expect(screen.getByText("john@example.com")).toBeInTheDocument();
  });

  it("calls onSelect when clicked", async () => {
    const user = userEvent.setup();
    const onSelect = vi.fn();

    render(<UserCard name="John" email="john@example.com" onSelect={onSelect} />);
    await user.click(screen.getByRole("button"));

    expect(onSelect).toHaveBeenCalledWith(expect.any(String));
  });

  it("does not render avatar when avatarUrl is undefined", () => {
    render(<UserCard name="John" email="john@example.com" />);

    expect(screen.queryByRole("img")).not.toBeInTheDocument();
  });
});
```

### Testing Hooks

```tsx
import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useUsers } from "./useUsers";

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
}

describe("useUsers", () => {
  it("fetches users successfully", async () => {
    const { result } = renderHook(() => useUsers({ page: 1 }), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data).toHaveLength(10);
  });
});
```

### Testing Zustand

```tsx
import { act } from "@testing-library/react";
import { useAuthStore } from "./authStore";

describe("authStore", () => {
  beforeEach(() => {
    useAuthStore.setState({ user: null, token: null });
  });

  it("sets user on login", async () => {
    await act(async () => {
      await useAuthStore.getState().login({ email: "a@b.com", password: "pw" });
    });

    expect(useAuthStore.getState().user).toEqual(expect.objectContaining({ email: "a@b.com" }));
  });

  it("clears state on logout", () => {
    useAuthStore.setState({ user: { id: "1", email: "a@b.com" } as User, token: "abc" });

    act(() => {
      useAuthStore.getState().logout();
    });

    expect(useAuthStore.getState().user).toBeNull();
    expect(useAuthStore.getState().token).toBeNull();
  });
});
```

### Playwright E2E Tests

```tsx
// e2e/auth.spec.ts
import { test, expect } from "@playwright/test";

test.describe("Authentication", () => {
  test("user can log in and see dashboard", async ({ page }) => {
    await page.goto("/login");

    await page.getByLabel("Email").fill("user@example.com");
    await page.getByLabel("Password").fill("password123");
    await page.getByRole("button", { name: "Sign in" }).click();

    await expect(page).toHaveURL("/dashboard");
    await expect(page.getByRole("heading", { name: "Welcome" })).toBeVisible();
  });

  test("shows validation errors for empty form", async ({ page }) => {
    await page.goto("/login");
    await page.getByRole("button", { name: "Sign in" }).click();

    await expect(page.getByText("Email is required")).toBeVisible();
    await expect(page.getByText("Password is required")).toBeVisible();
  });
});
```

### Testing Rules

- Test behavior, not implementation details
- Use `screen.getByRole` over `getByTestId` when possible
- Use `userEvent` over `fireEvent` for realistic interactions
- Mock API calls at the network level (MSW) for integration tests
- Reset store state in `beforeEach` for Zustand tests
- Wrap hooks that use providers in a test wrapper
- E2E tests cover critical user flows only — not every edge case
- Name tests as `it("does X when Y")` — describe behavior

---

## ESLint + Prettier

### ESLint Flat Config

```ts
// eslint.config.ts
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import prettier from "eslint-config-prettier";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  {
    plugins: { react, "react-hooks": reactHooks },
    rules: {
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "warn",
      "react/jsx-no-leaked-render": "error",
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "@typescript-eslint/consistent-type-imports": "error",
      "@typescript-eslint/no-unnecessary-condition": "error",
      "no-console": ["warn", { allow: ["warn", "error"] }],
    },
  },
  prettier,
);
```

### Prettier Config

```json
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "all",
  "printWidth": 100,
  "plugins": ["prettier-plugin-tailwindcss"]
}
```

### Rules

- Prettier handles formatting — ESLint handles logic/correctness only
- Use `prettier-plugin-tailwindcss` for class sorting
- Use `@typescript-eslint/consistent-type-imports` to enforce `import type`
- No unused variables (prefix with `_` if intentionally unused)
- No `console.log` in production code (warn level)

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

## TypeScript Patterns

### Discriminated Unions for State

```tsx
type AsyncState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error };
```

### Strict Event Handlers

```tsx
type EventMap = {
  "user:created": { user: User };
  "user:deleted": { userId: string };
};

function emit<K extends keyof EventMap>(event: K, payload: EventMap[K]): void;
```

### Utility Types

```tsx
// Make specific keys optional
type PartialBy<T, K extends keyof T> = Omit<T, K> & Partial<Pick<T, K>>;

// Extract component props
type ButtonProps = React.ComponentProps<typeof Button>;

// Strict omit that errors on invalid keys
type StrictOmit<T, K extends keyof T> = Pick<T, Exclude<keyof T, K>>;
```

### Rules

- Prefer `type` over `interface` unless extending/implementing
- Use `as const` for literal arrays and objects
- Use `satisfies` for type checking without widening
- Never use `any` — use `unknown` and narrow
- Use discriminated unions over boolean flags for state
- Prefer `Record<string, T>` over `{ [key: string]: T }`

---

## Performance Patterns

### Memoization

```tsx
// Memoize expensive computations
const sortedUsers = useMemo(() => {
  return [...users].sort((a, b) => a.name.localeCompare(b.name));
}, [users]);

// Memoize callbacks passed to child components
const handleSelect = useCallback((id: string) => {
  setSelectedId(id);
}, []);

// Memoize entire components that receive stable props
const MemoizedUserCard = memo(UserCard);
```

### Rules

- Don't prematurely memoize — measure first
- Use `useMemo` for expensive computations that depend on changing inputs
- Use `useCallback` for functions passed as props to memoized children
- Use `memo()` for components that re-render often with the same props
- Virtualize long lists (>100 items) with `@tanstack/react-virtual`
- Lazy-load routes and heavy components with `React.lazy` + `Suspense`
- Use `useTransition` for non-urgent state updates

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

## What This Skill Does NOT Cover

- Server-side rendering specifics — see framework docs (Next.js, Remix)
- Generic TypeScript patterns — see **ts-total-typescript** skill
- Generic coding conventions — see **code-conventions** skill
- Component visual design — see **ui-designer** skill
- Animation patterns — see **ui-animator** skill
- Accessibility — see **ui-accessibility** skill
