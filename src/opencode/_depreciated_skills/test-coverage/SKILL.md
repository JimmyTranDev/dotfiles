---
name: test-coverage
description: Test coverage analysis, gap identification, coverage targets, and strategies for improving test quality across TypeScript and shell projects
---

## Coverage Tools

| Stack | Tool | Config File | Run Command |
|-------|------|-------------|-------------|
| Vitest | `@vitest/coverage-v8` or `@vitest/coverage-istanbul` | `vitest.config.ts` | `vitest run --coverage` |
| Jest | `jest --coverage` (built-in v8/istanbul) | `jest.config.ts` | `jest --coverage` |
| Node native | `node --experimental-test-coverage` | none | `node --test --experimental-test-coverage` |
| Shell | `kcov` | none | `kcov /tmp/cov ./script.sh` |

## Coverage Metrics

| Metric | What It Measures | Priority |
|--------|-----------------|----------|
| Branch | Every `if`/`else`/`switch`/`??`/`&&` path taken | Highest |
| Function | Every function/method called at least once | High |
| Statement | Every executable statement reached | Medium |
| Line | Every line executed | Medium |

Branch coverage is the most valuable — 100% line coverage can still miss untested branches.

## Coverage Targets

| Code Category | Minimum Target | Ideal |
|---------------|---------------|-------|
| Core business logic | 90% branch | 95%+ |
| Utility/helper functions | 95% branch | 100% |
| API handlers/controllers | 80% branch | 90%+ |
| UI components | 70% branch | 85%+ |
| Generated/config code | Skip | Skip |

## Vitest Coverage Config

```typescript
export default defineConfig({
  test: {
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      include: ["src/**/*.ts"],
      exclude: [
        "src/**/*.test.ts",
        "src/**/*.spec.ts",
        "src/**/types.ts",
        "src/**/consts.ts",
        "src/**/*.d.ts",
      ],
      thresholds: {
        branches: 80,
        functions: 80,
        lines: 80,
        statements: 80,
      },
    },
  },
})
```

## Gap Identification Workflow

1. **Run coverage** — generate HTML report for visual inspection
2. **Sort by lowest branch coverage** — prioritize files with lowest branch %
3. **Identify uncovered branches** — look for red-highlighted `if`/`else`/`switch` paths
4. **Classify gaps** — decide if each gap is worth testing

| Gap Type | Action |
|----------|--------|
| Untested error path | Write test — errors are critical |
| Untested edge case (null, empty, boundary) | Write test — these cause prod bugs |
| Untested happy path variant | Write test — core behavior must be covered |
| Defensive code that can't be reached | Remove the dead code |
| Framework boilerplate | Exclude from coverage |

## Writing Tests to Fill Gaps

### Error Paths

```typescript
it("throws when user not found", async () => {
  mockDb.findUser.mockResolvedValue(null)
  await expect(getUser("missing-id")).rejects.toThrow("User not found")
})
```

### Branch Coverage for Conditionals

```typescript
it("applies discount for premium users", () => {
  expect(calculatePrice(100, { tier: "premium" })).toBe(80)
})

it("charges full price for free users", () => {
  expect(calculatePrice(100, { tier: "free" })).toBe(100)
})
```

### Boundary Values

```typescript
it.each([
  [0, "zero"],
  [1, "positive"],
  [-1, "negative"],
  [Number.MAX_SAFE_INTEGER, "positive"],
])("classifies %d as %s", (input, expected) => {
  expect(classify(input)).toBe(expected)
})
```

## Coverage Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Testing implementation details | Brittle, breaks on refactor | Test behavior and outputs |
| `istanbul ignore` everywhere | Hides real gaps | Only ignore truly unreachable code |
| Chasing 100% coverage | Diminishing returns, tests become noise | Focus on branch coverage of critical paths |
| Snapshot-only testing | High line coverage, low value | Add assertion-based tests for logic |
| Mocking everything | Tests pass but nothing actually works | Use real implementations where feasible |

## Coverage in CI

| Strategy | Command |
|----------|---------|
| Fail on threshold | `vitest run --coverage --coverage.thresholds.100=false` |
| Report in PR | Use `vitest-coverage-report` GitHub Action or `codecov` |
| Track trends | Upload lcov to Codecov/Coveralls |
| Block merges | Set coverage thresholds in config, CI fails if unmet |

## Excluding Code from Coverage

Use sparingly and only for genuinely untestable code:

```typescript
/* v8 ignore next */
const unreachableDefault = () => { throw new Error("unreachable") }

/* v8 ignore start */
if (import.meta.hot) {
  import.meta.hot.accept()
}
/* v8 ignore stop */
```

Valid exclusion reasons:
- HMR/dev-only code
- Truly unreachable defensive defaults (e.g., exhaustive switch)
- Platform-specific code that can't run in test environment

Invalid exclusion reasons:
- "Too hard to test" — refactor to make it testable
- Error handling — errors must be tested
- Complex conditionals — these need coverage the most

## Prioritization Matrix

When time is limited, prioritize coverage improvements by risk:

| Risk Level | What to Cover First |
|-----------|-------------------|
| Critical | Payment, auth, data mutation, security |
| High | Core business rules, API contracts, state management |
| Medium | UI interactions, form validation, routing |
| Low | Logging, analytics, cosmetic rendering |
