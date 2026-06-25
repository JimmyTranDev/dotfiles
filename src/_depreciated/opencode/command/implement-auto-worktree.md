---
description: Run a feature end-to-end inside a dedicated wcreated git worktree — spec, plan, build, verify, review — fully autonomous, pausing only to clarify genuine ambiguity, then ask once whether to open a draft PR, a ready-for-review PR, or none
---

Drive **$ARGUMENTS** from idea to merged-quality code inside a dedicated
`wcreated` git worktree, in five phases: **spec → plan → build → verify →
review**. This is the autonomous `/implement-auto` flow run inside a fresh
worktree, finishing by asking once how to open the pull request.

Run autonomously end-to-end. The **only** reason to pause mid-flow is a
clarifying question after the spec or after the plan when something is genuinely
ambiguous and a wrong guess would change the work. With nothing to clarify, flow
straight through to a finished, verified, reviewed change — no go/no-go gates.

`$ARGUMENTS` is either a Jira key (e.g. `ABC-123`) or a short feature
description. If empty, ask what to implement before starting.

## Phase 0 — Worktree setup

1. Load the `worktree-management` skill with the skill tool and follow its
   **wcreated** workflow (Workflow A) exactly — raw `git`, never the worktree
   shell script.
2. Create a **new branch worktree** under `~/Programming/wcreated`, branched off
   the freshly-updated base branch (`develop` → `main` → `master`):
   - **Jira key** (`^[A-Z]+-[0-9]+$`): name the branch `<KEY>-<slug(summary)>`,
     pulling the summary via `acli` when available (fall back to `<KEY>`).
   - **Otherwise**: derive the branch/slug from the description.
3. Let the skill choose the commit type, seed the empty commit (so the branch is
   pushable/PR-able immediately), install deps if a lockfile exists, and `cd`
   into the new worktree.
4. Confirm you are inside the worktree (`git rev-parse --is-inside-work-tree`)
   and on the new branch (`git branch --show-current`) before writing any code.
   **Every** subsequent phase runs inside this worktree.

Carry the branch name and the base branch it was cut from into the later phases —
the PR head is this branch and the PR base is that base branch.

## Phase 1 — Spec (autonomous)

1. Load the `spec-driven-development` skill with the skill tool and follow it.
2. **Surface assumptions first** — list what you're inferring about scope, stack,
   and behavior before writing spec content.
3. Produce a **concise** spec: objective, success criteria (specific and
   testable), scope/boundaries (always / ask-first / never), and open questions.
   Keep it proportional to the task. For a Jira key, the **success criteria are
   the ticket's acceptance criteria**.

**Clarify only if needed (after spec).** Scan for genuinely blocking
ambiguities — anything where a wrong assumption would change scope or behavior
and you cannot resolve it from the codebase or context. If any exist, ask them
with the `question` tool (3 concrete proposals each, best first), fold the
answers into the spec, and continue. If the spec is unambiguous, state your key
assumptions and **advance to planning automatically** — no confirmation gate.

## Phase 2 — Plan (autonomous)

1. Load the `planning-and-task-breakdown` skill with the skill tool and follow it.
2. Break the spec into **ordered, dependency-aware tasks**, each sized S–M (no
   task touching more than ~5 files). Every task gets acceptance criteria and a
   verification step (test / build / manual check). Prefer vertical slices.

**Clarify only if needed (after plan).** Same rule: pause only if sequencing,
scope, or approach has a genuine ambiguity whose answer would change the plan.
Ask those with the `question` tool, fold in the answers, then continue.
Otherwise **advance to build automatically** — no confirmation gate.

## Phase 3 — Build (autonomous)

Run without gates — implement every task to completion, all inside the worktree:

1. Load `incremental-implementation` and `test-driven-development` and follow
   them. For framework/library specifics, load `source-driven-development`.
2. For each task: write the test, implement the smallest slice, run the
   project's tests/build/lint, and keep the tree green before moving on. Use a
   todo list to track task-by-task progress.
3. Touch only what the task requires (scope discipline). Note — don't fix —
   unrelated issues you spot.

**The only reasons to stop the build and ask:** a genuinely blocking ambiguity
that wasn't settled in the spec or plan, or an **irreversible / destructive
action** (deleting data, force-push, prod deploy, schema drops, anything moving
money or sending external comms). Otherwise keep going.

## Phase 4 — Verify

With all tasks built, verify the change as a whole (not just the slices you
touched):

1. Run the **full** suite — tests, build, lint, type-check — and confirm every
   spec success criterion is actually met.
2. If anything fails or behaves unexpectedly, load `debugging-and-error-recovery`
   and fix the **root cause** (not the symptom), then re-run.
3. Confirm new/changed logic is **meaningfully covered**. If code was hard to
   test or coverage is thin, load `testability-and-coverage` and close the gaps.
4. For high-stakes, security-sensitive, or irreversible logic, load
   `doubt-driven-development` for an adversarial pass before it stands.

Don't proceed to review until the suite is green.

## Phase 5 — Review

Load `code-review-and-quality` and review the complete change across every axis
(correctness, design, tests, security, readability) as if it were someone
else's PR. Fix anything that wouldn't pass review, then **re-verify** (Phase 4)
after the fixes.

## Phase 6 — Pull request

Once the change is built, verified, and reviewed:

1. **Commit everything.** Load the `commit` skill and commit all work with
   conventional messages (include the Jira key when present). The tree must be
   clean — `git status` shows nothing to commit — before continuing.
2. **Push the branch:** `git push -u origin <branch>`.
3. **Ask how to publish.** Use the `question` tool with exactly these three
   options:
   - **Draft PR (Recommended)** — open a draft so CI runs and you can do a final
     pass in the PR UI before pinging reviewers; mark ready in one click later.
     `gh pr create --draft --base <base> --title "<title>" --body "<body>"`
   - **Open PR (ready for review)** — the work is already verified and reviewed,
     so request review immediately.
     `gh pr create --base <base> --title "<title>" --body "<body>"`
   - **No PR** — stop after pushing; report the branch and the exact
     `gh pr create` command to open one later.
4. **Create the PR** for the chosen option (skip for *No PR*). Set:
   - `--base` to the worktree's base branch (the `develop`/`main`/`master` it was
     cut from); head is the current branch.
   - **Title** from the spec objective (or `<KEY> <summary>` for a Jira ticket).
   - **Body** summarizing what changed and how it was verified (tests/build/lint),
     plus the Jira link `https://storebrand.atlassian.net/browse/<KEY>` when a
     ticket exists.

   Report the PR URL.

## Done

Report: the worktree path + branch + base branch, the spec summary, any
clarifications asked and how they were answered, the task list with each task's
status, the verify results (tests / build / lint / coverage), the review
findings and how they were resolved, anything noted-but-not-touched, and the PR
decision (draft / ready / none) with its URL — or, for *No PR*, the
`gh pr create` command to open one later.
