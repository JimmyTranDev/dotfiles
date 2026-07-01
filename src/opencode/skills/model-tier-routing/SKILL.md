---
name: model-tier-routing
description: Routes the agent's own work across the Claude model tiers — Haiku, Sonnet, and Opus — to spend the fewest tokens and dollars for the quality a task actually needs. Use when deciding which model tier should run a task, a session, or a delegated subagent; when high-volume or mechanical work (searches, bulk file reads, boilerplate, renames, log scans) is burning expensive top-tier tokens; when configuring a cheaper subagent via `opencode agent create --model`/`--mode subagent`; or when choosing a per-run/per-session `--model`. Triggers on "token usage", "reduce cost", "cheaper model", "which model", "model tier", "haiku", "sonnet", "opus", "downgrade/upgrade the model", "too expensive". Use ONLY for choosing WHICH tier runs the work — for WHEN to delegate use parallelization-and-delegation, for WHAT context to load use context-engineering, and for the opencode config/CLI mechanics use customize-opencode / opencode-cli.
---

# Model Tier Routing

## Overview

Every task the agent runs — and every subagent it spawns — costs tokens, and not
every task needs the smartest, most expensive model. The Claude family comes in
three tiers: **Haiku** (fastest, cheapest), **Sonnet** (balanced), and **Opus**
(most capable, most expensive). Routing each task to the *cheapest tier that can
do it well* is the single biggest lever on token spend that does not sacrifice
outcome quality. This skill is the decision discipline for picking that tier and
for escalating or de-escalating deliberately.

This repo currently runs **one** model for everything —
`anthropic/claude-opus-4-8` (`opencode.jsonc`), the top tier — so mechanical and
high-volume work pays Opus prices for no quality gain. This skill is the guidance
for changing that per task and per subagent.

The skill owns **which tier** runs the work. It stacks with two sibling levers:
`parallelization-and-delegation` decides **when** to hand work to a subagent, and
`context-engineering` decides **what** to load into the context. Use all three
together — they cut tokens along different axes.

## When to Use

- You're deciding which model should run a task, a session, or a delegated
  subagent.
- High-volume or mechanical work — codebase searches, bulk file reads,
  boilerplate, mechanical renames, log/output scanning, formatting — is running
  on the top tier and burning tokens for no quality benefit.
- You're spawning a `Task` subagent and could give it a cheaper model.
- You're configuring an opencode agent/subagent and choosing its model.
- A run feels too expensive or too slow and you want to right-size the model.

**Do NOT use when:**

- You need to decide *whether* to delegate or batch calls at all — that's
  `parallelization-and-delegation`.
- The problem is too much or wrong context, not the model — that's
  `context-engineering`.
- You need the mechanics of editing opencode config or agent definitions — that's
  `customize-opencode`; for driving the `opencode` binary it's `opencode-cli`.
- Correctness is safety-critical and the cost of a wrong cheap-tier answer
  outweighs the token savings — stay on the higher tier.

## The Three Tiers

| Tier | Relative cost & latency | Route here when the task is... |
|---|---|---|
| **Haiku** | Cheapest, fastest | Mechanical and well-specified: search/extraction, bulk reads, simple edits, renames, formatting, log scanning, classification, short summaries. Little reasoning, easy to verify. |
| **Sonnet** | Mid cost, mid latency | Standard engineering: most feature code, straightforward bug fixes, test writing, refactors with a clear target, routine reviews. The sensible default for real work. |
| **Opus** | Most expensive, slowest | Deep reasoning: ambiguous architecture, multi-system tradeoffs, subtle debugging, security-sensitive logic, or when a cheaper tier already failed. Reserve it — don't default to it. |

Exact model IDs drift; resolve current ones with `opencode models anthropic`
(`opencode models --verbose` shows costs — see `opencode-cli`). Match the *tier*,
not a hard-coded string.

## Routing Decision Flow

```
Task to run (or subagent to spawn)
   │
   ├─ Mechanical / well-specified, easy to verify? ───→ Haiku
   │     (search, bulk read, rename, format, extract, classify)
   │
   ├─ Standard engineering with a clear target? ──────→ Sonnet  (default)
   │     (feature code, clear bug fix, tests, scoped refactor, routine review)
   │
   ├─ Deep reasoning / ambiguity / high stakes? ──────→ Opus
   │     (architecture, cross-system tradeoffs, subtle bug, security logic)
   │
   └─ Unsure which? ──────────────────────────────────→ Start one tier DOWN,
                                                          verify, escalate on failure
```

**Default to Sonnet, not Opus.** Reserve Opus for tasks that genuinely need it,
and push mechanical work down to Haiku. When in doubt, start cheaper and escalate:
escalation costs one retry; over-provisioning costs *every* run.

**Escalate up a tier when:** the cheaper tier's output is wrong, incomplete, or
low-confidence; the task turns out more ambiguous than it looked; or verification
(tests/build/review) fails on the cheaper output.

**De-escalate down a tier when:** the work is repetitive and easy to check; you're
fanning out many independent subagents (multiply the per-run cost by N); or the
output is going to be verified anyway (tests, a reviewer, or a higher-tier pass).

**Always verify cheap-tier output** the same way you'd verify your own — tests,
build, a quick read. Cheap + verified beats expensive + assumed.

## Applying It in opencode

Three places to set the tier — see `opencode-cli` for the binary mechanics and
`customize-opencode` for the config/content design:

- **Per subagent (biggest win).** Delegate mechanical, high-volume work to a
  `Task` subagent running a cheaper tier so the expensive main context never pays
  for it. Set a subagent's model in opencode config, or scaffold one with
  `opencode agent create --mode subagent --model anthropic/<haiku-or-sonnet>`.
  See `parallelization-and-delegation` for *when* to delegate; this skill picks
  the subagent's *tier*.
- **Per run / session.** Start a cheaper run with the `--model`/`-m` flag
  (`opencode run -m anthropic/<model>` or the TUI `--model`), or switch models
  mid-session for a stretch of cheap work.
- **The default model.** The workspace default lives in `opencode.jsonc`
  (`"model"`). Changing it is a `customize-opencode` task, not something this
  skill does — but a top-tier default means *every* unrouted task pays top price,
  which is the gap this skill closes.

Pair with `context-engineering`: a cheaper tier with tight, focused context often
beats a top tier drowning in noise.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Opus is the best model, so use it for everything." | Best-per-hard-task ≠ best-everywhere. Paying Opus rates to grep files or rename a symbol buys zero extra quality — only cost and latency. |
| "Switching tiers is more hassle than it's worth." | It's one `--model` flag or one subagent model field. The saving compounds across every mechanical call and every fanned-out subagent. |
| "A cheaper model might get it wrong." | So verify it — tests, build, a read. Cheap + verified is the goal; if verification fails you escalate one tier, having spent little. |
| "I'll just default to the top tier to be safe." | 'Safe' top-tier defaults are how token budgets quietly bleed. Default to Sonnet, reserve Opus, push mechanical work to Haiku. |
| "Token optimization means trimming context." | That's `context-engineering` — a different lever. Model tier is orthogonal: both cut tokens and they stack. |
| "The subagent should match my model." | Subagents inherit the top tier by default — that's the leak. A search or bulk-read subagent belongs on Haiku/Sonnet regardless of your tier. |

## Red Flags

- Every subagent runs the top tier, including pure search/read/extract units.
- Mechanical, high-volume work (renames, formatting, log scans) runs on Opus.
- Opus is the reflexive default instead of a deliberate choice for hard tasks.
- Choosing a tier by hard-coded model string instead of by task complexity.
- Fanning out many subagents on the top tier without multiplying out the cost.
- Accepting a cheap-tier result without verifying it — or refusing the cheap tier
  because you *won't* verify.
- Reaching for this skill to trim context or decide whether to delegate — wrong
  lever (that's `context-engineering` / `parallelization-and-delegation`).

## Verification

- [ ] The task was matched to the cheapest tier that can do it well (mechanical →
  Haiku, standard → Sonnet, deep reasoning / high stakes → Opus), not defaulted to
  the top tier.
- [ ] Delegated subagents doing mechanical or high-volume work were given a
  cheaper tier, not left on the inherited top tier.
- [ ] Any cheap-tier output was verified (tests / build / read) before being
  trusted; failures were escalated one tier rather than the tier being abandoned.
- [ ] The tier was chosen by task complexity, and the concrete model resolved via
  `opencode models anthropic` rather than a stale hard-coded ID.
- [ ] Context and delegation levers were considered alongside tier
  (`context-engineering`, `parallelization-and-delegation`), not conflated with it.
