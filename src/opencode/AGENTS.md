# AGENTS.md

Global rules for OpenCode in this workspace. Loaded as a system instruction via
`opencode.jsonc` (`instructions: ["AGENTS.md"]`).

## Asking Questions

**Always ask with the `question` tool — never end a turn with a free-form
question the user has to answer.** Whenever you need a decision, preference,
clarification, or a go/no-go confirmation before proceeding, surface it as an
interactive multiple-select `question` (the user picks an option) rather than
writing it in prose and stopping. If you catch yourself about to end a turn
with a trailing question, convert it into a `question` call instead.

Every `question` offers **3 concrete proposals**:

- List exactly 3 proposed solutions per question.
- Put the **best** option first — the one that yields the highest-quality
  outcome, even if it takes more time or effort — and append "(Recommended)" to
  its label. Never recommend an option just because it is faster or easier.
- Keep `custom` enabled (the default) so the tool's auto-added "Type your own
  answer" appears last — the user's self-input escape hatch. This is why you
  never need a free-form prose question: open-ended answers come through
  `custom`, not through ending your turn.
- Do NOT add your own "Other" / catch-all option; the custom self-input covers
  it.
- Give each proposal a short, distinct `description` that explains its trade-off.
- Use `multiple: true` only when more than one option can genuinely apply at
  once; most questions stay single-select.

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
| YOLO | Explicit opt-in: "yolo", "full send", "do everything, I'll test later", "no gates" — one autonomous no-gate pass (still clarifies the target) | `yolo` |

### Domain-specific

| Intent | Skill |
|--------|-------|
| API, module boundaries, REST/GraphQL, type contracts | `api-and-interface-design` |
| User-facing UI, components, layouts, client state | `frontend-ui-engineering` |
| Browser DOM/console/network/perf debugging (needs chrome-devtools MCP) | `browser-testing-with-devtools` |
| Refactor for clarity without changing behavior | `code-simplification` |
| Write/review good code comments (why-not-what); TODO:/FIX:/HACK:/NOTE: markers | `good-code-comments` |
| Performance regressions, Core Web Vitals, load times | `performance-optimization` |
| Untrusted input, auth, sessions, data storage, integrations | `security-and-hardening` |
| Logging, metrics, tracing, alerting | `observability-and-instrumentation` |
| Build/deploy pipelines, quality gates in CI | `ci-cd-and-automation` |
| npm audit + bump deps to latest minor (no majors), re-audit, verify | `npm-audit-and-bump-minor` |
| Find/remove unused files, dependencies, exports & dead code in JS/TS via Knip | `knip` |
| Commit already-staged changes with a conventional message | `commit` |
| Commits, branching, conflicts, parallel work | `git-workflow-and-versioning` |
| Write a GitHub PR title + body (the `gh pr create` content) | `github-pr-description` |
| Git worktrees in ~/Programming/wcreated & wcheckout (create/checkout/delete/update/clean) | `worktree-management` |
| Resolve in-progress git merge/rebase/cherry-pick conflicts (unmerged paths, conflict markers) | `merge-conflict-resolution` |
| Handle review comments on your own GitHub PR — address in code, reply, resolve threads | `handle-github-pr-comments` |
| Handle your PR's review comments in an isolated wcheckout worktree — pull head branch, fix/reply, push, cleanup | `handle-pr-comments-worktree` |
| Removing/sunsetting systems, migrating implementations | `deprecation-and-migration` |
| ADRs, decision records, API/feature documentation | `documentation-and-adrs` |
| New session setup, rules files, context configuration | `context-engineering` |
| Read live output of CLIs running in nvim toggleterm terminals | `nvim-toggleterm-read` |
| Browse/pull an Android emulator app's private data folder (/data/data) | `android-app-data` |
| Embedded Turso Database engine — `tursodb` shell, `@tursodatabase/*` SDKs, MVCC/concurrent writes, encryption, local-first sync | `turso-database` |
| Manage the Turso Cloud platform (libSQL) — databases, groups, branches, tokens, local dev server via the `turso` CLI | `turso-cloud` |
| Operate the `opencode` CLI binary — `run`, `serve`/`web`/`attach`, auth, agents, MCP, models, sessions, stats, plugins, `upgrade`/`uninstall` | `opencode-cli` |
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
