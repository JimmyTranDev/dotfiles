---
name: turso-database-management
description: Manages Turso (libSQL) cloud databases via the `turso` CLI. Use when creating, listing, inspecting, branching, importing/exporting, replicating, or destroying Turso databases; managing groups, organizations, or database/group/API tokens; opening a SQL shell; or running a local libSQL dev server. Triggers on "turso", "turso cli", "libsql database", "turso db shell", "turso dev", or any turso.io / libsql:// database URL.
---

# Turso Database Management

## Overview

`turso` is the official CLI for Turso, the libSQL/SQLite-based edge database cloud. It is the **single tool of record** for managing Turso accounts, organizations, groups, databases, branches, replicas, and tokens from the terminal, and for running a local libSQL dev server (`turso dev`). Route every Turso interaction through `turso` so behavior stays scriptable and consistent — never scrape `turso.tech` / `app.turso.tech` pages or guess at `libsql://` URLs for account or database data.

Reference docs: https://docs.turso.tech/reference/turso-cli

## When to Use

- Any time a Turso/libSQL resource is referenced — a `*.turso.io` host, a `libsql://` URL, a database, group, or org name.
- Creating, listing, inspecting, branching, importing/exporting, replicating, or destroying databases.
- Managing groups, organizations, members/invites, or database/group/API tokens.
- Opening an interactive SQL shell or running one-off SQL against a Turso database.
- Running a local libSQL server for offline development (`turso dev`).

**Do NOT use when:**

- The app uses a plain local SQLite file via a libSQL SDK with a `file:` URL — no server or CLI is needed at all.
- Inspecting a local Android app's on-device SQLite file — use `android-app-data`.
- You only need to browse a SQLite file's contents interactively — a SQLite browser is fine; use `turso db shell` only for *Turso-hosted* databases.

## Installation

Managed in this repo via `brew "tursodatabase/tap/turso"` in `src/Brewfile`.

```bash
brew install tursodatabase/tap/turso     # macOS / Linux / WSL
# or:
curl -sSfL https://get.tur.so/install.sh | bash
```

**Gotcha — Homebrew tap trust:** turso depends on `sqld` from the `libsql/sqld` tap. On modern Homebrew (tap-trust enabled), `brew install` silently stops at `==> Would install 1 formula: turso` because the dependency tap is untrusted. Fix:

```bash
brew tap libsql/sqld
brew trust --formula libsql/sqld/sqld
brew install tursodatabase/tap/turso
```

Upgrade with `brew upgrade turso` or `turso update`.

## Authentication

```bash
turso auth signup            # create a new account (browser, GitHub OAuth)
turso auth login             # log in (browser, GitHub OAuth)
turso auth whoami            # print current username
turso auth token             # print the API token for the current session
turso auth logout            # remove stored credentials
```

**You must `turso auth login` before any other command** — unauthenticated calls fail with a login prompt.

### API tokens (automation / CI)

Non-expiring, revocable tokens that authenticate as their creator. Use these for scripts and CI instead of the interactive session token.

```bash
turso auth api-tokens mint <name>     # create a token (printed once — store it)
turso auth api-tokens list            # list token names
turso auth api-tokens revoke <name>   # revoke a token
```

Provide a token to commands via the `TURSO_API_TOKEN` env var or `turso config set token`.

### Config location

Credentials and settings live in `settings.json` under the platform config dir (macOS: `$HOME/Library/Application Support/turso`; Linux: `$XDG_CONFIG_HOME` or `$HOME/.config/turso`). Override the directory per-invocation with the global `-c, --config-path <dir>` flag.

## Organizations

```bash
turso org list               # list orgs (marks the current one)
turso org switch <slug>      # set the org context for subsequent commands
turso org members            # manage members (list/add/rm)
turso org invites            # manage invites
turso org create <name>      # create an org
turso org destroy <name>     # DESTRUCTIVE: delete an org
```

`turso org switch` changes which org every later command targets — confirm you are in the right org before creating or destroying anything.

## Groups

A group is a set of locations that databases live in; databases inherit their group's locations.

```bash
turso group list                          # list groups, locations, version, status
turso group show <group>                  # details for one group
turso group create <group> [--location <id>] [--wait]
turso group locations                     # manage a group's replica locations
turso group destroy <group>               # DESTRUCTIVE: deletes the group + its DBs
turso group tokens create <group>         # group-wide DB token
```

## Databases

```bash
turso db list                             # list databases (name, type, group, URL)
turso db show <db>                        # full details (URL, ID, group, locations, instances)
turso db inspect <db>                     # usage: storage, rows read/written, syncs
turso db locations                        # list available location IDs (marks default)
```

### Create

```bash
turso db create [name] [flags]            # no name → a name is generated
```

| Flag | Purpose |
|------|---------|
| `--group <name>` | Create in a specific group |
| `--location <id>` | Primary location (default: closest) |
| `--from-file <path>` | Seed from a local SQLite3 file |
| `--from-dump <path>` | Seed from a local SQL dump |
| `--from-dump-url <url>` | Seed from a remote SQL dump |
| `--from-csv <path> --csv-table-name <t>` | Seed from a CSV |
| `--from-db <name> [--timestamp <RFC3339>]` | Copy another DB, optionally at a past point in time |
| `--size-limit <e.g. 256mb>` | Cap database size |
| `--type regular\|schema` | Database type (default `regular`) |
| `-w, --wait` | Block until ready |

### SQL shell & one-off queries

```bash
turso db shell <db>                       # interactive SQL shell (sqlite3-like)
turso db shell <db> "select * from users;"   # run a single statement, non-interactively
turso db shell <db> --location <id>       # target a specific replica location
turso db shell http://127.0.0.1:8080      # shell against a local `turso dev` server
```

Pipe SQL via stdin for scripts: `echo "select count(*) from t;" | turso db shell <db>`.

### Branch, replicate, tokens

```bash
turso db branch <source-db> <target-db> [--group <g>] [--timestamp <RFC3339>]
turso db replicate <db> <location-code> [--wait]      # add a replica in a location
turso db tokens create <db> [-r] [-e <never|7d>] [-p <perm>] [--group]
turso db tokens invalidate <db>                       # rotate keys (revokes all tokens)
```

`db tokens create` flags: `-r/--read-only`, `-e/--expiration` (`never` or e.g. `7d`), `-p/--permissions` (e.g. `-p all:data_read`), `--group` (valid for the whole group).

### Import / export

```bash
turso db import <file.db> [--group <g>]               # upload a local SQLite file as a new DB
turso db export <db> [--output-file <f>] [--overwrite] [--with-metadata]
```

`export` writes `<db>.db` plus `<db>.db-wal` (WAL frames) locally.

### Destroy

```bash
turso db destroy <db>                     # DESTRUCTIVE: permanently deletes the database
```

## Local dev server

```bash
turso dev                                 # in-memory libSQL server on http://127.0.0.1:8080
turso dev --db-file dev.db                # persist to a file
turso dev --port 9000                     # custom port
```

Point a libSQL SDK at the printed `http://127.0.0.1:<port>` URL for offline development. Many SDKs can use a `file:` URL directly and need no server.

## Config & plan

```bash
turso config path                         # path to the config file
turso config set token <token>            # set the token used by turso
turso config set autoupdate <on|off>      # autoupdate behavior
turso config cache                        # manage CLI cache
turso plan show                           # current org plan, usage, and limits
```

## Common Workflows

```bash
# Verify auth and see what you have access to
turso auth whoami && turso org list && turso db list

# Create a database in a group and open a shell
turso db create app-prod --group production --wait
turso db shell app-prod

# Seed a new database from an existing local SQLite file
turso db import ./local.db --group production

# Snapshot a production DB to inspect locally
turso db export app-prod --output-file backup.db --with-metadata

# Create a point-in-time branch for debugging
turso db branch app-prod app-debug --timestamp 2026-06-01T00:00:00Z

# Mint a read-only token (7-day expiry) for an analytics service
turso db tokens create app-prod --read-only --expiration 7d

# Check usage against plan limits
turso db inspect app-prod && turso plan show
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "`brew install` printed something, so turso is installed." | If output ended at `Would install 1 formula: turso`, it did **not** install. Trust the `libsql/sqld` tap and re-run. Verify with `turso --version`. |
| "I'll just run the command; login can wait." | Every non-auth command fails until `turso auth login`. Check `turso auth whoami` first. |
| "`turso db destroy` / `group destroy` / `org destroy` is fine to run." | These are irreversible deletions. Confirm the target name and the current org (`turso org list`) before running. |
| "I'll fetch the Turso dashboard URL to read the data." | Web pages return no machine-readable data. Use `turso db list/show/inspect` and `turso db shell`. |
| "I need a server for local libSQL development." | If your SDK supports `file:` URLs, point it at a local file — no `turso dev` needed. |

## Red Flags

- Running any `turso` command without first confirming `turso auth whoami`.
- Destroy/branch/import/export against a database without confirming the **current org** (`turso org list`).
- Treating a `brew install` that stopped at "Would install" as a successful install.
- Hardcoding a `libsql://...` URL or token in code/commits instead of minting a scoped `db tokens` / `api-tokens` value.
- Using `turso db shell` against a non-Turso/local SQLite file (use a SQLite browser or `android-app-data` instead).

## Verification

- [ ] `turso --version` prints a version (install succeeded).
- [ ] `turso auth whoami` prints the expected username (authenticated).
- [ ] For read tasks: the relevant `turso db list` / `db show` / `db inspect` output matches expectations.
- [ ] For mutations: the resource appears (`turso db list` / `group list`) or is gone (after destroy), confirmed by re-running the list command.
- [ ] Any token minted is stored securely and not committed to the repo.
