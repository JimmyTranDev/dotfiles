---
name: specify-innovate
description: Specify skill for innovation brainstorming — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`innovate-`

## Skills to Load

None required (domain skills loaded based on project type).

## Agents to Launch

None specified.

## Analysis Categories

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

### Context

This command runs inside OpenCode. Factor in the OpenCode workflow — slash commands, agents, skills, MCP tools, terminal-based interaction — when identifying improvements for OpenCode-related projects.

### User Profile Identification

- Determine who uses this project (end users, developers, operators, or the developer via OpenCode)
- Identify the primary workflows — what does a typical session look like?
- Note development environment constraints (terminal-based, CLI-first, AI-assisted)
- Check for existing TODO/FIXME markers that reveal known pain points

## Severity Classification

Rank by impact-to-effort ratio:
- **Quick wins**: Small effort, high user value
- **High-impact projects**: Large effort but transformative
- **Addressable now**: Can be done immediately with existing `/commands` or skills

## Scope Overrides

None — uses default scope detection.
