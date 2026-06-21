---
name: testability-and-coverage
description: Makes hard-to-test code testable, then drives it to full, meaningful test coverage. Use when existing code has low or no coverage, is hard to test (hidden dependencies, global or static state, baked-in time/randomness/I/O, tight coupling), or when the user asks to "add tests", "make this testable", "get full/100% coverage", or "pin existing behavior before refactoring". Use ONLY for retrofitting tests onto existing code — for greenfield, test-first development use test-driven-development instead.
---

# Testability and Coverage

## Overview

Retrofit testability onto code that is hard to test, then drive it to full, meaningful coverage. This is a two-front job: first introduce **seams** so units can run in isolation *without changing behavior*, then systematically close every coverage gap with assertions that test behavior, not implementation.

This skill covers *existing* code. For writing new behavior test-first (RED → GREEN → REFACTOR), use `test-driven-development`. For *how* to write good individual tests (AAA, DAMP, state-not-interactions, real-over-mocks), defer to `test-driven-development` — this skill does not duplicate it.

## When to Use

- Existing code with low, no, or untrustworthy test coverage
- Code that resists testing: `new` dependencies created inside, global/singleton/static state, `Date.now()`/`Math.random()`/UUID/env read inline, network/DB/filesystem I/O baked in, tight coupling, long multi-responsibility functions
- The user asks to "add tests", "make this testable", "get to full/100% coverage", "increase coverage"
- You must pin current behavior before a risky refactor or migration

**Do NOT use when:**

- Writing brand-new behavior test-first → `test-driven-development`
- Reproducing and fixing a specific bug → `debugging-and-error-recovery` (then a regression test)
- Pure clarity refactor with tests already in place → `code-simplification`
- The goal is a vanity coverage number with no behavioral value (see "What full coverage means")

## The Legacy Code Dilemma

> To change code safely you need tests. To get the code under test you often must change it. Changing untested code risks breaking it.

Break the cycle with the **smallest possible behavior-preserving change** that creates a seam, protected by a characterization test written *first*.

## The Workflow

```
Phase 0   Phase 1        Phase 2          Phase 3            Phase 4
PIN   →   FIND       →   SEAM         →   COVER          →   VERIFY
chars.    testability    behavior-        close branch       all green,
tests     blockers       preserving       & edge gaps        coverage met,
          (smell scan)   refactor         with assertions    behavior intact
   │__________________________________________________________│
                    run characterization tests after every refactor
```

### Phase 0: Pin current behavior (characterization tests)

Before changing structure, capture what the code *currently does* — even if it looks wrong. These tests document reality and become your safety net. Do not "fix" behavior here.

```typescript
// Characterization test: assert the ACTUAL output, discovered by running it.
// Goal is a net under the code, not a judgment of correctness.
it('characterizes formatInvoice for a standard order (current behavior)', () => {
  expect(formatInvoice(sampleOrder)).toBe('INV-001 | $42.00 | NET-30');
});
```

If you cannot even instantiate the unit to characterize it, jump to Phase 1/2, introduce the *minimal* seam needed to call it, then return and pin.

### Phase 1: Find the testability blockers

Scan the target for these smells and name the seam each one needs:

| Smell (why it's untestable) | Seam to introduce |
|---|---|
| Dependency constructed inside (`new Mailer()`) | Inject via constructor/parameter |
| Global / singleton / static mutable state | Wrap and inject; parameterize access |
| `Date.now()`, `Math.random()`, UUID, `process.env` read inline | Inject a clock / id / config provider |
| Network, DB, filesystem, clock I/O | Depend on an interface; substitute a fake |
| Hidden side effects mixed with logic | Split pure core from imperative shell |
| Long function doing many things | Extract pure functions for each decision |
| Static method / free function with hidden deps | Extract-and-override or wrap |

### Phase 2: Introduce seams (behavior-preserving refactor)

Apply the smallest refactor that creates the seam. **Run the Phase 0 characterization tests after every change** — they must stay green. If you have none yet for that path, write one first.

Prefer, in order: **parameter/constructor injection** → **extract pure function** → **extract-and-override** → **wrap**.

```typescript
// BEFORE — untestable: hidden dependency + nondeterministic time
class OrderService {
  place(order: Order) {
    const id = new IdGenerator().next();          // hidden dep
    const at = new Date();                          // nondeterministic
    new Database().save({ ...order, id, at });      // hidden I/O
  }
}

// AFTER — seams via injection; behavior identical, now substitutable
class OrderService {
  constructor(
    private db: SaveTarget,
    private ids: IdSource,
    private clock: () => Date,
  ) {}
  place(order: Order) {
    this.db.save({ ...order, id: this.ids.next(), at: this.clock() });
  }
}
```

Wire real implementations at the composition root; pass fakes in tests. Keep public behavior byte-for-byte identical — this is a refactor, not a feature change.

### Phase 3: Drive to full, meaningful coverage

1. **Measure** line *and* branch coverage. Branch coverage matters more than line coverage.
2. **List the gaps**: every uncovered branch, error/exception path, early return, default, and boundary.
3. **Add one focused test per behavior**, asserting outcomes (defer test-writing style to `test-driven-development`). Cover:
   - Equivalence partitions + boundary values (0, 1, max, empty, null)
   - Every conditional branch and switch/default arm
   - Error and exception paths (not just the happy path)
   - The substituted seams (fakes returning errors, throwing, timing out)
4. **Re-measure**; treat each remaining uncovered line as a question — "what behavior is untested here?" — not a number to game. Delete genuinely dead code (with approval) rather than testing it.

### Phase 4: Verify

Run the full suite and the coverage report; confirm the checklist below.

## Testability Design Principles (keep new code testable)

- **Dependency inversion** — depend on abstractions you can substitute, not concretions.
- **Functional core, imperative shell** — push pure logic to the center; keep I/O at the edges.
- **Make effects explicit** — pass clocks, id generators, randomness, and config in; never reach for globals.
- **Determinism** — same inputs, same outputs; no hidden time/random/network.

## What "Full Coverage" Means

Coverage is a tool, not a goal. 100% line coverage with weak or no assertions proves nothing; an untested branch is a silent risk. Target **every branch and every observable behavior exercised by a meaningful assertion**. Prefer branch/path coverage over a line-count percentage, and never add assertion-free tests just to move the number.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll refactor for testability first, then add tests." | Refactoring untested code is how you introduce silent regressions. Pin behavior with a characterization test *before* you touch structure. |
| "100% line coverage means it's fully tested." | Line coverage with weak assertions proves nothing. Branch coverage with real assertions is the bar. |
| "It's too coupled to test — I'll just test it manually." | Coupling is the thing to fix. Introduce a seam; that's the whole point of this skill. |
| "Mock everything so the unit is isolated." | Over-mocking yields tests that pass while production breaks. Prefer real implementations and fakes; mock only true boundaries. |
| "I'll change behavior while I'm in here making it testable." | Testability seams must be behavior-preserving. Mixing in behavior changes destroys your safety net. Separate the commits. |
| "Coverage is at the target, so I'm done." | A number reached with assertion-free or happy-path-only tests is false confidence. Verify branches and error paths. |
| "This code has no tests but I understand it, so I'll just write the fix." | Understanding isn't a regression guard. Characterize first. |

## Red Flags

- Refactoring for testability with no characterization test protecting the change
- Coverage percentage climbing while assertion count barely moves
- Tests that only exercise the happy path; every error branch uncovered
- Mocks for everything, including pure logic and simple data
- "Testable" version that quietly changes outputs, ordering, or error behavior
- Chasing 100% by testing third-party/framework code or dead code instead of deleting it
- Seam introduced but real wiring at the composition root left broken/untested

## Verification

- [ ] Characterization tests captured current behavior *before* any refactor and stayed green throughout
- [ ] Every testability blocker found in Phase 1 has a seam, or a documented reason it was left
- [ ] Refactors are behavior-preserving — public outputs, side effects, ordering, and error behavior unchanged
- [ ] Branch coverage measured (not just line); every branch, error path, and boundary has a test
- [ ] Each test asserts a meaningful outcome — no assertion-free coverage padding
- [ ] Full suite passes and is fast/isolated: `npm test` (or the project's runner)
- [ ] Coverage target met *and* justified behaviorally, not just numerically
