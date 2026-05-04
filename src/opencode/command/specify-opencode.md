---
name: specify-opencode
description: Analyze OpenCode config (agents, commands, skills, AGENTS.md) for gaps, inconsistencies, and improvements and write spec to `spec/`
---

Usage: /specify-opencode [scope or focus area]

Analyze the OpenCode configuration and identify improvements — gaps, inconsistencies, redundancies, and missed opportunities across agents, commands, skills, and AGENTS.md.

$ARGUMENTS

1. Understand the current config state (run in parallel):
   - Read `src/opencode/AGENTS.md` for global rules
   - List all agents in `src/opencode/agent/`
   - List all commands in `src/opencode/command/`
   - List all skills in `src/opencode/skills/`
   - Run `git log --oneline -20` to understand recent config changes

2. Load skills: **meta-opencode-authoring**, **meta-agents-md**, **code-deduplicator**, **code-follower**. Analyze the config across these lenses:
   - **Coverage gaps**: Workflows that no command handles, domains no skill covers, situations no agent is suited for
   - **Clarity**: Descriptions too vague for correct routing, names that are confusing or non-obvious, commands that are hard to discover
   - **Consistency**: Files that break conventions others follow — wrong frontmatter, missing sections, different levels of detail
   - **Redundancy**: Knowledge duplicated across files — commands inlining skill content, agents repeating AGENTS.md rules, skills overlapping
   - **Ergonomics**: Names that are hard to remember, taxonomy that's unintuitive, too many steps for common operations
   - **Effectiveness**: Agent prompts that produce poor outputs, command workflows that miss edge cases, skills with outdated patterns

3. For each finding:
   - Name the lens it falls under
   - Identify the target file(s)
   - Describe current state and what's wrong
   - Estimate effort (small, medium, large) and impact (high, medium, low)
   - Suggest the specific fix

4. Present findings:
   - Group by lens
   - Within each lens, rank by impact-to-effort ratio (quick wins first)
   - Highlight the top 3 "best bang for buck" improvements across all lenses

5. Write findings to a spec file using the `opencode-` prefix per the `specify-*` conventions in AGENTS.md.
