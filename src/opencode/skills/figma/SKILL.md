---
name: figma
description: Converts Figma designs into code via the Figma Dev Mode MCP server. Use when a Figma file/frame/component URL or node id appears, when translating a design or mockup into UI code, extracting design tokens/variables, or pulling a rendered image of a selection. Triggers on "figma", "design-to-code", "dev mode", "implement this design", "design tokens", "figma.com/design" / "figma.com/file" links.
---

# Figma — Design to Code

## Overview

Turn Figma designs into production code by reading the design through the
**Figma Dev Mode MCP server** rather than guessing from a screenshot. The MCP
returns the design's structure, generated code, and the actual variables/tokens
behind a selection — far more faithful than eyeballing an image.

This server is configured in `opencode.jsonc` as the `Figma` MCP
(`http://127.0.0.1:3845/mcp`). Its tools are namespaced under that server and
discovered at runtime — list the available tools and prefer the Figma ones over
reimplementing from a flat image.

## Prerequisites

The Dev Mode MCP server is served by the **Figma desktop app**, not the web app:

1. Open the design in the **Figma desktop app** (Dev Mode MCP requires a Dev or
   Full seat on a paid plan).
2. Enable **Preferences → Enable Dev Mode MCP Server** (serves on
   `http://127.0.0.1:3845/mcp`).
3. Confirm the `Figma` MCP is `enabled` in `opencode.jsonc`.

If MCP tools are unavailable or the server is unreachable, say so and fall back
to `get_image`/a provided screenshot — do not silently invent styles.

## Selecting the target

Figma MCP tools act on a node. Provide it one of two ways:

- **Selection** — the user selects a frame/component in the Figma desktop app;
  tools operate on the current selection.
- **Node id** — extract it from the URL's `node-id` query param. In a URL the
  id uses a dash (`node-id=1234-5678`); the API form uses a colon
  (`1234:5678`).
  `https://www.figma.com/design/<fileKey>/<name>?node-id=1234-5678` → node
  `1234:5678`.

## Typical Dev Mode MCP tools

Exact tool names depend on the server version — discover them at runtime. The
common surface:

| Tool | Purpose |
|------|---------|
| `get_code` | Generate code for the selected node/frame (steer it toward your framework) |
| `get_variable_defs` | Extract variables/design tokens (colors, spacing, type) used by the selection |
| `get_code_connect_map` | Map Figma nodes to existing codebase components (Code Connect) |
| `get_image` | Render an image of the selection for visual reference |
| `get_metadata` | Compact structural/XML view of the selection (node tree, sizes, positions) |

## Workflow

1. **Locate** — get the node id from the URL (or confirm the desktop selection).
2. **Inspect structure** — pull metadata/an image to understand layout,
   hierarchy, and spacing before writing code.
3. **Extract tokens** — `get_variable_defs` so you use the design system's real
   variables (e.g. `color/primary`, `spacing/4`) instead of hard-coded values.
4. **Check Code Connect** — `get_code_connect_map` to reuse existing components
   the design already maps to, rather than building new ones.
5. **Generate, then adapt** — use `get_code` as a starting point, then rewrite
   it to match this repo's framework, component library, naming, and style
   conventions. Treat MCP output as a draft, never a drop-in.
6. **Verify** — render `get_image` and compare against your built UI; reconcile
   spacing, color, and type. Run the project's build/lint.

## Conventions

- **Reuse over recreate.** Always check Code Connect / existing components
  before generating new markup. Map design tokens to existing theme variables.
- **Tokens, not magic numbers.** Pull variables and wire them to the codebase's
  design tokens; flag any design value with no token instead of hard-coding it.
- **Adapt generated code.** MCP `get_code` output is generic — conform it to the
  repo's framework, file structure, and lint rules. Pair with
  `frontend-ui-engineering` for production-quality component work.
- **Don't guess offscreen detail.** If the selection is ambiguous or truncated,
  pull metadata/image or ask which frame — don't fabricate states (hover,
  empty, error) the design doesn't show.
- **Large frames:** narrow to a specific component/node id rather than
  generating an entire page in one shot.

## Common pitfalls

| Pitfall | Reality |
|---|---|
| Using the web app | Dev Mode MCP is served by the **desktop** app only. |
| Hard-coding hex/px from an image | The design has variables — pull them with `get_variable_defs`. |
| Treating `get_code` as final | It's a draft; adapt to repo framework/conventions and review it. |
| Ignoring Code Connect | You may rebuild a component that already exists in the codebase. |
| `node-id` dash vs colon | URL uses `1234-5678`; API/tools use `1234:5678`. |
