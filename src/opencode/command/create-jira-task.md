---
description: Create a well-formed Jira work item — interactively gather the details, Figma designs, and APIs involved, assemble a structured description with acceptance criteria, confirm the draft, then create it via acli and report the key + URL
---

Create a Jira work item from **$ARGUMENTS** by gathering everything a good ticket
needs — the details, the Figma designs, and the APIs involved — then creating it
through the `acli` skill. `$ARGUMENTS` seeds the summary/idea; if it's empty, ask
what the task is before starting.

Load the `acli` skill with the skill tool first — it owns every `acli jira
workitem` call. Route all Jira reads and writes through it; never WebFetch an
`*.atlassian.net` URL.

## Phase 1 — Gather the inputs

Collect the following **in order**. For any decision with discrete options, ask
with the `question` tool (offer 3 concrete proposals, best first); for free-text
fields (summary, details), ask a direct open question and draft a proposal the
user can accept or edit. Never invent a project key or type — confirm them.

1. **Project & type.** Establish the target **project key** and **work item
   type** (`Task`, `Story`, `Bug`, `Epic`). If the project is unknown, list the
   user's recent ones with
   `acli jira workitem search --jql "assignee = currentUser() ORDER BY updated DESC" --fields project --json`
   and offer the top hits.
2. **Summary.** A concise, action-oriented one-liner. Draft one from
   `$ARGUMENTS` and let the user refine it.
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

## Phase 2 — Assemble & confirm the draft

1. Compose the description with clear sections — **Details**, **Figma**,
   **APIs / contracts**, **Acceptance criteria** (omit any empty section). Write
   it to a temporary file (e.g. a heredoc to a `mktemp` path) so the multi-line,
   structured content survives shell quoting, and pass that path via
   `--description-file`.
2. Show the full draft back to the user — project, type, summary, the rendered
   description, and any labels/assignee/parent.

**Confirm gate (before creating).** Creating a ticket is an external side
effect, so never auto-create. Use the `question` tool with exactly these three
options:

- **Create the ticket (Recommended)** — the draft is right; create it now.
- **Edit the draft first** — adjust fields, then re-confirm.
- **Cancel** — discard the draft without creating anything.

Do not run the create command until this gate returns "Create".

## Phase 3 — Create & report

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

If `acli` returns an auth error at any point, run `acli auth status` (and
`acli auth login` if needed) before retrying. Never print tokens or auth output.
