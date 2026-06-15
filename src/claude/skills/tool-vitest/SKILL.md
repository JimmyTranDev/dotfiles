---
name: tool-vitest
description: Vitest testing patterns covering config, mocking, snapshot testing, workspace mode, coverage, in-source testing, and comparison with Jest
---

## Config Setup

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
    include: ["src/**/*.{test,spec}.{ts,tsx}"],
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      include: ["src/**/*.ts"],
      exclude: ["src/**/*.test.ts", "src/**/*.d.ts", "src/test/**"],
      thresholds: {
        statements: 80,
        branches: 80,
        functions: 80,
        lines: 80,
      },
    },
  },
});
```

Setup file:

```ts
import { afterEach } from "vitest";
import { cleanup } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";

afterEach(() => {
  cleanup();
});
```

## Mocking

### vi.fn()

```ts
const handler = vi.fn();
handler("arg1", "arg2");

expect(handler).toHaveBeenCalledWith("arg1", "arg2");
expect(handler).toHaveBeenCalledTimes(1);

const mockFetch = vi.fn().mockResolvedValue({ data: [] });
const result = await mockFetch();
expect(result).toEqual({ data: [] });
```

### vi.mock()

```ts
vi.mock("./api", () => ({
  fetchUsers: vi.fn().mockResolvedValue([{ id: 1, name: "Alice" }]),
}));

vi.mock("@/lib/supabase", () => ({
  supabase: {
    from: vi.fn().mockReturnThis(),
    select: vi.fn().mockResolvedValue({ data: [], error: null }),
  },
}));
```

Partial mock (keep original exports):

```ts
vi.mock("./utils", async (importOriginal) => {
  const actual = await importOriginal<typeof import("./utils")>();
  return {
    ...actual,
    formatDate: vi.fn().mockReturnValue("2024-01-01"),
  };
});
```

### vi.spyOn()

```ts
const spy = vi.spyOn(console, "error").mockImplementation(() => {});
doSomething();
expect(spy).toHaveBeenCalledWith("expected error");
spy.mockRestore();
```

### Timer Mocking

```ts
beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

it("debounces calls", async () => {
  const fn = vi.fn();
  const debounced = debounce(fn, 300);

  debounced();
  debounced();
  debounced();

  expect(fn).not.toHaveBeenCalled();
  vi.advanceTimersByTime(300);
  expect(fn).toHaveBeenCalledTimes(1);
});
```

## Snapshot Testing

```ts
it("renders component correctly", () => {
  const { container } = render(<Button variant="primary">Click</Button>);
  expect(container).toMatchSnapshot();
});

it("serializes data structure", () => {
  const result = transformData(input);
  expect(result).toMatchInlineSnapshot(`
    {
      "id": 1,
      "status": "active",
    }
  `);
});
```

Update snapshots: `vitest --update` or press `u` in watch mode.

## Coverage Setup

Run coverage:

```bash
vitest run --coverage
```

| Provider | Speed | Accuracy | Setup |
|----------|-------|----------|-------|
| v8 | Fast | Good | Built-in |
| istanbul | Slower | Precise | `@vitest/coverage-istanbul` |

## Workspace Mode

```ts
import { defineWorkspace } from "vitest/config";

export default defineWorkspace([
  {
    test: {
      name: "unit",
      include: ["src/**/*.test.ts"],
      environment: "node",
    },
  },
  {
    test: {
      name: "browser",
      include: ["src/**/*.browser.test.ts"],
      environment: "jsdom",
    },
  },
  {
    test: {
      name: "integration",
      include: ["tests/**/*.test.ts"],
      environment: "node",
      testTimeout: 30000,
    },
  },
]);
```

Run specific workspace: `vitest --project unit`

> Vitest 3.2+ deprecates standalone workspace files (`defineWorkspace`) in favor of a `projects` array inside `test` in `vitest.config.ts`.

## In-Source Testing

```ts
export function add(a: number, b: number): number {
  return a + b;
}

if (import.meta.vitest) {
  const { it, expect } = import.meta.vitest;

  it("adds two numbers", () => {
    expect(add(1, 2)).toBe(3);
    expect(add(-1, 1)).toBe(0);
  });
}
```

Config requirement:

```ts
export default defineConfig({
  define: {
    "import.meta.vitest": "undefined",
  },
  test: {
    includeSource: ["src/**/*.ts"],
  },
});
```

## Async Testing Patterns

```ts
it("resolves async data", async () => {
  const result = await fetchData();
  expect(result).toEqual({ id: 1 });
});

it("rejects with error", async () => {
  await expect(fetchInvalid()).rejects.toThrow("Not found");
});

it("handles concurrent operations", async () => {
  const [a, b] = await Promise.all([fetchA(), fetchB()]);
  expect(a.status).toBe("ok");
  expect(b.status).toBe("ok");
});
```

## Common Assertions

| Assertion | Usage |
|-----------|-------|
| `toBe(value)` | Strict equality (===) |
| `toEqual(value)` | Deep equality |
| `toStrictEqual(value)` | Deep equality + same types |
| `toBeTruthy()` | Truthy check |
| `toBeNull()` | null check |
| `toBeUndefined()` | undefined check |
| `toContain(item)` | Array/string contains |
| `toHaveLength(n)` | Length check |
| `toThrow(msg?)` | Exception check |
| `toMatchObject(obj)` | Partial object match |
| `toHaveBeenCalledWith(...args)` | Mock call args |
| `toHaveProperty(key, value?)` | Object property check |

## Comparison with Jest

| Feature | Vitest | Jest |
|---------|--------|------|
| Config | `vitest.config.ts` | `jest.config.ts` |
| Speed | Native ESM, fast | Slower, CJS transform |
| Mocking | `vi.fn()`, `vi.mock()` | `jest.fn()`, `jest.mock()` |
| Globals | opt-in via config | default on |
| Watch mode | HMR-powered | file polling |
| TypeScript | native via Vite | needs transformer |
| Compatibility | Jest-compatible API | n/a |
| In-source tests | supported | not supported |
| Browser testing | `@vitest/browser` | needs separate tool |

Migration from Jest: replace `jest.` with `vi.`, update config, remove babel/ts-jest transforms.
