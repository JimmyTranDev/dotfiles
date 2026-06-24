---
name: turso-cloud
description: Manages the Turso Cloud managed database platform (libSQL-backed) from the terminal via the `turso` CLI and the Platform API. Use when authenticating (`turso auth signup/login`, `--headless`), creating/listing/showing/inspecting/importing/destroying cloud databases (`turso db ...`), managing groups, organizations, plans, and scoped database/group access tokens, branching a database (`turso db create --from-db`, point-in-time `--timestamp`), retrieving a database's `libsql://` URL and auth token for an app, or running a local libSQL dev server (`turso dev`). Triggers on "Turso Cloud", "turso CLI", "turso db create", "turso db shell", "turso group", "turso auth", "turso db tokens", "branch a Turso database", "libsql:// URL". Use ONLY for the hosted cloud platform and its `turso` CLI — for the embedded `tursodb` engine, MVCC, local encryption, or `@tursodatabase/*` SDKs use turso-database instead.
---

# Turso Cloud (Managed Platform)

## Overview

Turso Cloud is the fully managed, SQLite-compatible database platform built on
**libSQL**, with branching, point-in-time recovery, replication/sync, analytics,
scoped tokens, and team access. You operate it from the terminal with the
`turso` CLI (`auth`, `db`, `group`, `org`, `plan`, `dev`) or programmatically via
the Platform API at `https://api.turso.tech`.

> **Turso Cloud vs Turso Database.** This skill is the **hosted platform** and
> the `turso` CLI. The embedded, in-process engine (`tursodb`,
> `@tursodatabase/database`) is a **different** product — use `turso-database`
> for that. Note: Turso Cloud runs on libSQL today; the new engine is being
> integrated into Cloud later.

## When to Use

- Authenticating to Turso Cloud and managing API tokens
- Creating, listing, showing, inspecting, importing, or destroying cloud databases
- Managing groups (shared-location DB sets), organizations, plans, and members
- Creating scoped access tokens (read-only, expiring) for databases or groups
- Branching a database (copy-on-write / point-in-time) for dev, testing, or per-PR CI
- Fetching a database's `libsql://` URL + token to wire into an application
- Running a local libSQL server for development (`turso dev`)

**Do NOT use when:**

- Working with the embedded `tursodb` engine, its interactive shell, MVCC,
  experimental flags, or `@tursodatabase/*` SDKs → use `turso-database`.
- The only goal is writing application query code against libSQL → that is SDK
  work; this skill is platform/CLI management.

## Install & Authenticate

```bash
# Install (separate from the embedded `tursodb` CLI)
brew install tursodatabase/tap/turso        # macOS
curl -sSfL https://get.tur.so/install.sh | bash   # Linux / WSL

turso auth signup        # or: turso auth login   (opens browser via GitHub)
turso auth login --headless   # WSL / remote / CI — prints a URL to paste
turso auth whoami
```

The CLI requires **re-authentication weekly**. Tokens are secrets — never share
or commit them.

## Command Surface

| Command | Purpose |
|---------|---------|
| `turso auth` | `signup`, `login` (`--headless`), `logout`, `whoami`, `token`, `api-tokens` |
| `turso db` | Create & manage databases, tokens, and the shell (details below) |
| `turso group` | `create`, `list`, `update`, `destroy`, `tokens`, `locations`, `transfer` |
| `turso org` | `list`, `create`, `switch <slug>`, `destroy`, `members`, `billing` |
| `turso plan` | `show`, `select`, `upgrade`, `overages` |
| `turso dev` | Run a local libSQL server for development |
| `turso update` | Update the CLI |

Append `--help` to any command to see its flags.

## Core Workflow

### 1. Databases (`turso db`)

```bash
turso db create <name> [--group <g>]      # --group required if >1 group exists
turso db list [--group <g>]
turso db show <name> [--url] [--http-url]  # --url prints the libsql:// URL
turso db shell <name> ["SQL"]              # interactive shell or one-shot SQL
turso db inspect <name> [--queries] [--verbose]   # usage, rows read/written, top queries
turso db import ~/path/to/database.db [--group <g>]   # SQLite file must be WAL mode
turso db destroy <name> -y                 # DESTRUCTIVE — confirm before running
turso db wakeup <name>
```

Seed a new database from existing data with `turso db create` flags:
`--from-db <db>` (+ `--timestamp <RFC3339>` for point-in-time), `--from-file
<file.db>` (≤2GB), `--from-dump <dump.sql>`, `--from-dump-url <url>`,
`--from-csv <file.csv> --csv-table-name <t>`. Other flags: `--size-limit`,
`--enable-extensions`, `-w/--wait`.

Dump / restore via the shell:

```bash
turso db shell <name> .dump > dump.sql       # export
turso db shell <name> < dump.sql             # load into a database
turso db shell <name> "SELECT * FROM users"  # run a query
```

### 2. Connect an application

```bash
turso db show <name> --url            # → libsql://<name>-<org>.turso.io
turso db tokens create <name>         # → auth token (a secret)
```

Store both as env vars (`TURSO_DATABASE_URL`, `TURSO_AUTH_TOKEN`). The app uses a
libSQL driver (`@libsql/client`, `libsql`, `go-libsql`) or
`@tursodatabase/serverless`; for local-first push/pull sync, see `turso-database`
(`@tursodatabase/sync`).

### 3. Access tokens

```bash
turso db tokens create <name> --read-only        # read-only scope
turso db tokens create <name> --expiration 7d    # expiring (e.g. 7d, or `never`)
turso db tokens invalidate <name>                # rotate / revoke all tokens
turso group tokens create <group>                # one token for every DB in a group
```

Prefer least privilege: read-only and short expirations where possible. Rotate
(`invalidate`) if a token may have leaked.

### 4. Groups, organizations, plans

```bash
turso group create <group> --location <code> -w   # primary region; auto-detected if omitted
turso group list
turso org switch <org-slug>     # set the active org for subsequent commands
turso org list
turso plan show
```

Multiple groups require a Scaler/Pro/Enterprise plan. Commands act on the active
organization — `turso org switch` first when managing another org.

### 5. Branching (dev / testing / per-PR)

A branch is a separate database seeded from an existing one (optionally from a
point in time). Branches are fully independent — schema/data changes do not
propagate; merge manually with a migration tool.

```bash
turso db create my-branch --from-db my-prod-db
turso db create my-branch --from-db my-prod-db --timestamp 2024-01-01T10:10:10-10:00
turso db tokens create my-branch       # branch needs its own (or a group) token
turso db destroy my-branch -y          # delete when done — branches count to quota
```

Automate per-PR branches in CI with the Platform API
(`POST https://api.turso.tech/v1/organizations/{org}/databases` with a `seed` of
`{"type":"database","name":"<source>"}`).

### 6. Local development

```bash
turso dev                       # ephemeral local libSQL server (http://127.0.0.1:8080)
turso dev --db-file local.db    # persist changes to a file
```

Point the SDK's `url` at `http://127.0.0.1:8080`; no auth token needed locally.

## Safety

- `turso db destroy` and `turso group destroy` are **irreversible**. Confirm the
  exact target with the user before running; never pass `-y` speculatively.
- Tokens and `libsql://` URLs+tokens are credentials — keep them in a secret
  manager / env vars, never in source, logs, or chat.
- `--from-db ... --timestamp` and point-in-time recovery depend on the plan's
  retention window.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll add `-y` so `db destroy` doesn't prompt." | Destruction is irreversible and counts as a high-stakes action. Confirm the target first; the prompt is a safety net, not an annoyance. |
| "I'll paste the database token inline to test." | Tokens are credentials and the CLI reauths weekly for a reason. Use env vars / a secret manager and prefer read-only + short expiration. |
| "Branches sync back to prod automatically." | Branches are fully independent databases. Schema/data must be merged manually with a migration tool, and the branch deleted when done. |
| "This is the same as the embedded engine." | Turso Cloud is libSQL-backed and managed via `turso`; the embedded engine is `tursodb`/`@tursodatabase/database`. Use `turso-database` for that. |
| "One group is enough, I'll skip `--group`." | With multiple groups the CLI requires `--group`; omitting it errors or targets the wrong group. |

## Red Flags

- Running `db destroy` / `group destroy` without confirming the exact name, or
  scripting `-y` non-interactively against production.
- Embedding `libsql://` URLs or tokens in source, logs, or committed files.
- Creating long-lived, full-access tokens when read-only / expiring would do.
- Leaving branch databases around after a PR merges (quota + cost).
- Reaching for `tursodb` / `@tursodatabase/database` here — that is `turso-database`.

## Verification

- [ ] Authenticated (`turso auth whoami` succeeds) and the active org is correct (`turso org switch`).
- [ ] Database operations target the intended name and group (verified with `turso db list` / `turso db show`).
- [ ] App credentials retrieved via `turso db show --url` + `turso db tokens create` and stored in env/secret manager, not literals.
- [ ] Tokens follow least privilege (read-only / expiring) and any leaked token was `invalidate`d.
- [ ] Branches created with `--from-db` are tracked and destroyed when no longer needed.
- [ ] Any destructive command (`db destroy`, `group destroy`) was confirmed with the user before running.
