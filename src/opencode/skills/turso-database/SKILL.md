---
name: turso-database
description: Works with the new Turso Database engine — the embedded, in-process SQLite rewrite driven by the `tursodb` CLI and the `@tursodatabase/database` / `pyturso` / `tursogo` / `turso` (Rust) SDKs. Use when launching the `tursodb` interactive shell, embedding a local/on-device/offline database in app code, enabling experimental features (views, triggers, custom types, encryption, vacuum, attach), using concurrent writes / MVCC (`BEGIN CONCURRENT`, `PRAGMA journal_mode='mvcc'`), at-rest encryption, vector search, CDC, or local-first `push`/`pull` sync. Triggers on "Turso Database", "tursodb", "@tursodatabase/database", "embedded turso", "turso MVCC", "turso concurrent writes", "turso encryption". Use ONLY for the embedded engine — for the managed cloud platform and the `turso` CLI (auth, db create, groups, branches, tokens) use turso-cloud; for the older libSQL client/server use that, not this.
---

# Turso Database (Embedded Engine)

## Overview

Turso Database is the next-generation, in-process database engine — a ground-up
Rust rewrite of SQLite, fully SQLite-compatible, with concurrent writes (MVCC),
async I/O, native vector search, at-rest encryption, and local-first sync. You
drive it through the `tursodb` binary (interactive shell + one-shot SQL) or by
embedding an SDK directly in application code. It runs anywhere: server,
desktop, mobile, browser, IoT — offline.

> **Turso Database vs Turso Cloud.** This skill is the **embedded engine**
> (`tursodb`, `@tursodatabase/database`). The hosted platform managed by the
> `turso` CLI (`turso auth`, `turso db create`, groups, branches, tokens) is a
> **different** product — use the `turso-cloud` skill for that. They connect via
> `@tursodatabase/sync` (this skill) push/pull to a cloud database.

## When to Use

- Running the `tursodb` interactive shell or one-shot SQL against a local file
- Embedding a local/on-device/offline DB via an SDK (`@tursodatabase/database`,
  `pyturso`, `tursogo`, `turso` crate)
- Enabling experimental features (views, triggers, custom types, encryption,
  index methods, vacuum, attach)
- Concurrent writes / MVCC, at-rest encryption, vector search, or CDC
- Local-first sync (`push()` / `pull()`) with `@tursodatabase/sync`

**Do NOT use when:**

- Managing the hosted platform — creating cloud databases, groups, branches, or
  tokens via the `turso` CLI → use `turso-cloud`.
- The project uses the older `@libsql/client` / `libsql` / `go-libsql` drivers
  (the libSQL fork that powers Turso Cloud today) → that is a different stack.
- Connecting to a remote DB over the wire from a server/edge runtime → use
  `@tursodatabase/serverless` (still note it here, but it is remote, not embedded).

## Install & Launch

Install the `tursodb` CLI (separate from the cloud `turso` CLI):

```bash
# macOS / Linux
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/tursodatabase/turso/releases/latest/download/turso_cli-installer.sh | sh
# Windows (PowerShell)
# irm https://github.com/tursodatabase/turso/releases/latest/download/turso_cli-installer.ps1 | iex
```

```bash
tursodb                       # transient in-memory shell (:memory:)
tursodb app.db                # open/create a persistent file
tursodb app.db "SELECT 1;"    # run SQL and exit
echo "SELECT 1+1;" | tursodb -q   # pipe SQL from stdin, no banner
```

## Core Workflow

### 1. Pick the interface

```
Need to inspect / prototype / script SQL at the terminal? ─→ tursodb CLI + dot-commands
Embedding in an application?                               ─→ SDK (table below)
Need local reads/writes + cloud sync?                      ─→ @tursodatabase/sync (push/pull)
Need remote-only access from a server/edge runtime?        ─→ @tursodatabase/serverless
```

### 2. SDK selection (new-project packages, built on this engine)

| Language | Local / embedded | + Cloud sync | Remote over-the-wire |
|----------|------------------|--------------|----------------------|
| TypeScript | `@tursodatabase/database` | `@tursodatabase/sync` | `@tursodatabase/serverless` |
| Python | `pyturso` (`import turso`) | `import turso.sync` | `libsql` |
| Go | `tursogo` | `tursogo` (sync) | `libsql-client-go` |
| Rust | `turso` crate | `turso` (`sync` feature) | `turso` (`remote` feature) |

Turso Database is a drop-in SQLite replacement — existing SQL, schema, and
queries work unchanged. TypeScript embedded example:

```ts
import { connect } from "@tursodatabase/database";

const db = await connect("app.db");
await db.prepare(
  `CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username TEXT NOT NULL)`
).run();
await db.prepare("INSERT INTO users (username) VALUES (?)").run("alice");
const users = await db.prepare("SELECT * FROM users").all();
```

### 3. Enable experimental features explicitly

Experimental features are **off by default** and must be turned on. Via the CLI,
pass `--experimental-<feature>`:

```bash
tursodb --experimental-views --experimental-triggers --experimental-vacuum app.db
```

| Feature | CLI flag / SDK feature string |
|---------|-------------------------------|
| Views (`CREATE VIEW`, materialized views) | `--experimental-views` / `views` |
| Triggers | `--experimental-triggers` / `triggers` |
| Custom types / domains (STRICT) | `--experimental-custom-types` / `custom_types` |
| At-rest encryption | `--experimental-encryption` / `encryption` |
| Index methods (FTS, sparse vector) | `--experimental-index-method` / `index_method` |
| Autovacuum / in-place VACUUM | `--experimental-autovacuum` / `--experimental-vacuum` |
| ATTACH / DETACH | `--experimental-attach` / `attach` |
| Multi-process WAL | `multiprocess_wal` |

SDKs take the same set as a builder/option (e.g. Rust
`Builder::new_local(path).experimental_triggers(true)`, Node
`new Database(path, { experimental: ["views","triggers"] })`, Python
`turso.connect(path, experimental_features="views,triggers")`).

### 4. Concurrent writes (MVCC)

Default config allows only one writer at a time. For multiple simultaneous
writers, enable MVCC and use `BEGIN CONCURRENT`:

```sql
PRAGMA journal_mode = 'mvcc';
BEGIN CONCURRENT;
  -- writes
COMMIT;
```

If two transactions touch the same rows, one gets a **conflict** error — the
application MUST detect it, `ROLLBACK`, and retry. Non-overlapping writes never
conflict. Treat "conflict"/"busy" errors as retryable in a loop.

### 5. At-rest encryption

```bash
KEY=$(openssl rand -hex 32)   # 32 bytes hex for a 256-bit cipher (16 for 128-bit)
tursodb --experimental-encryption "file:enc.db?cipher=aegis256&hexkey=$KEY"
```

- Default recommendation: `aegis256` (256-bit) or `aegis128l` (128-bit); AES
  variants `aes256gcm` / `aes128gcm` for NIST compliance; `aegisXXXxN` for
  hardware-parallel speed.
- Page-level AEAD; the DB file and WAL are encrypted (header's first 100 bytes
  are not). Keys live in memory only, **never on disk**.
- **Lose the key → lose the data.** Store it in a secret manager, never commit it.

### 6. Sync to Turso Cloud (local-first)

`@tursodatabase/sync` gives local reads/writes plus explicit `push()`/`pull()`.
You need a local path, a cloud `libsql://` URL, and an auth token (both obtained
with the `turso` CLI — see `turso-cloud`):

```ts
import { connect } from "@tursodatabase/sync";
const db = await connect({
  path: "./app.db",
  url: process.env.TURSO_DATABASE_URL,     // turso db show <db> --url
  authToken: process.env.TURSO_AUTH_TOKEN, // turso db tokens create <db>
});
await db.exec("INSERT INTO users (username) VALUES ('bob')");
await db.push();              // local → cloud
const changed = await db.pull(); // cloud → local
```

## Reference

**`tursodb [OPTIONS] [DATABASE] [SQL]`** — key options: `-m/--output-mode`
(`pretty`|`list`|`line`), `-o/--output <path>`, `-q/--quiet`, `-e/--echo`,
`-v/--vfs` (`syscall`|`memory`|`io_uring`), `-t/--tracing-output <path>`,
`--readonly`, `--mcp` (start an MCP server for AI clients), `--sync-server
<addr>`, `-V/--version`.

**Shell dot-commands** (no semicolon): `.help`, `.open <path> [vfs]`, `.tables`,
`.schema [table]`, `.indexes`, `.databases`, `.mode <pretty|list|line>`,
`.headers on|off`, `.timer on|off`, `.stats`, `.dump`, `.import [--csv] [--skip
N] <file> <table>`, `.clone <file>`, `.read <file>`, `.load <ext>`, `.manual
[page]`, `.quit`. Clone a DB by piping: `tursodb original.db ".dump" | tursodb -q clone.db`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It's SQLite-compatible, I'll just use a libSQL/SQLite driver." | The new engine ships its own packages (`@tursodatabase/database`, `pyturso`, `tursogo`, `turso` crate). libSQL drivers are a different stack — don't mix them up. |
| "I'll enable MVCC and writes just parallelize." | MVCC surfaces conflict errors on overlapping writes. Without retry-on-conflict the app loses writes. Always wrap `BEGIN CONCURRENT` in a retry loop. |
| "I'll turn on the experimental feature in prod." | Experimental features may change or have known limits — gate them to dev/testing, never critical data. |
| "I'll hardcode the encryption hexkey to test quickly." | Keys are never stored on disk by design; a committed key defeats encryption and is unrecoverable-by-design if lost. Use a secret manager. |
| "Embedded and cloud are the same Turso, one skill is fine." | They are distinct products with distinct CLIs/SDKs. Routing the wrong one wastes effort — use `turso-cloud` for the hosted platform. |

## Red Flags

- Reaching for `@libsql/client` / `libsql` / `go-libsql` when the task is the new
  embedded engine (or vice versa).
- `BEGIN CONCURRENT` without conflict detection and retry.
- Using an experimental feature without the corresponding `--experimental-*`
  flag / SDK option (it will error or silently no-op).
- Encryption key written to disk, source, or logs; opening an encrypted DB
  without the exact `cipher` + `hexkey`.
- Confusing the `tursodb` binary (this skill) with the `turso` CLI (cloud).

## Verification

- [ ] Correct interface chosen: `tursodb` shell vs an embedded SDK vs sync vs serverless.
- [ ] The package matches the engine (`@tursodatabase/*` / `pyturso` / `tursogo` / `turso` crate), not a libSQL driver, unless intentionally remote.
- [ ] Any experimental feature used is explicitly enabled via flag/option.
- [ ] Concurrent writes use `PRAGMA journal_mode='mvcc'` + `BEGIN CONCURRENT` with retry-on-conflict.
- [ ] Encryption uses a securely generated hexkey kept off disk; cipher + key documented for reopening.
- [ ] Sync code sources `url`/`authToken` from env/secret manager, not literals.
- [ ] SQL verified against the running DB (query returns expected rows / build passes).
