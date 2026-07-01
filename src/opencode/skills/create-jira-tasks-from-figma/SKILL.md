---
name: create-jira-tasks-from-figma
description: Creates multiple Jira work items (tasks) from a single Figma design — reads the design through the `figma` skill, decomposes it into discrete implementable tasks (one per screen, component, or flow), confirms the whole batch, then creates each ticket via the `create-jira-ticket`/`acli` skills under a shared project and optional parent epic, and reports every new key + browse URL. Use when turning a Figma file/frame/mockup into a set of Jira tickets, breaking a design into tickets, or filing one task per screen/component/flow. Triggers on "create jira tasks from figma", "figma to jira", "tickets from a design", "break this design into tasks", "one ticket per screen", or a figma.com/design or figma.com/file link paired with ticket creation. Delegates Figma reading to the `figma` skill and every Jira read/write to `acli` (never WebFetch `*.atlassian.net`); for a single ticket use `create-jira-ticket`, and for design-to-code without ticketing use `figma`.
---

# Create Jira Tasks from Figma

## Overview

Turns one Figma design into a set of well-formed Jira tasks. Where
`create-jira-ticket` files a single work item and `figma` turns a design into
code, this skill sits between them: it reads the design faithfully through the
`figma` skill, breaks it into discrete implementable units, and files one ticket
per unit through the `create-jira-ticket`/`acli` skills. It owns only the
**decomposition** and the **batch-create loop** — every Figma read and every
Jira write is delegated to the skill that owns it.

## When to Use

- Turning a Figma file, frame, or flow into multiple Jira tickets — one per
  screen, component, or user flow.
- Breaking a design hand-off into a backlog of tasks grouped under one epic.
- Seeding a batch of tickets from a mockup that the team will pick up.

**Do NOT use when:**

- You want a single ticket — use `create-jira-ticket`.
- You want to generate code from the design, not tickets — use `figma`.
- Reading, editing, assigning, or transitioning existing tickets — use `acli`.
- No Figma is involved — use `create-jira-ticket` for a plain ticket.

## Prerequisites

Load these skills with the skill tool first and delegate to them — do not
reimplement their surfaces:

- **`figma`** — reads the design via the Dev Mode MCP; owns node-id/selection
  targeting and the MCP-unavailable fallback.
- **`acli`** — owns every `acli jira workitem` call and auth; **`create-jira-ticket`**
  builds each well-formed ticket on top of it.

The seed input (a Figma URL or an idea) seeds the target and scope. If it is
empty, ask for the Figma link before starting. Never WebFetch an
`*.atlassian.net` URL; never print auth tokens.

## Workflow

### Phase 1 — Read the design

1. Load the `figma` skill and locate the target node — the `node-id` from the
   URL (dash form `1234-5678` → API form `1234:5678`) or the current desktop
   selection.
2. Pull **structure first** — metadata/image plus `get_variable_defs` — to see
   the frames, screens, and components present. Check `get_code_connect_map` to
   spot pieces that already map to existing components.
3. If the Figma MCP is unavailable, say so and fall back to a provided
   screenshot/description — **do not fabricate** frames or states.

### Phase 2 — Decompose into tasks

1. Break the design into discrete, independently-shippable units — typically one
   per screen, major component, or user flow. Prefer vertical slices a single
   engineer can own end to end.
2. For each unit draft: a concise, action-oriented **summary**; a short
   **details** paragraph (what to build, which Figma frame/node it maps to,
   notable tokens/states); and testable **acceptance criteria**.
3. Right-size: merge trivial fragments, split anything too large to verify in one
   ticket. Flag any design value with no token instead of hard-coding it (per the
   `figma` skill).
4. Capture cross-cutting work (shared components, design tokens, navigation) as
   its own task so screen tasks can depend on it.

### Phase 3 — Establish shared context

Ask **once** and reuse across every task. For discrete choices use the question
tool (3 concrete proposals, best first); never invent values.

1. **Project key + work item type** (default `Task`). Confirm both — never invent
   them. If the project is unknown, list recent ones with
   `acli jira workitem search --jql "assignee = currentUser() ORDER BY updated DESC" --fields project --json`.
2. **Parent epic** — offer to link (or create) one so the batch groups under it
   (`--parent <KEY>`); skip if declined.
3. **Shared metadata** — labels/component and assignee applied to every task.

### Phase 4 — Confirm the batch (gate)

Creating tickets is an external side effect, so **never auto-create**. Show the
full plan — project, type, parent epic, and every task's summary + acceptance
criteria — then use the question tool with exactly these options:

- **Create all tasks (Recommended)** — the list is right; file them now.
- **Edit the list first** — add / remove / merge / split tasks or fix a field,
  then re-confirm.
- **Cancel** — discard without creating anything.

Do not create anything until this gate returns **Create**.

### Phase 5 — Create the tasks

1. Create each task through the `create-jira-ticket`/`acli` surface, sharing the
   project, type, parent, and labels. Assemble each multi-line description in a
   temp file and pass `--description-file` (structured content breaks under inline
   shell quoting):
   ```bash
   acli jira workitem create --project <KEY> --type <TYPE> --summary "<summary>" \
     --description-file <file> --parent <EPIC> --json
   ```
   Parse the JSON for each new key.
2. Keep a running list of results. If one create fails, **report it and continue**
   with the rest — a partial batch beats losing the successful tickets.

### Phase 6 — Report

1. Report every created **key** with its **browse URL**
   (`https://<site>.atlassian.net/browse/<KEY>`), grouped under the parent epic
   when one was used, plus any task that failed to create.
2. Offer to pick up the batch — self-assign and move to *In Progress* — or leave
   it in the backlog; skip if declined.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll eyeball the screenshot instead of reading the design." | The `figma` skill pulls real structure and tokens; guessing produces vague, wrong tasks. Read it through the skill. |
| "One big ticket for the whole design is simpler." | Decomposition into shippable units is the entire point. File one task per screen/component/flow. |
| "The list looks right, I'll just create the tickets." | Creating tickets is an external side effect. Pass the confirm gate first. |
| "I'll reimplement the acli flags / ticket assembly here." | That surface lives in `acli`/`create-jira-ticket`. Delegate; don't duplicate. |
| "I'll pass each description inline." | Multi-line structured content breaks under shell quoting. Write it to a temp file and use `--description-file`. |
| "One create failed, I'll abort the batch." | Report the failure and continue; a partial batch beats losing the successful ones. |

## Red Flags

- Creating any ticket before the confirm gate returns **Create**.
- Filing a single catch-all ticket instead of decomposing the design.
- WebFetching an `*.atlassian.net` URL instead of using the `acli` skill.
- Inventing a project key, work item type, or parent epic instead of confirming it.
- Fabricating frames or states when the Figma MCP is unavailable.
- Duplicating `acli` flags or `figma` MCP handling instead of delegating.

## Verification

- [ ] The `figma` skill was loaded and the design was read (structure + tokens), not guessed.
- [ ] The design was decomposed into discrete tasks, each with a summary + acceptance criteria and mapped to a Figma frame/node.
- [ ] Project key, work item type, and any parent epic were confirmed (not invented).
- [ ] The confirm gate returned **Create** before any ticket was created.
- [ ] Every task was created via `acli`/`create-jira-ticket` with `--description-file` and the shared project/parent.
- [ ] All new keys + browse URLs were reported (including any failures); pick-up (assign + *In Progress*) was offered.
