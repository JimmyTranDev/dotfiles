---
name: tool-slack-cli
description: Slack CLI (slack) command reference for creating, running, deploying, and managing Slack apps, triggers, datastores, auth, and environment variables
---

## Command Overview

| Command | Subcommands | Purpose |
|---------|-------------|---------|
| `slack project` | `create`, `init`, `samples` | Scaffold and initialize Slack projects |
| `slack platform` | `run`, `deploy`, `activity` | Local dev server, deployment, and logs |
| `slack auth` | `login`, `logout`, `list`, `revoke`, `token` | Authentication and token management |
| `slack app` | `install`, `uninstall`, `delete`, `list`, `link`, `unlink`, `settings` | App lifecycle management |
| `slack trigger` | `create`, `delete`, `list`, `info`, `update`, `access` | Workflow trigger management |
| `slack datastore` | `put`, `get`, `delete`, `query`, `update`, `count`, `bulk-*` | App datastore CRUD operations |
| `slack env` | `add`, `list`, `remove` | Environment variables for deployed apps |
| `slack manifest` | `info`, `validate` | App manifest inspection and validation |
| `slack collaborator` | `add`, `list`, `remove` | Manage app collaborators |
| `slack external-auth` | `add`, `add-secret`, `remove`, `select-auth` | OAuth2 provider management |
| `slack function` | `access` | Control function access permissions |

## Global Flags

| Flag | Purpose |
|------|---------|
| `-a, --app <id>` | Target a specific app ID or environment |
| `-w, --team <name\|id>` | Select workspace or organization |
| `--token <token>` | Set access token for a team |
| `-f, --force` | Ignore warnings and continue |
| `-v, --verbose` | Print debug logging |
| `--no-color` | Remove styles from output |
| `-s, --skip-update` | Skip CLI update check |

## Project Lifecycle

### Create a new project

```bash
slack project create my-app
slack project create my-app -t slack-samples/deno-hello-world
slack project create agent my-agent-app
slack project create my-app -t org/monorepo --subdir apps/my-app
```

### Initialize existing project

```bash
slack project init
```

### List sample apps

```bash
slack project samples
```

## Local Development

### Start dev server

```bash
slack platform run
slack run
slack dev
```

Aliases: `slack run`, `slack dev`, `slack start-dev`

| Flag | Purpose |
|------|---------|
| `--activity-level <level>` | Log level: trace, debug, info, warn, error, fatal (default: info) |
| `--cleanup` | Uninstall local app after exiting |
| `--hide-triggers` | Skip trigger listing and creation prompts |
| `--no-activity` | Hide platform log activity |

### View activity logs

```bash
slack platform activity
```

## Deployment

### Deploy to Slack Platform

```bash
slack platform deploy
slack platform deploy --team T0123456
slack deploy
```

## Authentication

```bash
slack auth login
slack auth list
slack auth logout
slack auth revoke
slack auth token
```

Aliases: `slack login`, `slack logout`

## App Management

```bash
slack app install
slack app uninstall
slack app delete
slack app list
slack app link
slack app unlink
slack app settings
```

## Triggers

### Create

```bash
slack trigger create
slack trigger create --trigger-def "triggers/shortcut_trigger.ts"
slack trigger create --workflow "#/workflows/my_workflow"
```

| Flag | Purpose |
|------|---------|
| `--trigger-def <path>` | Path to JSON trigger definition file |
| `--workflow <ref>` | Workflow reference: `#/workflows/<callback_id>` |
| `--title <title>` | Trigger title (default: "My Trigger") |
| `--description <desc>` | Trigger description |
| `--interactivity` | Add interactivity parameter to trigger |

### Manage

```bash
slack trigger list
slack trigger info --trigger-id Ft123
slack trigger update --trigger-id Ft123 --trigger-def "triggers/updated.ts"
slack trigger delete --trigger-id Ft123
slack trigger access --trigger-id Ft123
```

## Datastores

### Single item operations

```bash
slack datastore put --datastore tasks '{"item": {"id": "42", "description": "Create a PR", "status": "Done"}}'
slack datastore get --datastore tasks '{"id": "42"}'
slack datastore update --datastore tasks '{"item": {"id": "42", "status": "Done"}}'
slack datastore delete --datastore tasks '{"id": "42"}'
slack datastore count --datastore tasks
```

### Bulk operations

```bash
slack datastore bulk-put --datastore tasks '{"items": [{"id": "12", "description": "Task A"}, {"id": "42", "description": "Task B"}]}'
slack datastore bulk-get --datastore tasks '{"ids": ["12", "42"]}'
slack datastore bulk-delete --datastore tasks '{"ids": ["12", "42"]}'
```

### Query

```bash
slack datastore query --datastore tasks '{"expression": "#status = :status", "expression_attributes": {"#status": "status"}, "expression_values": {":status": "In Progress"}}'
```

## Environment Variables

```bash
slack env add MAGIC_PASSWORD abracadabra
slack env list
slack env remove MAGIC_PASSWORD
```

Aliases: `slack var`, `slack vars`, `slack variable`, `slack variables`

## Manifest

```bash
slack manifest info
slack manifest info --source remote
slack manifest validate
```

## Collaborators

```bash
slack collaborator add
slack collaborator list
slack collaborator remove
```

## External Auth (OAuth2)

```bash
slack external-auth add
slack external-auth add-secret
slack external-auth remove
slack external-auth select-auth
```

## Diagnostics

```bash
slack doctor
slack version
slack upgrade
```

## Common Workflows

### New app from scratch

```bash
slack project create my-app
slack auth login
slack platform run
slack trigger create --trigger-def "triggers/my_trigger.ts"
slack platform deploy
```

### Deploy update

```bash
slack platform deploy --team T0123456
slack platform activity --team T0123456
```

### Debug issues

```bash
slack doctor
slack platform run --activity-level debug
slack platform activity
```
