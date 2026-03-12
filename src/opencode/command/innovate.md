---
name: innovate
description: Brainstorm new ideas, features, and creative improvements for the project
---

Usage: /innovate [focus area]

Analyze the project and brainstorm fresh ideas — new features, user-facing enhancements, and creative improvements that would make the project better.

$ARGUMENTS

1. Understand the project (run independent commands in parallel):
   - Explore the project structure, entry points, and key modules to understand what the project does
   - Run `git log --oneline -30` to understand recent development direction and momentum
   - Read key config files, READMEs, or AGENTS.md to understand the project's purpose and audience
   - If the user specifies a focus area, narrow ideation to that scope

2. Brainstorm ideas across these categories (only include categories that are relevant):
   - **New features**: Functionality the project doesn't have yet but would benefit its users — think about what users would love, what competitors offer, what's missing from the workflow
   - **User experience enhancements**: Ways to make existing features more intuitive, faster, or more delightful — better defaults, smarter behaviors, reduced friction
   - **Integrations**: Connections with other tools, services, or ecosystems that would multiply the project's value
   - **Automation opportunities**: Repetitive tasks that could be automated, workflows that could be streamlined, manual steps that could be eliminated
   - **Quality of life**: Small touches that make a big difference — better error messages, progress indicators, undo support, keyboard shortcuts, smart defaults
   - **Scaling & future-proofing**: Ideas that prepare the project for growth — extensibility points, plugin systems, configuration options

3. For each idea:
   - Give it a short, clear name
   - Describe what it does and why users would want it in 1-2 sentences
   - Estimate effort (small, medium, large) and impact (high, medium, low)
   - Suggest where in the codebase it would fit and which existing patterns to follow
   - Suggest which `/command` to run to get started (e.g., `/implement`, `/improve`, `/fix`)

4. Present ideas:
   - Group by category
   - Within each category, rank by impact-to-effort ratio (quick wins first, then high-impact projects)
   - Highlight the top 3 "best bang for buck" ideas across all categories

Do not apply changes. Present ideas only so the user can decide what to build next.
