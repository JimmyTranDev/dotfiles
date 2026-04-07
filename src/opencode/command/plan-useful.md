---
name: plan-useful
description: Identify practical features and improvements users would actually want based on real workflows and pain points
---

Usage: /plan-useful [focus area]

Analyze the project from a user's perspective and identify practical features, missing conveniences, and workflow improvements that solve real problems users face day-to-day.

Context: this command runs inside OpenCode, an AI-powered coding CLI. The user interacting with the project is a developer using OpenCode to build, debug, and maintain software. Factor in the OpenCode workflow — slash commands, agents, skills, MCP tools, terminal-based interaction — when identifying improvements. Consider what would make the developer's daily OpenCode-assisted workflow faster, smoother, and more reliable.

$ARGUMENTS

1. Understand the project (run independent commands in parallel):
   - Explore the project structure, entry points, and key modules to understand what the project does
   - Run `git log --oneline -30` to understand recent development direction and momentum
   - Read key config files, READMEs, or AGENTS.md to understand the project's purpose, audience, and conventions
   - Check for existing issue trackers, TODO comments, or FIXME markers that reveal known pain points
   - If the user specifies a focus area, narrow analysis to that scope

2. Identify the user profile and context:
   - Determine who uses this project (end users, developers, operators, or the developer themselves via OpenCode)
   - Identify the primary workflows — what does a typical session look like? What commands or sequences get run repeatedly?
   - Note the development environment constraints (terminal-based, CLI-first, AI-assisted via OpenCode)

3. Analyze the project for practical user needs across these categories (only include categories that are relevant):
   - **Pain point elimination**: Workflows that require too many steps, manual repetition, or workarounds — things users probably complain about or silently tolerate. For OpenCode-based projects, look for missing slash commands, agents, or skills that would automate common multi-step sequences.
   - **Missing conveniences**: Features that users would expect to exist but don't — things they'd search for in docs or ask about in issues. Consider missing CLI flags, configuration options, or integrations with tools already in the developer's stack.
   - **Error recovery**: Places where users can get stuck, lose work, or hit dead ends with no clear path forward — missing undo, poor error messages, no fallback options. In AI-assisted workflows, this includes cases where the AI produces incorrect output and there's no easy way to roll back or retry.
   - **Workflow shortcuts**: Common multi-step sequences that could be collapsed into single actions — batch operations, presets, templates, saved configurations. For OpenCode projects, this means new `/commands` that chain existing commands, or new skills that encode domain knowledge the AI currently lacks.
   - **Discoverability gaps**: Useful features that exist but are hard to find — buried settings, undocumented capabilities, non-obvious but powerful combinations. Consider whether existing slash commands, agents, or skills are well-named and well-described enough for users to find them.
   - **Data and feedback**: Places where the user is left guessing — missing progress indicators, unclear status, no confirmation of success, lack of actionable diagnostics. In terminal/CLI contexts, consider output formatting, verbosity levels, and structured output options.
   - **Customization needs**: Areas where users have different preferences or contexts that a single default can't satisfy — but configuration is missing or too rigid. Consider per-project vs global settings, environment-specific behavior, and theme/display preferences.
   - **Cross-tool integration**: Gaps between this project and the developer's broader toolchain — git workflows, CI/CD, issue trackers, package managers, deployment targets — where a small bridge would eliminate context switching.

4. For each suggestion:
   - Give it a short, clear name
   - Describe the user problem it solves and why a user would want it in 1-2 sentences
   - Estimate effort (small, medium, large) and impact (high, medium, low)
   - Suggest where in the codebase it would fit and which existing patterns to follow
   - Suggest which `/command` to run to get started (e.g., `/implement`, `/fix`, `/design`, `/plan-innovate`)

5. Present findings:
   - Group by category
   - Within each category, rank by impact-to-effort ratio (quick wins first, then high-impact projects)
   - Highlight the top 3 "most wanted" improvements across all categories — things users would thank you for
   - Flag any suggestions that could be addressed immediately with existing `/commands` or skills

6. Output findings directly in chat as the final response. If the user specifies an output destination (file path, format, etc.), write there instead.
   - When writing to a file, append a new section with a timestamp header (create the file if it doesn't exist)
   - Use the same grouped-by-category format from step 5
   - Include effort/impact estimates and suggested `/command` for each item
