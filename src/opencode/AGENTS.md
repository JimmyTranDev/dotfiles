# AGENTS.md

Global rules for OpenCode in this workspace. Loaded as a system instruction via
`opencode.jsonc` (`instructions: ["AGENTS.md"]`).

## Asking Questions

Whenever you need a decision, preference, or clarification from the user, ask
with the `question` tool and always offer **3 concrete proposals**:

- List exactly 3 proposed solutions per question.
- Put the **best** option first — the one that yields the highest-quality
  outcome, even if it takes more time or effort — and append "(Recommended)" to
  its label. Never recommend an option just because it is faster or easier.
- Keep `custom` enabled (the default) so the tool's auto-added "Type your own
  answer" appears last — that is the user's self-input escape hatch for when
  none of the 3 proposals fit.
- Do NOT add your own "Other" / catch-all option; the custom self-input covers
  it.
- Give each proposal a short, distinct `description` that explains its trade-off.

Prefer the `question` tool over free-form questions in prose whenever the choice
has discrete options.

## Skill-Driven Execution Model

OpenCode runs a **skill-driven execution model** powered by the built-in `skill`
tool and the `skills/` directory. Skills (from
[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)) live in
`skills/<skill-name>/SKILL.md` and are auto-discovered by name + description.

### Core Rules

- If a task matches a skill, you MUST invoke it with the `skill` tool.
- Never implement directly when a skill applies.
- Follow the skill's instructions exactly — do not partially apply them.
- When unsure which skill fits, load `using-agent-skills` first (the meta-skill
  that governs discovery and invocation).

## Intent → Skill Mapping

Map every request to the appropriate skill before acting.

### Lifecycle (the development loop)

| Phase | Trigger | Skill |
|-------|---------|-------|
| CLARIFY | Underspecified ask, "build me X" with no who/why, ambiguous intent | `interview-me` |
| IDEATE | Vague idea, "refine this idea", "stress-test my plan" | `idea-refine` |
| DEFINE | New feature/project, unclear requirements, no spec exists | `spec-driven-development` |
| PLAN | Break a spec into ordered, estimable tasks | `planning-and-task-breakdown` |
| BUILD | Small, low-risk, well-understood change ("just"/"quick"/"simple"/typo/config tweak) | `fast-implementation` |
| BUILD | Multi-file change, large or risky implementation | `incremental-implementation` |
| BUILD | Any logic, bug fix, or behavior change | `test-driven-development` |
| BUILD | Framework/library correctness, avoid outdated patterns | `source-driven-development` |
| VERIFY | Existing code is hard to test or under-covered; "add tests", "make testable", "full coverage" | `testability-and-coverage` |
| VERIFY | Tests fail, build breaks, unexpected error/behavior | `debugging-and-error-recovery` |
| VERIFY | High-stakes/irreversible decision needs adversarial review | `doubt-driven-development` |
| REVIEW | Before merging any change | `code-review-and-quality` |
| SHIP | Deploy to production, rollout/rollback planning | `shipping-and-launch` |

### Domain-specific

| Intent | Skill |
|--------|-------|
| API, module boundaries, REST/GraphQL, type contracts | `api-and-interface-design` |
| User-facing UI, components, layouts, client state | `frontend-ui-engineering` |
| Browser DOM/console/network/perf debugging (needs chrome-devtools MCP) | `browser-testing-with-devtools` |
| Refactor for clarity without changing behavior | `code-simplification` |
| Performance regressions, Core Web Vitals, load times | `performance-optimization` |
| Untrusted input, auth, sessions, data storage, integrations | `security-and-hardening` |
| Logging, metrics, tracing, alerting | `observability-and-instrumentation` |
| Build/deploy pipelines, quality gates in CI | `ci-cd-and-automation` |
| npm audit + bump deps to latest minor (no majors), re-audit, verify | `npm-audit-and-bump-minor` |
| Commit already-staged changes with a conventional message | `commit` |
| Commits, branching, conflicts, parallel work | `git-workflow-and-versioning` |
| Removing/sunsetting systems, migrating implementations | `deprecation-and-migration` |
| ADRs, decision records, API/feature documentation | `documentation-and-adrs` |
| New session setup, rules files, context configuration | `context-engineering` |
| Read live output of CLIs running in nvim toggleterm terminals | `nvim-toggleterm-read` |
| Browse/pull an Android emulator app's private data folder (/data/data) | `android-app-data` |
| Manage Turso (libSQL) cloud databases, branches, tokens, or local dev server via the `turso` CLI | `turso-database-management` |
| Which skill applies? (meta) | `using-agent-skills` |

## Execution Model

For every request:

1. Determine if any skill applies (even a small chance).
2. Invoke the matching skill with the `skill` tool.
3. Follow the skill workflow strictly.
4. Only proceed to implementation after required steps (clarify, spec, plan,
   tests) are complete.

## Anti-Rationalization

These thoughts are wrong — ignore them:

- "This is too small for a skill."
- "I can just quickly implement this."
- "I'll gather context first, then decide."

Correct behavior: always check for and use the matching skill first.

## Limitations

- Skill invocation depends on model compliance — these rules enforce it.
- `browser-testing-with-devtools` requires its chrome-devtools MCP server.
- `idea-refine` ships a helper at `skills/idea-refine/scripts/idea-refine.sh`.
