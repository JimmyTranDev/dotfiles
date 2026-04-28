---
name: specify-innovate
description: Brainstorm new ideas, practical improvements, and workflow enhancements for the project and write spec to `spec/`
---

Usage: /specify-innovate [focus area]

Analyze the project and brainstorm ideas — new features, practical improvements, workflow enhancements, and creative solutions that would make the project better for its users.

Context: this command runs inside OpenCode, an AI-powered coding CLI. The user interacting with the project is a developer using OpenCode to build, debug, and maintain software. Factor in the OpenCode workflow — slash commands, agents, skills, MCP tools, terminal-based interaction — when identifying improvements. Consider what would make the developer's daily OpenCode-assisted workflow faster, smoother, and more reliable.

$ARGUMENTS

1. Understand the project (run independent commands in parallel):
   - Explore the project structure, entry points, and key modules to understand what the project does
   - Run `git log --oneline -30` to understand recent development direction and momentum
   - Read key config files, READMEs, or AGENTS.md to understand the project's purpose, audience, and conventions
   - Check for existing issue trackers, TODO comments, or FIXME markers that reveal known pain points

2. Identify the user profile and context:
   - Determine who uses this project (end users, developers, operators, or the developer themselves via OpenCode)
   - Identify the primary workflows — what does a typical session look like?
   - Note the development environment constraints (terminal-based, CLI-first, AI-assisted via OpenCode)

3. Brainstorm ideas across these categories (only include categories that are relevant):
   - **New features**: Functionality the project doesn't have yet but would benefit its users — what users would love, what competitors offer, what's missing
   - **Pain point elimination**: Workflows that require too many steps, manual repetition, or workarounds. For OpenCode projects, look for missing slash commands, agents, or skills that would automate common sequences
   - **User experience enhancements**: Ways to make existing features more intuitive, faster, or more delightful — better defaults, smarter behaviors, reduced friction
   - **Missing conveniences**: Features users would expect but don't exist — missing CLI flags, configuration options, or integrations
   - **Error recovery**: Places where users can get stuck, lose work, or hit dead ends — missing undo, poor error messages, no fallback options
   - **Workflow shortcuts**: Common multi-step sequences that could be collapsed into single actions — batch operations, presets, templates
   - **Integrations**: Connections with other tools, services, or ecosystems that would multiply the project's value
   - **Discoverability gaps**: Useful features that exist but are hard to find — buried settings, undocumented capabilities, non-obvious combinations
   - **Data and feedback**: Places where the user is left guessing — missing progress indicators, unclear status, lack of actionable diagnostics
   - **Customization needs**: Areas where users have different preferences that a single default can't satisfy
   - **Scaling & future-proofing**: Extensibility points, plugin systems, configuration options that prepare for growth

4. For each idea:
   - Give it a short, clear name
   - Describe the user problem it solves and why users would want it in 1-2 sentences
   - Estimate effort (small, medium, large) and impact (high, medium, low)
   - Suggest where in the codebase it would fit and which existing patterns to follow
   - Suggest which `/command` to run to get started (e.g., `/implement`, `/fix`)

5. Present findings:
   - Group by category
   - Within each category, rank by impact-to-effort ratio (quick wins first, then high-impact projects)
   - Highlight the top 3 "most wanted" improvements across all categories
   - Flag any suggestions that could be addressed immediately with existing `/commands` or skills

6. Write findings to a spec file using the `innovate-` prefix per the `specify-*` conventions in AGENTS.md.
