---
name: stitch-mcp
description: Stitch MCP tool usage patterns for fetching AI-generated UI designs, building sites from screens, and integrating Google Stitch designs into coding workflows
---

## Tool Overview

The stitch MCP proxy exposes upstream Stitch API tools plus virtual tools that combine multiple API calls into higher-level operations.

### Virtual Tools

| Tool | Purpose |
|------|---------|
| `get_screen_code` | Retrieve a screen and download its HTML code content |
| `get_screen_image` | Retrieve a screen and download its screenshot image as base64 |
| `build_site` | Build a site from a project by mapping screens to routes, returns design HTML per page |

### Upstream Tools

| Tool | Purpose |
|------|---------|
| `list_projects` | List all projects accessible to the user |
| `get_project` | Get project details including screen instances |
| `create_project` | Create a new project |
| `list_screens` | List all screens in a project |
| `get_screen` | Get details of a specific screen |
| `generate_screen_from_text` | Generate a new screen from a text prompt |
| `edit_screens` | Edit existing screens with a text prompt |
| `generate_variants` | Generate variants of existing screens |
| `create_design_system` | Create a design system for a project |
| `update_design_system` | Update an existing design system |
| `list_design_systems` | List design systems for a project |
| `apply_design_system` | Apply a design system to screens |

## Parameter Format

Project and screen IDs are plain numeric/hex strings without prefixes, except where noted:

- `projectId`: `"5198704158110731809"` (no `projects/` prefix)
- `screenId`: `"98b50e2ddc9943efb387052637738f61"` (no `screens/` prefix)
- `name` on `get_project`: `"projects/5198704158110731809"` (requires `projects/` prefix)
- `name` on `get_screen`: `"projects/{project}/screens/{screen}"` (full resource path)

## Workflow

1. **List projects** — call `list_projects` to browse available projects
2. **Get project details** — call `get_project` with `name: "projects/{id}"` to see screen instances
3. **List screens** — call `list_screens` with `projectId` to get screen IDs
4. **Get screen content** — call `get_screen_code` or `get_screen_image` with `projectId` and `screenId`

## get_screen_code

Retrieves a screen by ID and returns its full HTML content.

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | The project ID (e.g. `"5198704158110731809"`) |
| `screenId` | Yes | string | The screen ID (e.g. `"98b50e2ddc9943efb387052637738f61"`) |

## get_screen_image

Retrieves a screen screenshot as a base64-encoded image.

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | The project ID |
| `screenId` | Yes | string | The screen ID |

## build_site

Maps project screens to URL routes and returns the design HTML for each page.

```json
{
  "projectId": "5198704158110731809",
  "routes": [
    { "screenId": "abc123", "route": "/" },
    { "screenId": "def456", "route": "/about" }
  ]
}
```

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | The project ID |
| `routes` | Yes | array | Screen-to-route mapping |
| `routes[].screenId` | Yes | string | Screen ID within the project |
| `routes[].route` | Yes | string | URL route (e.g. `/`, `/about`) |

## list_projects

Lists all projects accessible to the user.

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `filter` | No | string | AIP-160 filter (e.g. filter by `view` field) |

Returns projects with `name`, `title`, `deviceType`, `screenInstances`, and `designTheme`.

## get_project

Retrieves project details including all screen instances.

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `name` | Yes | string | Resource name with prefix: `"projects/5198704158110731809"` |

## list_screens

Lists all screens within a project.

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | Project ID without prefix: `"5198704158110731809"` |

## get_screen

Retrieves details of a specific screen. Requires all three parameters.

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `name` | Yes | string | Full resource path: `"projects/{project}/screens/{screen}"` |
| `projectId` | Yes | string | Project ID without prefix |
| `screenId` | Yes | string | Screen ID without prefix |

## generate_screen_from_text

Generates a new screen from a text prompt. This can take a few minutes.

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | Project ID without prefix |
| `prompt` | Yes | string | Text description of the screen to generate |
| `deviceType` | No | string | Target device: `"mobile"` or `"desktop"` |
| `modelId` | No | string | Model to use for generation |

## edit_screens

Edits existing screens with a text prompt. This can take a few minutes.

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | Project ID without prefix |
| `selectedScreenIds` | Yes | array | Screen IDs to edit (array of strings) |
| `prompt` | Yes | string | Text description of the edits |
| `deviceType` | No | string | Target device type |
| `modelId` | No | string | Model to use for generation |

## generate_variants

Generates variants of existing screens.

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | Project ID without prefix |
| `selectedScreenIds` | Yes | array | Screen IDs to generate variants for |
| `prompt` | Yes | string | Text description for variant generation |
| `variantOptions` | Yes | object | Options: number of variants, creative range, focus aspects |
| `deviceType` | No | string | Target device type |
| `modelId` | No | string | Model to use for generation |

## Common Patterns

### Get Design HTML for Implementation

1. Call `list_projects` to find the target project
2. Call `list_screens` with `projectId` to get screen IDs
3. Call `get_screen_code` with `projectId` and `screenId`
4. Use the returned HTML/CSS as reference for implementing components

### Generate New Designs

1. Call `create_project` with a title, or use an existing project
2. Call `generate_screen_from_text` with a prompt describing the UI
3. Call `get_screen_image` to preview the result
4. Call `edit_screens` to refine, or `generate_variants` to explore alternatives

### Build a Multi-Page Site

1. Call `list_screens` to get all screen IDs in the project
2. Decide on route mappings (which screen goes to which URL path)
3. Call `build_site` with the project ID and route array
4. Use the returned HTML per route to scaffold the site

### Get Visual Reference

1. Call `get_screen_image` to get a base64 screenshot
2. Use the image as a visual reference alongside code generation

### Finding Screen IDs from a Stitch URL

Stitch URLs use the format: `stitch.withgoogle.com/projects/{projectId}?node-id={screenInstanceId}`

The `node-id` from the URL maps to a screen instance `id` in the project. To get the screen content:
1. Call `list_projects` and find the project by ID
2. Look at `screenInstances` in the project data — match `id` to the `node-id` from the URL
3. The `sourceScreen` field contains the full resource name with the screen ID
4. Extract the screen ID from `sourceScreen` (the part after `screens/`)
5. Use that screen ID with `get_screen_code` or `get_screen_image`

## Authentication

Authentication is handled automatically by the proxy. Setup options:

| Method | How |
|--------|-----|
| Guided wizard | `stitch-mcp init` (handles gcloud, OAuth, config) |
| API key | Set `STITCH_API_KEY` environment variable |
| System gcloud | Set `STITCH_USE_SYSTEM_GCLOUD=1` env var with existing gcloud config |

## CLI Commands

These commands are available outside of MCP for direct terminal use:

| Command | Purpose |
|---------|---------|
| `stitch-mcp init` | Setup auth, gcloud, and MCP client config |
| `stitch-mcp doctor` | Verify configuration health |
| `stitch-mcp serve -p <id>` | Preview project screens on local Vite dev server |
| `stitch-mcp site -p <id>` | Generate Astro project from screens |
| `stitch-mcp view` | Interactive resource browser in terminal |
| `stitch-mcp tool [name]` | Invoke MCP tools from CLI |
| `stitch-mcp logout` | Revoke credentials |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `STITCH_API_KEY` | API key for direct authentication (skips OAuth) |
| `STITCH_ACCESS_TOKEN` | Pre-existing access token |
| `STITCH_USE_SYSTEM_GCLOUD` | Use system gcloud config instead of isolated config |
| `STITCH_PROJECT_ID` | Override project ID |
| `STITCH_HOST` | Custom Stitch API endpoint |
