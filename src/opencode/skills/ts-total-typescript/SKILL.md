---
name: ts-total-typescript
description: Advanced TypeScript patterns including type-level programming, generics, discriminated unions, branded types, inference, utility types, overloads, and strict patterns
---

## Type vs Interface

| Use | When |
|-----|------|
| `type` | Unions, intersections, mapped types, conditional types, primitives, tuples |
| `interface` | Object shapes that may be extended or implemented by classes |

```ts
type Result<T> = { success: true; data: T } | { success: false; error: Error }

interface Repository {
  findById(id: string): Promise<Entity | null>
}
```

## Generics

Constrain generics to the narrowest useful type. Use defaults when a common case exists.

```ts
const groupBy = <T, K extends string | number>(
  items: T[],
  keyFn: (item: T) => K,
): Record<K, T[]> => {
  return items.reduce(
    (acc, item) => {
      const key = keyFn(item)
      ;(acc[key] ??= []).push(item)
      return acc
    },
    {} as Record<K, T[]>,
  )
}
```

Avoid single-letter generics beyond `T`, `K`, `V`. Use descriptive names for complex signatures.

```ts
const merge = <TBase extends object, TOverride extends Partial<TBase>>(
  base: TBase,
  override: TOverride,
): TBase & TOverride => ({ ...base, ...override })
```

## Discriminated Unions

Always use a literal `type` or `kind` field as the discriminant. Exhaustive checking via `never`.

```ts
type Action =
  | { type: "create"; payload: CreatePayload }
  | { type: "update"; payload: UpdatePayload }
  | { type: "delete"; id: string }

const handleAction = (action: Action) => {
  switch (action.type) {
    case "create":
      return createItem(action.payload)
    case "update":
      return updateItem(action.payload)
    case "delete":
      return deleteItem(action.id)
    default:
      return action satisfies never
  }
}
```

## Branded Types

Prevent primitive type confusion by branding.

```ts
type UserId = string & { readonly __brand: "UserId" }
type OrderId = string & { readonly __brand: "OrderId" }

const createUserId = (id: string): UserId => id as UserId
const createOrderId = (id: string): OrderId => id as OrderId
```

## Const Assertions and Enums

Prefer `as const` objects over TypeScript enums.

```ts
const STATUS = {
  active: "active",
  inactive: "inactive",
  pending: "pending",
} as const

type Status = (typeof STATUS)[keyof typeof STATUS]
```

## Conditional Types

```ts
type IsArray<T> = T extends readonly unknown[] ? true : false

type UnwrapPromise<T> = T extends Promise<infer U> ? U : T

type ExtractRouteParams<T extends string> =
  T extends `${string}:${infer Param}/${infer Rest}`
    ? Param | ExtractRouteParams<Rest>
    : T extends `${string}:${infer Param}`
      ? Param
      : never
```

## Mapped Types

```ts
type Readonly<T> = { readonly [K in keyof T]: T[K] }

type Optional<T, K extends keyof T> = Omit<T, K> & Partial<Pick<T, K>>

type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K]
}
```

## Template Literal Types

```ts
type EventName<T extends string> = `on${Capitalize<T>}`

type CSSProperty = `${string}-${string}`

type HttpMethod = "GET" | "POST" | "PUT" | "DELETE" | "PATCH"
type ApiRoute = `/${string}`
type Endpoint = `${HttpMethod} ${ApiRoute}`
```

## Utility Type Patterns

| Type | Purpose |
|------|---------|
| `Partial<T>` | All properties optional |
| `Required<T>` | All properties required |
| `Pick<T, K>` | Subset of properties |
| `Omit<T, K>` | Exclude properties |
| `Record<K, V>` | Key-value map |
| `Extract<T, U>` | Members of T assignable to U |
| `Exclude<T, U>` | Members of T not assignable to U |
| `NonNullable<T>` | Remove null and undefined |
| `ReturnType<T>` | Return type of function |
| `Parameters<T>` | Parameter types as tuple |
| `Awaited<T>` | Unwrap Promise recursively |
| `NoInfer<T>` | Prevent inference from this position |

## Type Narrowing

Prefer narrowing over type assertions. Use type predicates for reusable guards.

```ts
const isNonNull = <T>(value: T | null | undefined): value is T => value != null

const isError = (value: unknown): value is Error => value instanceof Error

const hasProperty = <K extends string>(
  obj: unknown,
  key: K,
): obj is Record<K, unknown> =>
  typeof obj === "object" && obj !== null && key in obj
```

## Function Overloads

Use overloads when return type depends on input type. Keep implementation signature broad.

```ts
function parse(input: string): JsonValue
function parse(input: Buffer): JsonValue
function parse(input: string | Buffer): JsonValue {
  const raw = typeof input === "string" ? input : input.toString("utf-8")
  return JSON.parse(raw)
}
```

Prefer unions or generics over overloads when the logic is identical.

## satisfies Operator

Use `satisfies` to validate a value matches a type without widening it.

```ts
const config = {
  port: 3000,
  host: "localhost",
  debug: true,
} satisfies Record<string, string | number | boolean>
```

## Strict Patterns

- Enable all strict `tsconfig` options: `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`
- Use `unknown` over `any` — narrow before use
- Prefer `Record<string, unknown>` over `object` for arbitrary key-value
- Use `readonly` arrays and tuples for data that should not be mutated
- Prefer `as const` assertions over manual literal type annotations

```ts
const processInput = (input: unknown) => {
  if (typeof input === "string") {
    return input.toUpperCase()
  }
  if (Array.isArray(input)) {
    return input.length
  }
  throw new Error("Unsupported input type")
}
```

## Zod Integration

Derive TypeScript types from Zod schemas — single source of truth.

```ts
import { z } from "zod"

const userSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  role: z.enum(["admin", "user", "guest"]),
  createdAt: z.coerce.date(),
})

type User = z.infer<typeof userSchema>

const parseUser = (data: unknown): User => userSchema.parse(data)
```

## Module Patterns

### Namespace-style exports for related utilities

```ts
export const DateUtils = {
  format: (date: Date, pattern: string): string => { ... },
  parse: (input: string): Date => { ... },
  isValid: (date: unknown): date is Date => { ... },
} as const
```

### Builder pattern with method chaining

```ts
class QueryBuilder<T> {
  private filters: Array<(item: T) => boolean> = []

  where(predicate: (item: T) => boolean): this {
    this.filters.push(predicate)
    return this
  }

  build(): (items: T[]) => T[] {
    return (items) => items.filter((item) => this.filters.every((f) => f(item)))
  }
}
```

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| `any` leaking through imports | Use `@typescript-eslint/no-unsafe-*` rules |
| Forgetting `noUncheckedIndexedAccess` | Enable in tsconfig, handle `undefined` from index access |
| Enum runtime overhead | Use `as const` objects instead |
| Overly complex conditional types | Break into named helper types |
| Type assertions hiding bugs | Use type guards and narrowing instead |
| `{}` type meaning "any non-nullish" | Use `Record<string, unknown>` or `object` |
