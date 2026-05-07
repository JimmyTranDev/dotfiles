---
name: learn-nvim
description: Extract learnings from the current chat and update Neovim config (AGENTS.md, plugin settings, keymaps)
---

Usage: /learn-nvim [specific topic or "all"]

$ARGUMENTS

Analyze the current conversation for reusable learnings about Neovim and update the relevant configuration files in `~/Programming/JimmyTranDev/nvim`.

## Workflow

1. Load the **meta-skill-learnings** and **meta-agents-md** skills in parallel

2. Scan the conversation for:
   - Plugin configuration gotchas or pitfalls
   - Keymap fixes or improvements
   - LSP configuration patterns
   - Snacks/picker/UI behavior discoveries
   - Lua API patterns worth remembering
   - Plugin interaction issues and workarounds
   - Performance fixes or optimizations
   - Decisions that should become permanent rules

3. For each learning, determine where it belongs:
   - **AGENTS.md update** — universal rules for working in the nvim repo (e.g., "use `args` instead of `base` for git_diff to include uncommitted changes")
   - **Plugin config note** — inline knowledge near the relevant plugin setup in `lua/plugins/`
   - **Custom module note** — patterns for `lua/custom/` or `lua/core/` modules
   - **Dotfiles AGENTS.md** — if the learning applies across all repos, not just nvim (escalate to dotfiles repo)

4. Present the learnings to the user:
   - Show each learning with its proposed destination file and location
   - Let the user approve, modify, or reject each one

5. Apply approved learnings:
   - For AGENTS.md: create or update `~/Programming/JimmyTranDev/nvim/AGENTS.md`
   - For plugin/module notes: update the relevant lua file
   - Follow the conventions from **meta-skill-learnings**

## Target Repository

All changes target `~/Programming/JimmyTranDev/nvim` unless the learning is cross-cutting (then escalate to dotfiles AGENTS.md).

## AGENTS.md Structure

If creating `AGENTS.md` for the first time, use this structure:

```markdown
## Neovim Config Rules

- rule 1
- rule 2

## Plugin Gotchas

- gotcha 1
- gotcha 2

## Snacks Picker Patterns

- pattern 1
```

Add new sections as needed based on the learnings discovered.

## Rules

- Never duplicate knowledge that already exists in the nvim repo
- Keep learnings concise and actionable
- Prefer updating existing sections over creating new ones
- If `$ARGUMENTS` is "all", extract everything. If a topic is specified, focus on that domain only.
- Do not add code comments to lua files — save knowledge in AGENTS.md instead
