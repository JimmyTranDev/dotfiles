---
name: stitch-mcp
description: Stitch MCP tool usage patterns for fetching AI-generated UI designs, building sites from screens, and integrating Google Stitch designs into coding workflows
---

## Tool Overview

The stitch MCP proxy exposes upstream Stitch API tools plus virtual tools that combine multiple API calls into higher-level operations.

### Virtual Tools

| Tool | Purpose |
|------|---------|
| `build_site` | Build a site from a project by mapping screens to routes, returns design HTML per page |
| `get_screen_code` | Retrieve a screen and download its HTML code content |
| `get_screen_image` | Retrieve a screen and download its screenshot image as base64 |

### Upstream Tools

The proxy also exposes all upstream Stitch MCP tools for listing projects, screens, and metadata.

## Workflow

1. **List projects** — use upstream tools to browse available Stitch projects
2. **Inspect screens** — view screen metadata, preview HTML, or get screenshots
3. **Build site** — map screens to routes and generate a deployable site structure

## build_site

Maps project screens to URL routes and returns the design HTML for each page.

```json
{
  "projectId": "123456",
  "routes": [
    { "screenId": "abc", "route": "/" },
    { "screenId": "def", "route": "/about" }
  ]
}
```

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | The Stitch project ID |
| `routes` | Yes | array | Screen-to-route mapping |
| `routes[].screenId` | Yes | string | Screen ID within the project |
| `routes[].route` | Yes | string | URL route (e.g. `/`, `/about`) |

## get_screen_code

Retrieves a screen by ID and returns its full HTML content.

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | The Stitch project ID |
| `screenId` | Yes | string | The screen ID to fetch |

## get_screen_image

Retrieves a screen screenshot as a base64-encoded image.

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | The Stitch project ID |
| `screenId` | Yes | string | The screen ID to capture |

## Common Patterns

### Get Design HTML for Implementation

1. List projects to find the target project ID
2. List screens within the project to find screen IDs
3. Call `get_screen_code` for the specific screen
4. Use the returned HTML/CSS as reference for implementing components

### Build a Multi-Page Site

1. List all screens in the project
2. Decide on route mappings (which screen goes to which URL path)
3. Call `build_site` with the project ID and route array
4. Use the returned HTML per route to scaffold the site

### Get Visual Reference

1. Call `get_screen_image` to get a base64 screenshot
2. Use the image as a visual reference alongside code generation

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
