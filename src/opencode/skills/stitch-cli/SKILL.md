---
name: stitch-cli
description: Stitch CLI usage patterns for fetching AI-generated UI designs, building sites from screens, and integrating Google Stitch designs into coding workflows
---

## How to Call Stitch Tools

Run Stitch tool operations via the `stitch-mcp tool <tool_name>` CLI command in Bash. Pass parameters as JSON with the `-d` flag.

```bash
stitch-mcp tool <tool_name> -d '{"key": "value"}'
```

Tools with no required parameters can omit `-d`. Use `-o json` for machine-readable output, `-o raw` for unprocessed output.

Use `-s` or `--schema` to inspect a tool's arguments before calling it:

```bash
stitch-mcp tool <tool_name> -s
```

## Tool Reference

### Virtual Tools

| Tool | Purpose |
|------|---------|
| `get_screen_code` | Retrieve a screen and download its HTML code content |
| `get_screen_image` | Retrieve a screen and download its screenshot image content |
| `build_site` | Build a site from a project by mapping screens to routes, returns design HTML per page |
| `list_tools` | List all available tools with their descriptions and schemas |

### Upstream Tools

| Tool | Purpose |
|------|---------|
| `list_projects` | List all projects accessible to the user |
| `get_project` | Get project details including screen instances |
| `create_project` | Create a new project |
| `list_screens` | List all screens in a project |
| `get_screen` | Get details of a specific screen |
| `generate_screen_from_text` | Generate a new screen from a text prompt (can take minutes) |
| `edit_screens` | Edit existing screens with a text prompt (can take minutes) |
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

1. **List projects** -- `stitch-mcp tool list_projects`
2. **Get project details** -- `stitch-mcp tool get_project -d '{"name": "projects/{id}"}'`
3. **List screens** -- `stitch-mcp tool list_screens -d '{"projectId": "{id}"}'`
4. **Get screen content** -- run `get_screen_code` and `get_screen_image` in parallel

## get_screen_code

Retrieves a screen by ID and returns its full HTML content.

```bash
stitch-mcp tool get_screen_code -d '{"projectId": "5198704158110731809", "screenId": "98b50e2ddc9943efb387052637738f61"}'
```

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | The project ID |
| `screenId` | Yes | string | The screen ID |

## get_screen_image

Retrieves a screen screenshot image content.

```bash
stitch-mcp tool get_screen_image -d '{"projectId": "5198704158110731809", "screenId": "98b50e2ddc9943efb387052637738f61"}'
```

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | The project ID |
| `screenId` | Yes | string | The screen ID |

## build_site

Maps project screens to URL routes and returns the design HTML for each page.

```bash
stitch-mcp tool build_site -d '{"projectId": "5198704158110731809", "routes": [{"screenId": "abc123", "route": "/"}, {"screenId": "def456", "route": "/about"}]}'
```

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | The project ID |
| `routes` | Yes | array | Screen-to-route mapping |
| `routes[].screenId` | Yes | string | Screen ID within the project |
| `routes[].route` | Yes | string | URL route (e.g. `/`, `/about`) |

## list_projects

Lists all projects accessible to the user.

```bash
stitch-mcp tool list_projects
stitch-mcp tool list_projects -d '{"filter": "view=shared"}'
```

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `filter` | No | string | AIP-160 filter: `view=owned` (default) or `view=shared` |

Returns projects with `name`, `title`, `deviceType`, `screenInstances`, and `designTheme`.

## get_project

Retrieves project details including all screen instances.

```bash
stitch-mcp tool get_project -d '{"name": "projects/5198704158110731809"}'
```

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `name` | Yes | string | Resource name with prefix: `"projects/5198704158110731809"` |

## list_screens

Lists all screens within a project.

```bash
stitch-mcp tool list_screens -d '{"projectId": "5198704158110731809"}'
```

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | Project ID without prefix |

## get_screen

Retrieves details of a specific screen. Requires all three parameters.

```bash
stitch-mcp tool get_screen -d '{"name": "projects/{project}/screens/{screen}", "projectId": "{project}", "screenId": "{screen}"}'
```

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `name` | Yes | string | Full resource path: `"projects/{project}/screens/{screen}"` |
| `projectId` | Yes | string | Project ID without prefix |
| `screenId` | Yes | string | Screen ID without prefix |

## generate_screen_from_text

Generates a new screen from a text prompt. This can take a few minutes -- do NOT retry on timeout.

If the tool call fails due to a connection error, the generation may still succeed. Try `get_screen` later to check.

The response may include `output_components` with suggestions. If present, show them to the user. If the user accepts a suggestion, call `generate_screen_from_text` again with `prompt` set to the accepted suggestion.

```bash
stitch-mcp tool generate_screen_from_text -d '{"projectId": "5198704158110731809", "prompt": "a dashboard with analytics charts", "deviceType": "desktop"}'
```

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | Project ID without prefix |
| `prompt` | Yes | string | Text description of the screen to generate |
| `deviceType` | No | string | Target device: `"mobile"` or `"desktop"` |
| `modelId` | No | string | Model to use for generation |

## edit_screens

Edits existing screens with a text prompt. This can take a few minutes -- do NOT retry on timeout.

```bash
stitch-mcp tool edit_screens -d '{"projectId": "5198704158110731809", "selectedScreenIds": ["98b50e2ddc9943efb387052637738f61"], "prompt": "make the header larger"}'
```

| Parameter | Required | Type | Purpose |
|-----------|----------|------|---------|
| `projectId` | Yes | string | Project ID without prefix |
| `selectedScreenIds` | Yes | array | Screen IDs to edit (array of strings) |
| `prompt` | Yes | string | Text description of the edits |
| `deviceType` | No | string | Target device type |
| `modelId` | No | string | Model to use for generation |

## generate_variants

Generates variants of existing screens.

```bash
stitch-mcp tool generate_variants -d '{"projectId": "5198704158110731809", "selectedScreenIds": ["98b50e2ddc9943efb387052637738f61"], "prompt": "explore different color schemes", "variantOptions": {}}'
```

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

1. Run `stitch-mcp tool list_projects` to find the target project
2. Run `stitch-mcp tool list_screens -d '{"projectId": "<id>"}'` to get screen IDs
3. Run `stitch-mcp tool get_screen_code -d '{"projectId": "<id>", "screenId": "<id>"}'`
4. Use the returned HTML/CSS as reference for implementing components

### Generate New Designs

1. Run `stitch-mcp tool create_project -d '{"title": "<name>"}'`, or use an existing project
2. Run `stitch-mcp tool generate_screen_from_text -d '{"projectId": "<id>", "prompt": "<description>"}'`
3. Run `stitch-mcp tool get_screen_image -d '{"projectId": "<id>", "screenId": "<id>"}'` to preview
4. Run `edit_screens` to refine, or `generate_variants` to explore alternatives

### Build a Multi-Page Site

1. Run `stitch-mcp tool list_screens -d '{"projectId": "<id>"}'` to get all screen IDs
2. Decide on route mappings (which screen goes to which URL path)
3. Run `stitch-mcp tool build_site -d '{"projectId": "<id>", "routes": [...]}'`
4. Use the returned HTML per route to scaffold the site

### Get Visual Reference

1. Run `stitch-mcp tool get_screen_image -d '{"projectId": "<id>", "screenId": "<id>"}'`
2. Use the image as a visual reference alongside code generation

### Finding Screen IDs from a Stitch URL

Stitch URLs use the format: `stitch.withgoogle.com/projects/{projectId}?node-id={screenInstanceId}`

The `node-id` from the URL maps to a screen instance `id` in the project. To get the screen content:
1. Run `stitch-mcp tool list_projects` and find the project by ID
2. Look at `screenInstances` in the project data -- match `id` to the `node-id` from the URL
3. The `sourceScreen` field contains the full resource name with the screen ID
4. Extract the screen ID from `sourceScreen` (the part after `screens/`)
5. Use that screen ID with `get_screen_code` or `get_screen_image`

## Authentication

Setup options:

| Method | How |
|--------|-----|
| Guided wizard | `stitch-mcp init` (handles gcloud, OAuth, config) |
| API key | Set `STITCH_API_KEY` environment variable |
| System gcloud | Set `STITCH_USE_SYSTEM_GCLOUD=1` env var with existing gcloud config |

## Standalone CLI Commands

These commands are run directly (not via `stitch-mcp tool`):

| Command | Purpose |
|---------|---------|
| `stitch-mcp init` | Setup auth, gcloud, and MCP client config |
| `stitch-mcp doctor` | Verify configuration health |
| `stitch-mcp screens -p <id>` | Explore all screens in a project |
| `stitch-mcp serve -p <id>` | Serve project HTML screens via local web server |
| `stitch-mcp site -p <id>` | Build a structured site from Stitch screens |
| `stitch-mcp snapshot` | Create a UI snapshot given a data state |
| `stitch-mcp view` | Interactive resource browser in terminal |
| `stitch-mcp logout` | Revoke credentials |

### serve options

| Flag | Purpose |
|------|---------|
| `-p, --project <id>` | Project ID |
| `-l, --list-screens` | List all screens with their server paths as JSON |
| `--json` | Start server in non-interactive mode, output JSON when ready |

### site options

| Flag | Purpose |
|------|---------|
| `-p, --project <id>` | Project ID |
| `-o, --output <dir>` | Output directory (default: `.`) |
| `-e, --export` | Export screen-to-route config as `build_site` JSON |
| `-l, --list-screens` | List all screens with suggested routes as JSON |
| `-r, --routes <json>` | JSON array of `{screenId, route}` mappings (skips TUI) |

### snapshot options

| Flag | Purpose |
|------|---------|
| `-c, --command <command>` | The command to snapshot (e.g. `init`) |
| `-d, --data <file>` | Path to JSON data file |
| `-s, --schema` | Print the data schema for the command |

### view options

| Flag | Purpose |
|------|---------|
| `--projects` | List all projects |
| `--name <name>` | Resource name to view |
| `--sourceScreen <name>` | Source screen resource name |
| `--project <id>` | Project ID |
| `--screen <id>` | Screen ID |
| `--serve` | Serve the screen via local server |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `STITCH_API_KEY` | API key for direct authentication (skips OAuth) |
| `STITCH_ACCESS_TOKEN` | Pre-existing access token |
| `STITCH_USE_SYSTEM_GCLOUD` | Use system gcloud config instead of isolated config |
| `STITCH_PROJECT_ID` | Override project ID |
| `STITCH_HOST` | Custom Stitch API endpoint |
