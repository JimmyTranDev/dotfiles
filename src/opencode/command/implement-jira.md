---
description: Implement a Jira ticket end-to-end — pull the ticket (acli) and any Figma design, then spec, plan, build, verify, and review with quick confirms after the spec and plan
---

Implement Jira work item **$ARGUMENTS** end-to-end. This is the `/implement`
flow (**spec → plan → build → verify → review**, auto-advancing with a quick
confirm after the spec and after the plan) seeded from a Jira ticket and its
linked Figma design.

`$ARGUMENTS` is a Jira key (e.g. `ABC-123`) or a `*.atlassian.net/browse/...`
URL. If empty, ask for the ticket before starting. Extract the key from the
URL's last path segment when given a URL.

## Phase 0 — Intake (Jira + Figma)

1. **Read the ticket.** Load the `acli` skill with the skill tool, then:
   ```bash
   acli jira workitem view <KEY> --fields summary,description,status,assignee,comment --json
   ```
   Summarize the objective and pull out acceptance criteria from the
   description/comments. If auth fails, run `acli auth status` / `acli auth login`.
2. **Pick up the ticket.** Self-assign and move it into progress (reversible,
   expected when starting work):
   ```bash
   acli jira workitem assign --key <KEY> --assignee "@me" --yes
   acli jira workitem transition --key <KEY> --status "In Progress" --yes
   ```
   Status names are workflow-specific — if `"In Progress"` is rejected, `view`
   the ticket, read its current status, and confirm the correct target name.
3. **Pull the design (if any).** If the ticket (or you) reference a Figma link
   (`figma.com/design/...`) or node id, load the `figma` skill with the skill
   tool and pull the design's structure, variables/tokens, and a code draft for
   the relevant frame. If there's no design link, skip this step.

Carry the ticket's acceptance criteria and the design's tokens/components into
the spec as concrete success criteria.

## Phase 1 — Spec · Phase 2 — Plan · Phase 3 — Build · Phase 4 — Verify · Phase 5 — Review

Run the **identical** core flow from the `/implement` command:

1. **Spec** — load `spec-driven-development`; surface assumptions, then write a
   concise spec whose **success criteria are the ticket's acceptance criteria**
   (plus design-fidelity criteria from Figma where relevant).
   **Confirm gate** via the `question` tool: *Proceed to planning (Recommended)*
   / *Revise the spec first* / *Stop here*.
2. **Plan** — load `planning-and-task-breakdown`; ordered S–M tasks, each with
   acceptance criteria + a verification step; vertical slices.
   **Confirm gate** via the `question` tool: *Proceed to build (Recommended)* /
   *Revise the plan first* / *Stop here*.
3. **Build** — load `incremental-implementation` + `test-driven-development`
   (and `source-driven-development` for framework specifics). Implement every
   task to completion: test → slice → run tests/build/lint → keep the tree
   green. Use `figma` (`get_image`) to verify UI fidelity against the design.
   Only stop for a genuinely blocking ambiguity or an irreversible/destructive
   action.
4. **Verify** — run the **full** tests/build/lint/type-check and confirm every
   acceptance criterion is met. On failure load `debugging-and-error-recovery`
   and fix the root cause; ensure new/changed code is meaningfully covered (load
   `testability-and-coverage` if thin); for high-stakes/irreversible logic load
   `doubt-driven-development`. Reconfirm UI fidelity against the Figma design
   with `figma` (`get_image`).
5. **Review** — load `code-review-and-quality` and review the whole change
   across every axis as if it were someone else's PR. Fix anything that wouldn't
   pass review, then re-verify.

## Phase 6 — Report back to Jira

When the work is complete and verified:

1. Comment a summary on the ticket (what changed, branch/PR, how it was
   verified):
   ```bash
   acli jira workitem comment create --key <KEY> --body "<summary of work, branch/PR, verification>"
   ```
2. Propose the next transition (e.g. `"In Review"` or `"Done"`) and run it after
   confirming the exact status name from the project's workflow:
   ```bash
   acli jira workitem transition --key <KEY> --status "In Review" --yes
   ```

## Done

Report: the ticket key + objective, the spec summary, the task list with each
task's status, the verify results (tests/build/lint + coverage + design
fidelity), the review findings and how they were resolved, the Jira comment
posted, and the ticket's resulting status. If ready to land, suggest committing
with the `commit` skill (include the ticket key in the message).
