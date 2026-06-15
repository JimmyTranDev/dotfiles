---
name: code-conventions
description: Coding conventions covering general principles, conditional complexity, error handling, and TypeScript-specific patterns including module structure, imports, and project setup
---

## General Principles

- Avoid `else` blocks — use early returns and guard clauses instead, including inside `catch` blocks
- Don't create intermediate variables that just alias another variable without transformation (e.g., `const displayError = localError`) — use the original name directly
- Never swallow errors silently
- Provide meaningful error messages
- Always use braces `{}` for `if`/`else`/`for`/`while` — even single-line bodies
- Prefer pure functions — minimize side effects, keep functions deterministic
- Single responsibility — each function/module does one thing well
- DRY but not premature — extract only after 3+ repetitions or when logic diverges

## Conditional Complexity

### Guard Clauses

```ts
// Good — early return
function getDiscount(user: User): number {
  if (!user.isActive) {
    return 0;
  }

  if (!user.subscription) {
    return 0;
  }

  return user.subscription.discount;
}

// Bad — nested conditions
function getDiscount(user: User): number {
  if (user.isActive) {
    if (user.subscription) {
      return user.subscription.discount;
    }
  }
  return 0;
}
```

### Exhaustive Switches

```ts
// Use satisfies never for exhaustive checks
function getLabel(status: Status): string {
  switch (status) {
    case "active":
      return "Active";
    case "inactive":
      return "Inactive";
    case "pending":
      return "Pending";
    default: {
      const _exhaustive: never = status;
      return _exhaustive;
    }
  }
}
```

### Lookup Tables Over Chains

```ts
// Good — object lookup
const STATUS_COLORS: Record<Status, string> = {
  active: "green",
  inactive: "gray",
  pending: "yellow",
  error: "red",
};

const color = STATUS_COLORS[status];

// Bad — if/else chain
let color: string;
if (status === "active") {
  color = "green";
} else if (status === "inactive") {
  color = "gray";
} else if (status === "pending") {
  color = "yellow";
} else {
  color = "red";
}
```

## Error Handling

### Patterns

```ts
// Result type for expected failures
type Result<T, E = Error> =
  | { ok: true; data: T }
  | { ok: false; error: E };

async function fetchUser(id: string): Promise<Result<User>> {
  try {
    const user = await api.get(`/users/${id}`);
    return { ok: true, data: user };
  } catch (error) {
    return { ok: false, error: toError(error) };
  }
}

// Throw for exceptional/unexpected cases only
function divide(a: number, b: number): number {
  if (b === 0) {
    throw new Error("Division by zero");
  }
  return a / b;
}
```

### Rules

- Throw errors for programmer mistakes and exceptional cases
- Return `Result` types for expected domain failures (validation, not found, etc.)
- Always handle async errors with try/catch or `.catch()`
- Never use empty catch blocks — at minimum log the error
- Create domain-specific error classes for different failure categories
- Include context in error messages (what failed, with what input)

## TypeScript

### Code Rules

- Use strict null handling — always handle `null`/`undefined` cases
- Prefer `const` over `let`, never use `var`
- Prefer arrow functions for callbacks and simple functions
- Use named function declarations for top-level/exported functions
- Use template literals over string concatenation
- Use `type` over `interface` unless extending or implementing
- Use `satisfies` for type checking without widening
- Never use `any` — use `unknown` and narrow with type guards
- Use `as const` for literal arrays and objects
- Prefer `Record<string, T>` over `{ [key: string]: T }`

### Naming

Core rule: camelCase for values/files, PascalCase for types/components, SCREAMING_SNAKE_CASE for constants. Boolean prefixes (`is`/`has`/`should`/`can`), hook `use` prefix, and event handlers (`handle<Event>`/`on<Event>`). Load the **code-naming** skill for the full convention tables.

### Module Structure

- Components and hooks each get their own folder with `index.tsx` as the entry point
- Supporting files live alongside the entry point: `utils.ts`, `hooks.ts`, `consts.ts`, `types.ts`
- Colocate tests with the code they test

```
components/
  userCard/
    index.tsx
    types.ts
    consts.ts
    utils.ts
    userCard.test.tsx
  searchInput/
    index.tsx
    types.ts
    hooks.ts

hooks/
  useDebounce/
    index.ts
    types.ts
    useDebounce.test.ts
  useAuth/
    index.ts
    utils.ts
    consts.ts
```

### Imports

- External packages first, then internal modules, then relative
- Group imports by source with blank line between groups
- Use `import type` for type-only imports
- Prefer direct imports over barrel file re-exports when possible

```ts
import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";

import { useAuthStore } from "@/stores/authStore";
import { cn } from "@/lib/utils";

import type { UserCardProps } from "./types";
import { formatName } from "./utils";
import { MAX_NAME_LENGTH } from "./consts";
```

### Async Patterns

```ts
// Prefer async/await over .then() chains
async function loadUserData(id: string): Promise<UserData> {
  const user = await fetchUser(id);
  const preferences = await fetchPreferences(user.prefsId);
  return { ...user, preferences };
}

// Use Promise.all for independent async operations
async function loadDashboard(userId: string): Promise<Dashboard> {
  const [user, notifications, stats] = await Promise.all([
    fetchUser(userId),
    fetchNotifications(userId),
    fetchStats(userId),
  ]);
  return { user, notifications, stats };
}
```

### Project Setup Preferences

- **Package manager**: Prefer `pnpm` for projects, `bun` for scripts/tooling
- **Bundler**: Vite preferred
- **Linting**: ESLint + Prettier or Biome
- **Testing**: Vitest preferred
- **Type checking**: Strict mode enabled in `tsconfig.json`

## Function Design

### Parameter Rules

- Max 3 positional parameters — use an options object beyond that
- Required params first, optional params last
- Destructure options objects in the function signature

```ts
// Good — options object for many params
function createUser(options: {
  name: string;
  email: string;
  role?: Role;
  sendWelcome?: boolean;
}): User {
  const { name, email, role = "user", sendWelcome = true } = options;
  // ...
}

// Good — few params, positional is fine
function add(a: number, b: number): number {
  return a + b;
}
```

### Return Types

- Explicitly annotate return types for exported functions
- Infer return types for internal/private functions
- Return early for invalid inputs — don't nest the happy path

## Function Style

### Declaration vs Arrow

- Use named `function` declarations for top-level and exported functions
- Use arrow functions for callbacks, inline handlers, and short expressions
- Never mix — be consistent within a file

```ts
// Good — named declaration for top-level
export function formatCurrency(amount: number, currency: string): string {
  return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(amount);
}

// Good — arrow for callback
const activeUsers = users.filter((user) => user.isActive);

// Good — arrow for inline handler
<button onClick={() => setOpen(true)}>Open</button>

// Bad — arrow for top-level export
export const formatCurrency = (amount: number, currency: string): string => {
  return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(amount);
};
```

### Implicit Returns

- Use implicit return for single-expression arrow functions
- Switch to explicit return (with braces) when the expression spans multiple lines or has side effects

```ts
// Good — single expression, implicit return
const double = (n: number) => n * 2;
const names = users.map((u) => u.name);
const isAdmin = (user: User) => user.role === "admin";

// Good — multiline expression, explicit return
const getFullName = (user: User) => {
  return `${user.firstName} ${user.lastName}`;
};

// Good — side effect, explicit return
const handleClick = (id: string) => {
  track("clicked", { id });
  setSelected(id);
};

// Bad — complex implicit return is hard to read
const getUser = (id: string) => users.find((u) => u.id === id) ?? { id, name: "Unknown", role: "guest" as const };
```

### Function Length

- Aim for max ~30 lines per function body
- If a function exceeds 30 lines, extract helper functions
- If a function has more than 2 levels of nesting, refactor

### Single-Purpose Functions

```ts
// Good — each function does one thing
function validateEmail(email: string): boolean {
  return EMAIL_REGEX.test(email);
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function processEmail(email: string): Result<string> {
  const normalized = normalizeEmail(email);
  if (!validateEmail(normalized)) {
    return { ok: false, error: new Error("Invalid email") };
  }
  return { ok: true, data: normalized };
}

// Bad — one function doing validation + normalization + error handling + side effects
function handleEmail(email: string): string {
  // ... 50 lines of mixed concerns
}
```

---

## Object & Array Style

### Property Shorthand

- Use shorthand when the variable name matches the property name
- Use explicit syntax when renaming or computing properties

```ts
// Good — shorthand for matching names
const name = "Alice";
const email = "alice@example.com";
const user = { name, email, role: "admin" };

// Good — explicit for renamed/different
const user = {
  displayName: rawName,
  emailAddress: email,
  createdAt: new Date(),
};

// Bad — redundant explicit
const user = { name: name, email: email };
```

### Destructuring

Use destructuring pragmatically — when it improves readability, not dogmatically.

```ts
// Good — destructure in function params
function greet({ name, title }: User): string {
  return `Hello, ${title} ${name}`;
}

// Good — destructure when accessing multiple properties
const { data, error, isLoading } = useQuery({ queryKey: ["users"], queryFn: fetchUsers });

// Good — dot access when only one property or when context matters
const userName = response.data.user.name;
logger.info(event.type);

// Bad — destructuring when dot access is clearer
const { data: { user: { name } } } = response; // deeply nested destructuring hurts readability
```

### Spread Patterns

```ts
// Good — shallow clone with override
const updated = { ...user, name: "Bob" };

// Good — merge arrays
const allItems = [...existingItems, ...newItems];

// Good — rest for excluding props
const { password, ...safeUser } = user;

// Bad — spread in a loop (performance issue)
let result: Item[] = [];
for (const batch of batches) {
  result = [...result, ...batch]; // O(n^2)
}

// Good — use flat/concat instead
const result = batches.flat();
```

### Array Methods

```ts
// Prefer declarative array methods
const activeEmails = users
  .filter((user) => user.isActive)
  .map((user) => user.email);

// Use reduce sparingly — prefer map/filter chains
// Good — clear intent
const total = items.reduce((sum, item) => sum + item.price, 0);

// Bad — complex reduce that should be a loop
const grouped = items.reduce((acc, item) => {
  // ... 10 lines of grouping logic
}, {});

// Good — use a plain loop for complex accumulation
const grouped: Record<string, Item[]> = {};
for (const item of items) {
  const key = item.category;
  if (!grouped[key]) {
    grouped[key] = [];
  }
  grouped[key].push(item);
}

// Good — use Object.groupBy when available
const grouped = Object.groupBy(items, (item) => item.category);
```

### Multiline Formatting

```ts
// Objects: one property per line when 3+ properties or any line > 80 chars
const config = {
  apiUrl: "https://api.example.com",
  timeout: 5000,
  retries: 3,
};

// Short objects can be inline
const point = { x: 10, y: 20 };

// Arrays: inline if short, multiline if long
const colors = ["red", "green", "blue"];

const routes = [
  { path: "/", component: Home },
  { path: "/users", component: UserList },
  { path: "/users/:id", component: UserDetail },
];

// Trailing commas always — makes diffs cleaner
const user = {
  name: "Alice",
  email: "alice@example.com", // <-- trailing comma
};
```

### Ternaries

```ts
// Good — simple ternary inline
const label = isActive ? "Active" : "Inactive";

// Good — multiline for longer expressions
const message = hasPermission
  ? "You can edit this resource"
  : "Contact an admin for access";

// Bad — nested ternaries
const color = isError ? "red" : isWarning ? "yellow" : isSuccess ? "green" : "gray";

// Good — use a lookup or function instead
const STATUS_COLORS: Record<Status, string> = {
  error: "red",
  warning: "yellow",
  success: "green",
  default: "gray",
};
```

---

## What This Skill Does NOT Cover

- React-specific component patterns — see **react-typescript** skill
- Advanced TypeScript type-level programming — see **ts-total-typescript** skill
- Naming conventions deep dive — see **code-naming** skill
