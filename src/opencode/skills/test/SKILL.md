---
name: test
description: Testing patterns covering test types, structure, naming, mocking strategies, coverage goals, framework setup, and CI integration across unit, integration, and e2e tests
---

## Test Types

| Type | Scope | Speed | Dependencies |
|------|-------|-------|-------------|
| Unit | Single function/module | < 1s | None (mocked) |
| Integration | Module boundaries | < 10s | Real DB, API stubs |
| E2E | Full user flow | < 60s | Real browser/app |
| Snapshot | UI output stability | < 1s | Renderer |

## Test Structure (AAA)

Every test follows Arrange-Act-Assert:

```typescript
test('rejects expired tokens', () => {
  const token = createToken({ expiresAt: Date.now() - 1000 })

  const result = validateToken(token)

  expect(result).toEqual({ valid: false, reason: 'expired' })
})
```

## Naming Conventions

**Test files**: colocate with source — `utils.ts` -> `utils.test.ts`

**Describe blocks**: name the unit under test

**Test names**: describe the behavior, not the method

| Bad | Good |
|-----|------|
| `test('calculateTotal')` | `test('adds tax to subtotal for taxable items')` |
| `test('handles error')` | `test('returns 404 when user not found')` |
| `test('works correctly')` | `test('merges overlapping date ranges into single range')` |

## What to Test

### Always Test

- Public API contracts and return values
- Edge cases: empty, null, undefined, zero, negative, boundary values
- Error paths: invalid input, network failures, timeouts
- Business logic and state transitions
- Async behavior: race conditions, concurrent access

### Skip Testing

- Simple getters/setters with no logic
- Framework internals (React rendering, Express routing)
- Third-party library behavior
- Implementation details that change during refactoring

## Mocking Strategy

### Mock External, Not Internal

```typescript
vi.mock('./database', () => ({
  query: vi.fn(),
}))

const result = await getUserOrders('user-123')

expect(database.query).toHaveBeenCalledWith(
  expect.stringContaining('SELECT'),
  ['user-123']
)
```

### Mock Hierarchy

| Priority | What to mock | Example |
|----------|-------------|---------|
| Always | HTTP/network calls | `vi.mock('axios')` |
| Always | File system in unit tests | `vi.mock('fs')` |
| Always | Timers and dates | `vi.useFakeTimers()` |
| Sometimes | Database in unit tests | `vi.mock('./db')` |
| Rarely | Your own modules | Prefer real implementations |
| Never | The thing under test | Defeats the purpose |

### Prefer Dependency Injection Over Mocking

```typescript
function createUserService(db: Database, mailer: Mailer) {
  return {
    async register(email: string) {
      const user = await db.insert({ email })
      await mailer.send(user.email, 'Welcome')
      return user
    },
  }
}

test('sends welcome email on registration', async () => {
  const fakeMailer = { send: vi.fn() }
  const fakeDb = { insert: vi.fn().mockResolvedValue({ id: '1', email: 'a@b.com' }) }
  const service = createUserService(fakeDb, fakeMailer)

  await service.register('a@b.com')

  expect(fakeMailer.send).toHaveBeenCalledWith('a@b.com', 'Welcome')
})
```

## Framework Setup

### Vitest (Preferred)

```typescript
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['**/*.test.ts'],
    coverage: {
      provider: 'v8',
      include: ['src/**'],
      exclude: ['**/*.test.ts', '**/*.d.ts', '**/types.ts'],
    },
  },
})
```

### Jest

```typescript
const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/*.test.ts'],
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts'],
}
```

### Playwright (E2E)

```typescript
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  timeout: 30_000,
  retries: 2,
  use: {
    baseURL: 'http://localhost:3000',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
})
```

## Coverage Goals

| Metric | Target | Notes |
|--------|--------|-------|
| Line coverage | 80%+ | Focus on business logic, not boilerplate |
| Branch coverage | 75%+ | Ensure error paths are tested |
| Critical paths | 100% | Auth, payments, data mutations |

Coverage is a guide, not a goal — 100% coverage with bad tests is worse than 70% with good tests.

## Test Isolation

- Each test must be independent — no shared mutable state between tests
- Use `beforeEach` for setup, not `beforeAll` (unless read-only fixtures)
- Clean up side effects: reset mocks, clear databases, restore timers

```typescript
beforeEach(() => {
  vi.clearAllMocks()
  vi.useRealTimers()
})
```

## Async Testing

```typescript
test('rejects on network timeout', async () => {
  vi.useFakeTimers()
  const promise = fetchWithTimeout('/api/data', { timeout: 5000 })

  await vi.advanceTimersByTimeAsync(5000)

  await expect(promise).rejects.toThrow('Request timed out')
  vi.useRealTimers()
})
```

## React Component Testing

```typescript
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

test('disables submit button while form is submitting', async () => {
  const user = userEvent.setup()
  render(<LoginForm />)

  await user.type(screen.getByLabelText('Email'), 'test@test.com')
  await user.click(screen.getByRole('button', { name: 'Submit' }))

  expect(screen.getByRole('button', { name: 'Submit' })).toBeDisabled()
})
```

### React Testing Priorities

1. **Query by role** (`getByRole`) — matches how users interact
2. **Query by label** (`getByLabelText`) — matches accessible patterns
3. **Query by text** (`getByText`) — matches visible content
4. **Query by test ID** (`getByTestId`) — last resort

## CI Integration

- Run unit tests on every push
- Run integration tests on PR creation and updates
- Run e2e tests before merge to main
- Fail the pipeline on coverage regression > 2%
- Cache test dependencies and build artifacts

## Test Smells

| Smell | Problem | Fix |
|-------|---------|-----|
| Test mirrors implementation | Breaks on every refactor | Test inputs and outputs only |
| Giant test with 10+ assertions | Unclear what failed | Split into focused tests |
| Tests require specific order | Shared mutable state | Isolate each test |
| Flaky pass/fail | Timing, network, or race condition | Mock time, use deterministic data |
| Commented-out tests | Dead code, hiding failures | Delete or fix them |
| Test name says "should work" | No useful failure message | Describe the expected behavior |

## What This Skill Does NOT Cover

- Security-specific testing (penetration, fuzzing) — see **security** skill
- Performance benchmarking and profiling — see load testing tools directly
- Shell script testing patterns — covered in the **tester** agent
