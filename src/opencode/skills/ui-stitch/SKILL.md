---
name: ui-stitch
description: Stitch MCP tool usage patterns for fetching AI-generated UI designs, generating screens, building sites, and integrating Google Stitch designs into coding workflows
---

## Tool Overview

Stitch tools are available via the MCP proxy configured in `opencode.json`. The proxy exposes both upstream Stitch API tools and virtual tools that combine multiple API calls into single operations.

### Upstream Tools

| Tool | Purpose |
|------|---------|
| `list_projects` | List all Stitch projects accessible to the user |
| `get_project` | Get details for a specific project by resource name |
| `list_screens` | List all screens within a project |
| `get_screen` | Get details for a specific screen (metadata, download URLs) |
| `generate_screen_from_text` | Generate a new screen from a text prompt |
| `edit_screens` | Edit existing screens using a text prompt |
| `generate_variants` | Generate design variants of existing screens |

### Virtual Tools

Virtual tools are added by the proxy. They combine multiple API calls into higher-level operations.

| Tool | Purpose |
|------|---------|
| `get_screen_code` | Retrieve a screen and download its HTML code content |
| `get_screen_image` | Retrieve a screen and download its screenshot image as base64 |
| `build_site` | Build a site from a project by mapping screens to routes, returns design HTML per page |
| `list_tools` | List all available tools with their descriptions and schemas |

## Interaction Workflow

Every Stitch design workflow follows this sequence:

1. **Discover** -- call `list_projects` to find available projects
2. **Browse** -- call `list_screens` with the project ID to see available screens
3. **Fetch** -- call `get_screen_code` and `get_screen_image` in parallel to get both the HTML source and visual screenshot
4. **Act** -- implement, review, edit, or generate based on the design content

Always retrieve both `get_screen_code` and `get_screen_image` for any screen -- code provides the implementation reference, the screenshot provides visual context.

## Tool Schemas

### list_projects

No required parameters. Returns projects with `name`, `title`, `deviceType`, `screenInstances`, and `designTheme`.

Optional parameter `filter` (string): AIP-160 filter, e.g. `"view=shared"` (default: `"view=owned"`).

### get_project

| Parameter | Required | Type | Notes |
|-----------|----------|------|-------|
| `name` | Yes | string | Resource name with prefix: `"projects/5198704158110731809"` |

### list_screens

| Parameter | Required | Type | Notes |
|-----------|----------|------|-------|
| `projectId` | Yes | string | Project ID without prefix |

### get_screen

| Parameter | Required | Type | Notes |
|-----------|----------|------|-------|
| `name` | Yes | string | Full resource path: `"projects/{project}/screens/{screen}"` |
| `projectId` | Yes | string | Project ID without prefix |
| `screenId` | Yes | string | Screen ID without prefix |

### get_screen_code

Returns the screen object with an added `htmlContent` field containing the full HTML source.

| Parameter | Required | Type | Notes |
|-----------|----------|------|-------|
| `projectId` | Yes | string | Project ID without prefix |
| `screenId` | Yes | string | Screen ID without prefix |

### get_screen_image

Returns the screen object with an added `screenshotBase64` field containing a base64-encoded PNG.

| Parameter | Required | Type | Notes |
|-----------|----------|------|-------|
| `projectId` | Yes | string | Project ID without prefix |
| `screenId` | Yes | string | Screen ID without prefix |

### generate_screen_from_text

Generation can take several minutes. Do NOT retry on timeout -- a connection error does not mean generation failed. Check with `list_screens` or `get_screen` afterward.

| Parameter | Required | Type | Notes |
|-----------|----------|------|-------|
| `projectId` | Yes | string | Project ID without prefix |
| `prompt` | Yes | string | Text description of the screen to generate |
| `deviceType` | No | string | `"mobile"` or `"desktop"` |
| `modelId` | No | string | Model to use for generation |

### edit_screens

Editing can take several minutes. Do NOT retry on timeout.

| Parameter | Required | Type | Notes |
|-----------|----------|------|-------|
| `projectId` | Yes | string | Project ID without prefix |
| `selectedScreenIds` | Yes | array | Screen IDs to edit (array of strings) |
| `prompt` | Yes | string | Text description of the edits |
| `deviceType` | No | string | Target device type |
| `modelId` | No | string | Model to use for generation |

### generate_variants

| Parameter | Required | Type | Notes |
|-----------|----------|------|-------|
| `projectId` | Yes | string | Project ID without prefix |
| `selectedScreenIds` | Yes | array | Screen IDs to generate variants for |
| `prompt` | Yes | string | Text description for variant generation |
| `variantOptions` | Yes | object | Options for variants (number, creative range, focus) |
| `deviceType` | No | string | Target device type |
| `modelId` | No | string | Model to use for generation |

### build_site

Maps project screens to URL routes and returns the design HTML for each page. Returns an object with `success`, `pages` (array of `{ screenId, route, title, html }`), and `message`.

| Parameter | Required | Type | Notes |
|-----------|----------|------|-------|
| `projectId` | Yes | string | Project ID without prefix |
| `routes` | Yes | array | Array of `{ screenId: string, route: string }` |

Each route path must be unique. Verify screen IDs with `list_screens` first.

## Common Parameter Mistakes

- **Forgetting `projectId`**: every screen-level tool requires a `projectId`. Use `list_projects` first.
- **Screen name vs screen ID**: `screenId` expects the screen's ID (e.g. `98b50e2ddc9943efb387052637738f61`), not its display name. Use `list_screens` to find IDs.
- **Duplicate routes in `build_site`**: each route path must be unique -- the tool validates and returns an error on duplicates.
- **`get_project` name format**: requires `"projects/"` prefix (e.g. `"projects/5198704158110731809"`).
- **`get_screen` name format**: requires full resource path `"projects/{project}/screens/{screen}"`.

## Common Patterns

### Get Design HTML for Implementation

1. Call `list_projects` to find the target project
2. Call `list_screens` with the project ID to get screen IDs
3. Call `get_screen_code` and `get_screen_image` in parallel for the target screen
4. Use the returned HTML/CSS as reference for implementing components

### Generate New Designs

1. Call `list_projects` to find an existing project, or `create_project` to create one
2. Call `generate_screen_from_text` with the project ID and a text prompt
3. Call `get_screen_code` and `get_screen_image` in parallel to preview
4. Call `edit_screens` to refine, or `generate_variants` to explore alternatives

### Build a Multi-Page Site

1. Call `list_screens` to get all screen IDs in the project
2. Decide on route mappings (which screen goes to which URL path)
3. Call `build_site` with the project ID and route mappings
4. Use the returned HTML per route to scaffold the site

### Finding Screen IDs from a Stitch URL

Stitch URLs use the format: `stitch.withgoogle.com/projects/{projectId}?node-id={screenInstanceId}`

The `node-id` from the URL maps to a screen instance `id` in the project:

1. Call `list_projects` and find the project by ID
2. Look at `screenInstances` in the project data -- match `id` to the `node-id` from the URL
3. The `sourceScreen` field contains the full resource name with the screen ID
4. Extract the screen ID from `sourceScreen` (the part after `screens/`)
5. Use that screen ID with `get_screen_code` or `get_screen_image`

## CLI Usage

The `stitch-mcp` binary can also be used directly via Bash for debugging and exploration:

```bash
stitch-mcp tool
stitch-mcp tool <tool_name> -s
stitch-mcp tool <tool_name> -d '{"key": "value"}'
stitch-mcp tool <tool_name> -o json
```

| Flag | Purpose |
|------|---------|
| `-s, --schema` | Show a tool's input schema |
| `-d, --data <json>` | Pass JSON parameters (like curl `-d`) |
| `-f, --data-file <path>` | Read JSON from file |
| `-o, --output <format>` | Output format: `json`, `pretty`, `raw` |

### Standalone Commands

| Command | Purpose |
|---------|---------|
| `stitch-mcp init` | Setup auth, gcloud, and MCP client config |
| `stitch-mcp doctor` | Verify configuration health |
| `stitch-mcp serve -p <id>` | Preview project screens on local Vite dev server |
| `stitch-mcp screens -p <id>` | Browse screens in terminal |
| `stitch-mcp view` | Interactive resource browser |
| `stitch-mcp site -p <id>` | Build an Astro site from screens |
| `stitch-mcp snapshot` | Save screen state to file |
| `stitch-mcp logout` | Revoke credentials |

## Authentication

| Method | How |
|--------|-----|
| Guided wizard | `stitch-mcp init` (handles gcloud, OAuth, config) |
| API key | Set `STITCH_API_KEY` environment variable |
| System gcloud | Set `STITCH_USE_SYSTEM_GCLOUD=1` with existing gcloud config |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `STITCH_API_KEY` | API key for direct authentication (skips OAuth) |
| `STITCH_ACCESS_TOKEN` | Pre-existing access token |
| `STITCH_USE_SYSTEM_GCLOUD` | Use system gcloud config instead of bundled config |
| `STITCH_PROJECT_ID` | Override project ID |
| `GOOGLE_CLOUD_PROJECT` | Alternative project ID variable |
| `STITCH_HOST` | Custom Stitch API endpoint |

## Troubleshooting

Run `stitch-mcp doctor --verbose` to diagnose issues. Common problems:
- Permission denied: ensure Owner/Editor role, billing enabled, Stitch API enabled
- Token expiry: the proxy auto-refreshes every 55 minutes; direct mode requires manual refresh
- Full reset: `stitch-mcp logout --force --clear-config` then `stitch-mcp init`
