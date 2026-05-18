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

- Use camelCase for files, folders, variables, functions, and properties
- Use PascalCase for types, interfaces, enums, and React components
- Use SCREAMING_SNAKE_CASE for constants and environment variables
- Prefix boolean variables with `is`, `has`, `should`, `can`
- Prefix hooks with `use`
- Name event handlers `handle<Event>` (internal) or `on<Event>` (prop)

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

## What This Skill Does NOT Cover

- React-specific component patterns — see **react-typescript** skill
- Advanced TypeScript type-level programming — see **ts-total-typescript** skill
- Naming conventions deep dive — see **code-naming** skill
