---
name: tool-posthog-cli
description: PostHog CLI (posthog-cli) command reference for authentication, SQL queries, sourcemap uploads, and experimental endpoint/task management
---

## Overview

The `posthog-cli` command is the PostHog CLI. Install via `npm install -g @posthog/cli`.

- Use `posthog-cli login` for interactive auth, or environment variables for CI/CD
- All commands accept `--host <HOST>` to target a specific PostHog instance (default: `https://us.posthog.com`)

## Authentication

### Interactive Login

```bash
posthog-cli login
posthog-cli login --host https://eu.posthog.com
```

### Environment Variables (CI/CD)

| Variable | Description |
|----------|-------------|
| `POSTHOG_CLI_HOST` | PostHog host (default: `https://us.posthog.com`) |
| `POSTHOG_CLI_API_KEY` | Personal API key (also accepts `POSTHOG_CLI_TOKEN`) |
| `POSTHOG_CLI_PROJECT_ID` | Project/environment ID number (also accepts `POSTHOG_CLI_ENV_ID`) |

### API Key Scopes

| Command | Required Scopes |
|---------|-----------------|
| `query` | `query:read` |
| `sourcemap` | `error_tracking:write` |
| `exp endpoints list/get/pull` | `endpoint:read` |
| `exp endpoints push` | `endpoint:write`, `insight_variable:write` |
| `exp endpoints run` | `query:read` |
| `exp tasks` | `task:read` |

## Commands

### posthog-cli query

Run SQL queries against PostHog data.

```bash
posthog-cli query "SELECT count() FROM events WHERE timestamp > now() - INTERVAL 1 DAY"
posthog-cli query "SELECT properties.$browser, count() FROM events GROUP BY 1 ORDER BY 2 DESC LIMIT 10"
```

### posthog-cli sourcemap

Upload bundled source maps to PostHog for error tracking.

```bash
posthog-cli sourcemap ./dist
posthog-cli sourcemap ./build --host https://eu.posthog.com
```

### posthog-cli exp

Experimental commands (subject to change).

#### Endpoints

```bash
posthog-cli exp endpoints list
posthog-cli exp endpoints get <endpoint>
posthog-cli exp endpoints pull
posthog-cli exp endpoints push
posthog-cli exp endpoints run <endpoint>
```

#### Tasks

```bash
posthog-cli exp tasks
```

## Global Options

| Flag | Description |
|------|-------------|
| `--host <HOST>` | PostHog host to connect to (default: `https://us.posthog.com`) |
| `-h, --help` | Print help |
| `-V, --version` | Print version |

## Common Workflows

```bash
posthog-cli login

posthog-cli query "SELECT count() FROM events WHERE timestamp > now() - INTERVAL 7 DAY"

posthog-cli sourcemap ./dist
```

### CI/CD Sourcemap Upload

```bash
export POSTHOG_CLI_API_KEY="phx_..."
export POSTHOG_CLI_PROJECT_ID="12345"
posthog-cli sourcemap ./dist
```
