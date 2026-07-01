---
name: create-jira-ticket
description: Creates a well-formed Jira work item (ticket) end-to-end from the terminal — interactively gathers the project, type, summary, details, Figma designs, and APIs, assembles a structured description with acceptance criteria, confirms the draft, then creates it via the `acli` skill and reports the new key + browse URL. Use when asked to "create a Jira ticket", "create a Jira issue", "file a ticket", "open a work item", "raise a Jira task/story/bug/epic", or to turn an idea into a well-structured ticket. Triggers on "create jira ticket", "new jira ticket", "file a jira issue", "create work item", "raise a ticket". Delegates every raw `acli jira workitem` call to the `acli` skill and never WebFetches `*.atlassian.net`; for reading, searching, editing, transitioning, or commenting on existing tickets — or a single create with all fields already known — use the `acli` skill directly.
---

# Create Jira Ticket

## Overview

Creates a well-formed Jira work item by gathering everything a good ticket needs
— the details, the Figma designs, and the APIs involved — then creating it
through the `acli` skill. This is the repeatable, interactive routine for turning
an idea into a structured ticket with acceptance criteria; the low-level `acli
jira workitem` surface (flags, auth, JSON output) lives in the `acli` skill,
which this skill delegates to for every Jira read and write.

## When to Use

- The user asks to create, file, open, or raise a Jira ticket, issue, or work
  item (`Task`, `Story`, `Bug`, `Epic`).
- Turning a vague request or idea into a well-structured ticket with concrete,
  testable acceptance criteria.
- Seeding a ticket that will be picked up immediately (self-assigned and moved
  to *In Progress*).

**Do NOT use when:**

- You already know every field and just need one raw `acli jira workitem create`
  call — use the `acli` skill directly.
- Reading, searching, editing, assigning, transitioning, or commenting on
  existing tickets — that is the `acli` skill.
- Confluence or admin work — out of scope.

## Prerequisites

Load the `acli` skill with the skill tool first — it owns every `acli jira
workitem` call. Route all Jira reads and writes through it; never WebFetch an
`*.atlassian.net` URL. If any `acli` command returns an auth error, run `acli
auth status` (and `acli auth login` if needed) before retrying, and never print
tokens or auth output.

The seed input (whatever idea or summary the caller passed in) seeds the summary.
If it is empty, ask what the ticket is about before starting.

## Workflow

### Phase 1 — Gather the inputs

Collect the following **in order**. For any decision with discrete options, ask
with the `question` tool (offer 3 concrete proposals, best first); for free-text
fields (summary, details), ask a direct open question and draft a proposal the
user can accept or edit. Never invent a project key or type — confirm them.

1. **Project & type.** Establish the target **project key** and **work item
   type** (`Task`, `Story`, `Bug`, `Epic`). If the project is unknown, list the
   user's recent ones with
   `acli jira workitem search --jql "assignee = currentUser() ORDER BY updated DESC" --fields project --json`
   and offer the top hits.
2. **Summary.** A concise, action-oriented one-liner. Draft one from the seed
   input and let the user refine it.
3. **Details.** The substance of the work — context, the problem, the desired
   outcome, constraints, and anything explicitly out of scope. Ask follow-ups
   until it is concrete.
4. **Figma designs.** Ask for any Figma links. For each one supplied, load the
   `figma` skill with the skill tool and pull that frame's structure and
   variables/tokens, then fold a short design summary plus the link into the
   description. No link → skip.
5. **APIs.** Ask which APIs the work touches — endpoints, methods, request/
   response shapes, auth, and any contract changes. Capture them under an
   "APIs / contracts" heading. None → skip.
6. **Acceptance criteria.** Turn the details into a checklist of specific,
   testable conditions that define "done". Propose a draft for the user to
   adjust.
7. **Optional metadata.** Offer to set labels, an assignee (`@me` or someone
   else), and a parent epic (`--parent <KEY>`). Skip any the user declines.

### Phase 2 — Assemble & confirm the draft

1. Compose the description with clear sections — **Details**, **Figma**,
   **APIs / contracts**, **Acceptance criteria** (omit any empty section). Write
   it to a temporary file (e.g. a heredoc to a `mktemp` path) so the multi-line,
   structured content survives shell quoting, and pass that path via
   `--description-file`.
2. Show the full draft back to the user — project, type, summary, the rendered
   description, and any labels/assignee/parent.

**Confirm gate (before creating).** Creating a ticket is an external side effect,
so never auto-create. Use the `question` tool with exactly these three options:

- **Create the ticket (Recommended)** — the draft is right; create it now.
- **Edit the draft first** — adjust fields, then re-confirm.
- **Cancel** — discard the draft without creating anything.

Do not run the create command until this gate returns "Create".

### Phase 3 — Create & report

1. Create the work item, appending `--label`, `--assignee`, and `--parent` only
   for the metadata the user chose:
   ```bash
   acli jira workitem create --project <KEY> --type <TYPE> --summary "<summary>" \
     --description-file <file> --json
   ```
   Parse the JSON for the new key.
2. Report the created **key** and its **browse URL**
   (`https://<site>.atlassian.net/browse/<KEY>`).
3. Offer to pick it up now — self-assign and move to *In Progress*:
   ```bash
   acli jira workitem assign --key <KEY> --assignee "@me" --yes
   acli jira workitem transition --key <KEY> --status "In Progress" --yes
   ```
   Status names are workflow-specific; if `"In Progress"` is rejected, `view` the
   ticket and use the exact name from its workflow. Skip if the user declines.

## Rules

- Delegate every raw `acli jira workitem` call to the `acli` skill; never
  WebFetch an `*.atlassian.net` URL.
- Never invent a project key or work item type — confirm both with the user.
- Never auto-create: pass the confirm gate before running the create command.
- Write the multi-line description to a temp file and pass `--description-file`
  so structured content survives shell quoting.
- Omit empty sections (Figma / APIs) from the assembled description.
- Never print tokens or auth output.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I know the project/type, I'll skip confirming." | Never invent a project key or type — a wrong one files the ticket in the wrong place. Confirm both. |
| "I'll pass the description inline with `--description`." | Multi-line structured content breaks under shell quoting. Write it to a temp file and use `--description-file`. |
| "The draft looks right, I'll just create it." | Creating a ticket is an external side effect. Pass the confirm gate first. |
| "I'll WebFetch the atlassian.net URL to check the result." | Those URLs return a JS shell with no data. Use the `acli` skill for every read. |
| "I'll reimplement the `acli` flags here." | The CLI surface lives in the `acli` skill. Delegate to it instead of duplicating. |

## Red Flags

- Running `acli jira workitem create` before the confirm gate returns "Create".
- WebFetching an `*.atlassian.net` URL instead of using the `acli` skill.
- Inventing a project key or work item type instead of confirming it.
- Passing a multi-line `--description` inline instead of `--description-file`.
- Printing auth tokens or auth command output.

## Verification

- [ ] The `acli` skill was loaded and every Jira read/write went through it.
- [ ] Project key and work item type were confirmed with the user (not invented).
- [ ] The description was assembled from only non-empty sections and passed via `--description-file`.
- [ ] The confirm gate returned "Create" before the create command ran.
- [ ] The new key and its browse URL were reported.
- [ ] Self-assign + transition to *In Progress* was offered, and run if accepted.
