---
description: Turn a Figma design into multiple Jira tasks — read the design via the figma skill, decompose it into one task per screen/component/flow, confirm the batch, then create each ticket via create-jira-ticket/acli under a shared project and optional parent epic, and report every key + URL
---

Load the `create-jira-tasks-from-figma` skill with the skill tool and follow its
workflow exactly to turn a Figma design into a set of Jira tasks from
**$ARGUMENTS**. `$ARGUMENTS` seeds the Figma link (or the idea/scope); if it is
empty, ask for the Figma URL before starting.

The skill reads the design through the `figma` skill, decomposes it into discrete
implementable tasks (one per screen, component, or flow) with per-task acceptance
criteria, establishes a shared project key, work item type, and optional parent
epic, **confirms the full batch before creating anything** (creating tickets is
an external side effect), then creates each task through the `create-jira-ticket`/
`acli` skills and reports every new key + browse URL.

Route every Jira read and write through the `acli` skill and read the design
through the `figma` skill; never WebFetch an `*.atlassian.net` URL. For a single
ticket use `/create-jira-ticket` instead; for design-to-code without ticketing
use the `figma` skill.
