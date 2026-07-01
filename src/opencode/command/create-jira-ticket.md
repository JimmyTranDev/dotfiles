---
description: Create a well-formed Jira work item — interactively gather the details, Figma designs, and APIs involved, assemble a structured description with acceptance criteria, confirm the draft, then create it via acli and report the key + URL
---

Load the `create-jira-ticket` skill with the skill tool and follow its workflow
exactly to create a Jira work item from **$ARGUMENTS**. `$ARGUMENTS` seeds the
summary/idea; if it's empty, ask what the ticket is about before starting.

The skill gathers the project, type, summary, details, Figma designs, APIs, and
acceptance criteria; assembles a structured description; **confirms the draft
before creating** (creating a ticket is an external side effect); then creates it
through the `acli` skill and reports the new key + browse URL. It also offers to
pick the ticket up — self-assign and move it to *In Progress*.

Route every Jira read and write through the `acli` skill (the `create-jira-ticket`
skill loads it); never WebFetch an `*.atlassian.net` URL.
