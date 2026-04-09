---
name: storybook-mcp
description: Storybook MCP tool usage patterns for querying component documentation, generating stories, previewing UI, running tests, and integrating AI agents with Storybook design systems
---

## Prerequisites

- Storybook dev server running (default: `http://localhost:6006`)
- `@storybook/addon-mcp` installed and registered in the project's Storybook config
- MCP server accessible at `http://localhost:<port>/mcp`
- React projects only (manifests are currently React-only)

## Setup

Install the addon in the target project:

```bash
npx storybook add @storybook/addon-mcp
```

The MCP server becomes available at `http://localhost:6006/mcp` when Storybook is running.

## Tool Overview

Tools are organized into three toolsets: docs, development, and testing.

### Docs Toolset

| Tool | Purpose |
|------|---------|
| `list-all-documentation` | Returns an index of all documented components and unattached docs entries |
| `get-documentation` | Returns detailed docs for a specific component (props, first 3 stories, remaining story index, additional docs) |
| `get-documentation-for-story` | Returns full story source and associated docs for a specific story variant |

### Development Toolset

| Tool | Purpose |
|------|---------|
| `get-storybook-story-instructions` | Returns instructions for writing stories including props to capture and interaction test patterns |
| `preview-stories` | Returns rendered story previews in the chat interface (if agent supports MCP Apps) or links to stories in Storybook |

### Testing Toolset

| Tool | Purpose |
|------|---------|
| `run-story-tests` | Runs tests for specific stories and returns results including accessibility issues, with instructions to resolve failures |

## Interaction Workflow

Every Storybook MCP workflow follows this sequence:

1. **Discover** -- call `list-all-documentation` to find available components
2. **Inspect** -- call `get-documentation` for specific components to understand props, usage, and examples
3. **Deep dive** -- call `get-documentation-for-story` when a specific story needs more detail than `get-documentation` provides
4. **Act** -- implement UI using the documented components, generate stories, or run tests
5. **Verify** -- call `run-story-tests` to validate the implementation, fix issues, and re-test

Always query documentation before using any component property. Never assume properties exist based on naming conventions or other libraries.

## Common Patterns

### Build UI with Existing Components

1. Call `list-all-documentation` to find components matching the UI requirements
2. Call `get-documentation` for each relevant component to learn props, variants, and usage
3. Compose components into the target UI
4. Call `get-storybook-story-instructions` to learn current story conventions
5. Write stories for the new UI using `preview-stories` to verify rendering
6. Call `run-story-tests` to validate -- fix and re-test if failures occur

### Generate Stories for an Existing Component

1. Call `get-documentation` to understand the component's props and existing stories
2. Call `get-storybook-story-instructions` to get current conventions and interaction test patterns
3. Write new stories covering untested states, edge cases, and interactions
4. Call `preview-stories` to verify rendering
5. Call `run-story-tests` to validate

### Run and Fix Tests

1. Call `run-story-tests` targeting the relevant stories
2. Interpret results -- the tool returns both test failures and accessibility violations
3. Fix issues in the component or story code
4. Re-run `run-story-tests` to confirm resolution
5. Repeat until all tests pass (self-healing loop)

### Explore Component Documentation

1. Call `list-all-documentation` for the full component index
2. Call `get-documentation` for a specific component
3. If a story's details are insufficient, call `get-documentation-for-story` with the component ID and story name

### Preview a Component in a Specific State

1. Call `get-documentation` to find available stories for the component
2. Call `preview-stories` with the target story to render it in the chat interface
3. If the agent does not support MCP Apps, the tool returns Storybook URLs instead

## Multi-Storybook Composition

When the project uses Storybook composition, the MCP server automatically includes manifests from all composed Storybooks. Tools like `list-all-documentation` and `get-documentation` return combined results across all composed sources without extra configuration.

## Agent Instructions

When using Storybook MCP in a project, add guidance to the project's AGENTS.md:

- Always call `list-all-documentation` before building UI to discover available components
- Always call `get-documentation` before using any component property -- never assume props exist
- Use `get-storybook-story-instructions` before writing stories to follow current conventions
- Run `run-story-tests` after generating or modifying stories to validate correctness
- If tests fail, fix the issue and re-run tests to confirm (self-healing loop)

## Limitations

| Limitation | Notes |
|------------|-------|
| React only | Manifests and docs toolset currently only support React projects |
| Requires running Storybook | MCP server is served by the Storybook dev server -- it must be running |
| Port conflicts | Default port 6006 may differ -- update the MCP URL accordingly |
| MCP Apps support | `preview-stories` rendering depends on agent MCP Apps support; falls back to URLs |
| Manifest generation | Components must have stories and proper TypeScript types for manifests to include them |
