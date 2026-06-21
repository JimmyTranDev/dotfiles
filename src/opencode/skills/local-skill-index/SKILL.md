---
name: local-skill-index
description: Creates a using-agent-skills discovery index inside a project's own .opencode/skills/ directory so that project's local skills are routable, modeled on the global using-agent-skills SKILL.md and referencing it instead of duplicating it. Use when authoring or scaffolding skills into any project's local .opencode/skills/ and that project has no local using-agent-skills index yet. Triggers on "create a local using-agent-skills", "add a skill index/router to this project", "this opencode project has no local skill index", "bootstrap local .opencode skills". Do NOT use for this repo's global src/opencode/skills/ library — that is skill-authoring.
---

# Local Skill Index

## Overview

A project can carry its own skills in `.opencode/skills/`. Those skills are
auto-discovered by frontmatter, but a project with no routing index has no
single entry point that lists them and defers to the global library. This skill
creates that entry point: a local `using-agent-skills/SKILL.md` for the project,
modeled on the global meta-skill but covering only the project's local skills.

## When to Use

- You are adding the first skill to a project's `.opencode/skills/` and want a
  routing index for it.
- A project already has local skills but no `using-agent-skills` index to route
  among them.
- You want a project-local entry point that lists local skills and falls back to
  the global library (and stands alone when no global library is installed).

**Do NOT use when:**

- Authoring into this repo's global `src/opencode/skills/` library — use
  `skill-authoring`.
- Editing opencode config (`opencode.json`, agents, plugins, MCP) — use
  `customize-opencode`.
- The project's local index already exists and is current — just refresh its
  table by hand if a single skill changed.

## How It Works

```
In a project's .opencode/skills/ ?
   │ no  → use skill-authoring (global library) instead
   │ yes
   ▼
Local using-agent-skills/SKILL.md exists & current?
   │ yes → refresh the routing table only
   │ no
   ▼
Enumerate local skills → write local using-agent-skills/SKILL.md from template → verify
```

### 1. Confirm the target

You are working in a project whose skills live in
`<project>/.opencode/skills/` — **not** the global `src/opencode/skills/`
library. If it is the global library, stop and use `skill-authoring`.

### 2. Ensure the directory

Confirm `<project>/.opencode/skills/` exists (create it if you are adding the
first local skill).

### 3. Enumerate local skills

For every `<project>/.opencode/skills/<name>/SKILL.md` (excluding any
`_depreciated/`), read the frontmatter `name` and distil a one-line intent from
its `description`. This list becomes the index body.

### 4. Write the index

Create `<project>/.opencode/skills/using-agent-skills/SKILL.md` from the
template below. Scope the description to local routing + global fallback, and
list each local skill with its one-line intent.

### 5. Reference, don't duplicate

Do not copy the global routing tree or the core operating behaviors into the
local file — point to the global `using-agent-skills` for those. The local index
carries only this project's skills plus the fallback note. If the machine has no
global `using-agent-skills`, the local file stands alone as the entry point.

### 6. Maintain on change

Whenever local skills are added, renamed, or removed, refresh the routing table
in the same change so it never drifts.

### 7. Verify & reload

Run the verification checklist, then restart opencode so the new local skill
loads (skills are read at startup, not hot-reloaded).

## Template — generated `.opencode/skills/using-agent-skills/SKILL.md`

```markdown
---
name: using-agent-skills
description: Discovers and routes among THIS project's local skills in .opencode/skills/. Use when starting work in this project or choosing which local skill applies. The global skill library still applies and is the fallback.
---

# Using Agent Skills — <project> (local)

## Overview

Routing index for this project's local skills (`.opencode/skills/`). It covers
only project-local skills and defers to the global `using-agent-skills` for the
core operating behaviors and the full lifecycle/domain routing.

## Local skill routing

| Intent | Skill |
|--------|-------|
| <one-line intent distilled from the skill's description> | `<local-skill-name>` |

## Fallback

If no local skill fits, use the global skill set (see the global
`using-agent-skills`): the lifecycle skills (spec → plan → build → test →
review → ship), the domain skills, and the core operating behaviors (surface
assumptions, manage confusion, push back, enforce simplicity, scope discipline,
verify before done).

When a global skill and a local skill both fit, run the **local** skill for the
project-specific mechanics.
```

## Naming Note

The local file is named `using-agent-skills` on purpose: it is the project's
discovery entry point. Because it shares the global meta-skill's name, keep it
thin and defer to the global behaviors rather than restating them — that way the
two compose where a global library exists, and the local file still works as a
standalone entry point where one does not.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll copy the global routing tree in so it's complete." | Duplicating the global tree bloats the file and drifts out of sync. List only local skills; reference the global meta-skill for the rest. |
| "There's already a global using-agent-skills, so a local one is pointless." | The global index knows nothing about THIS project's local skills. The local index surfaces them; it complements the global one. |
| "I'll skip the per-skill intent line." | Without a when-to-use per skill, routing is a guess. Distil one line from each local skill's description. |
| "This is basically skill-authoring." | skill-authoring targets the global `src/opencode/skills/` library; this targets a project's local `.opencode/skills/`. Different surfaces. |
| "I added a local skill but the index can wait." | A stale index misroutes or hides the new skill. Refresh the table in the same change. |

## Red Flags

- The generated file restates the global routing tree or core-behaviors prose
  instead of referencing it.
- The routing table lists skills that don't exist under `.opencode/skills/`, or
  omits ones that do.
- Used to author into the global `src/opencode/skills/` (that's skill-authoring).
- `_depreciated/` skills listed in the table.
- A README or extra docs created next to the index (repo rule: no unsolicited
  docs).
- An empty `scripts/` directory added to the index skill.

## Verification

- [ ] `<project>/.opencode/skills/using-agent-skills/SKILL.md` exists.
- [ ] Frontmatter `name` is `using-agent-skills`; `description` scopes it to
      local routing + global fallback, ≤1024 chars, no step-by-step process.
- [ ] Every local skill under `.opencode/skills/` (excluding `_depreciated/`)
      appears once in the routing table with a one-line intent; no phantom rows.
- [ ] The file references the global meta-skill rather than duplicating its
      routing tree / core behaviors.
- [ ] No empty `scripts/` directory and no unsolicited README.
- [ ] User reminded to restart opencode so the local skill loads.
