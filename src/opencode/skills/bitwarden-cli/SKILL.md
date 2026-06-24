---
name: bitwarden-cli
description: Manages a Bitwarden password vault from the terminal via the `bw` CLI. Use when logging in or unlocking a vault, reading or generating passwords/usernames/TOTP codes, creating/editing/listing/deleting vault items, folders, collections, or organization members, sending or receiving Bitwarden Send, exporting/importing vault data, configuring a self-hosted/EU server, or serving the vault over a local REST API. Triggers on "bitwarden", "bw cli", "bw login", "bw unlock", "bw get password", "BW_SESSION", "vault item", "bitwarden send", "bw generate", or an `@bitwarden/cli` reference. Use ONLY for the Bitwarden Password Manager CLI (`bw`), not the Secrets Manager CLI (`bws`).
---

# Bitwarden CLI

## Overview

`bw` is the Bitwarden Password Manager CLI — the canonical way to read and manage a Bitwarden vault from the terminal. It is self-documenting (`bw --help`, `bw <command> --help`) and exposes most features found in the desktop and browser clients.

This is a **password vault**. Treat master passwords, session keys, and retrieved secrets as sensitive: never echo them to logs, never paste a session key into a committed file, and prefer environment/file inputs over inline credentials. See [Security Practices](#security-practices).

Install (this macOS/Homebrew environment): `brew install bitwarden-cli`. Cross-platform and the official recommendation (required for arm64): `npm install -g @bitwarden/cli`.

## When to Use

- Authenticating to a vault (`bw login`, `bw unlock`) or ending a session (`bw lock`, `bw logout`)
- Reading secrets: `bw get password|username|totp|uri|notes|item <search>`
- Generating passwords/passphrases: `bw generate`
- Creating, editing, listing, or deleting vault items, folders, or collections
- Organization tasks: list members/collections, `move` an item to an org, `confirm` a member, device approval
- Bitwarden Send: `bw send` / `bw receive`
- Vault data lifecycle: `bw export`, `bw import`, `bw sync`, `bw status`
- Connecting to a self-hosted or EU server: `bw config server <url>`
- Exposing the vault over a local REST API: `bw serve`

**Do NOT use when:**

- Working with the Bitwarden **Secrets Manager** (developer secrets, projects, machine accounts) — that is a separate `bws` CLI, not `bw`.
- You only need to know *whether* the CLI is installed/authenticated — run `bw status` instead of triggering a full interactive login.

## The Auth Model: login vs unlock (read this first)

Bitwarden separates **authentication** (proving who you are) from **decryption** (unlocking vault data). This distinction trips up most automation.

| Step | Command | What it does |
|------|---------|--------------|
| Log in | `bw login` | Authenticates your identity with the server |
| Unlock | `bw unlock` | Derives a **session key** that decrypts vault data |

- `bw login` with **email + master password** authenticates AND unlocks in one step (returns a session key).
- `bw login --apikey` or `bw login --sso` **only authenticate** — you MUST then run `bw unlock` to obtain a session key before touching vault data.
- Commands needing NO decrypted data work without unlocking: `config`, `encode`, `generate`, `update`, `status`.
- Everything that reads/writes vault data (`get`, `list`, `create`, `edit`, `delete`, `move`, `export`, ...) requires an active session key.
- Members of an organization using [trusted devices](https://bitwarden.com/help/about-trusted-devices/) (no master password) cannot decrypt data via the CLI.

### Log in

```bash
bw login                       # interactive: email, master password, 2FA — recommended for humans
bw login --apikey              # prompts for client_id/client_secret — recommended for automation
bw login --sso                 # browser SSO flow, then `bw unlock`
bw login [email] [password] --method <method> --code <code>   # one-shot 2FA (discouraged; see Enums for <method>)
```

2FA methods supported by the CLI: Authenticator, Email, YubiKey. **FIDO2 and Duo are not supported** — use `--apikey` instead. If you hit `Your authentication request appears to be coming from a bot.`, answer with your API key `client_secret`.

### Unlock and the session key

```bash
bw unlock                              # prompts for master password, returns a session key
bw unlock --passwordenv BW_PASSWORD    # read master password from env var (automation)
bw unlock --passwordfile ./mp.txt      # read master password from file (first line)
```

Unlocking prints an `export BW_SESSION="..."` line. Every command touching vault data needs that key, supplied either way:

```bash
export BW_SESSION="5PBYGU+5yt3RHcCjoeJKx/wByU34vokGRZjXpSH7Ylo8w=="
bw list items
# or per-command:
bw list items --session "5PBYGU+5yt3RHcCjoeJKx/wByU34vokGRZjXpSH7Ylo8w=="
```

- Session keys are invalidated by `bw lock` or `bw logout`, and do **not** persist into a new terminal window — re-unlock each shell.
- **Always end with `bw lock` (or `bw logout`)** when finished.

## Automation & Environment Variables

| Variable | Purpose |
|----------|---------|
| `BW_CLIENTID` / `BW_CLIENTSECRET` | API-key credentials for `bw login --apikey` without prompts |
| `BW_PASSWORD` | Master password source for `bw unlock --passwordenv BW_PASSWORD` |
| `BW_SESSION` | Active session key used by all vault-data commands |
| `BITWARDENCLI_APPDATA_DIR` | Path to a `data.json` config dir — point at separate dirs to log in to multiple accounts |
| `BITWARDENCLI_DEBUG` | `true` for extra troubleshooting output |
| `NODE_EXTRA_CA_CERTS` | Absolute path to a `.pem` for a self-hosted server's self-signed cert |

Non-interactive scripting pattern:

```bash
export BW_CLIENTID="..." BW_CLIENTSECRET="..."
bw login --apikey --nointeraction
export BW_SESSION="$(bw unlock --passwordenv BW_PASSWORD --raw)"
bw get password "Production DB" --raw
bw lock
```

`--raw` returns the bare value (no descriptive message); `--nointeraction` never prompts. Combine them for clean piping.

## Core Commands

### get — retrieve ONE object

```bash
bw get (item|username|password|uri|totp|exposed|notes|attachment|folder|collection|organization|org-collection|template|fingerprint) <id-or-search> [options]
```

- Accepts an exact `id` OR a search string (e.g. `bw get password Github`).
- **Returns only one result** — if a search matches multiple items the CLI errors. Use specific terms or an exact `id`.
- `bw get totp <id>` returns the current TOTP code; `bw get exposed <id>` checks breach exposure.
- `bw get attachment <filename> --itemid <id> [--output <dir/>]` downloads a file (output path must end in `/` for a directory).
- `bw get fingerprint me` prints your own fingerprint phrase.

### list — retrieve an array

```bash
bw list (items|folders|collections|organizations|org-collections|org-members) [options]
```

Filters: `--url <url>`, `--folderid <id>`, `--collectionid <id>`, `--organizationid <id>`, `--trash`. Any filter accepts `null` or `notnull`. **Multiple filters = OR.** Add `--search <term>`; combining search with a filter = AND.

```bash
bw list items --folderid null --collectionid null          # items in no folder OR collection
bw list items --search github --folderid <id>              # search within a folder (AND)
```

### create / edit — the JSON pipeline

`create` and `edit` take **Base64-encoded JSON**. The canonical workflow is `get template → jq → encode → create/edit`:

```bash
# create a folder
bw get template folder | jq '.name="My First Folder"' | bw encode | bw create folder

# create a login item (item.login is a sub-template)
bw get template item | jq ".name=\"My Login\" | .login=$(bw get template item.login | jq '.username="jdoe" | .password="p@ss"')" | bw encode | bw create item

# edit: get the object, modify, re-encode, edit by exact id (edit performs a REPLACE)
bw get item <id> | jq '.login.password="newp@ss"' | bw encode | bw edit item <id>
```

- `create (item|attachment|folder|org-collection)`; `edit (item|item-collections|folder|org-collection)`.
- `bw create attachment --file ./f --itemid <id>` skips jq/encode (uses flags directly).
- Set `.type` in the item JSON to create other types (see [Enums](#enums)); secure notes also need `.secureNote.type = 0`.

### delete / restore

```bash
bw delete (item|attachment|folder|org-collection) <id> [options]
bw delete item <id> --permanent          # -p: irreversible, skips Trash
bw restore item <id>                      # recover from Trash (within 30 days)
```

By default `delete` sends an item to Trash (recoverable 30 days). `--permanent` is **irrecoverable**. Deleting an `org-collection` also needs `--organizationid <id>`.

## Generate

```bash
bw generate                                   # default: 14-char password, upper+lower+number
bw generate -uln --length 14                  # explicit equivalent
bw generate -ulns --length 20                 # add special chars
bw generate --passphrase --words 4 --separator - --capitalize --includeNumber
```

Flags: `-u/--uppercase`, `-l/--lowercase`, `-n/--number`, `-s/--special`, `--length <n>` (min 5); passphrase: `--passphrase`, `--words <n>`, `--separator <c>`, `-c/--capitalize`, `--includeNumber`. No login/unlock required.

## Bitwarden Send

```bash
bw send -n "My Send" -d 7 --hidden "secret text"        # text send, expires in 7 days
bw send -n "A File" -d 14 -f ./sensitive.pdf            # file send
bw receive --password <pw> https://vault.bitwarden.com/#/send/<id>/<key>
```

`send` is highly flexible (templates, max access, deletion dates) — for advanced usage consult `bw send --help` and the Send-from-CLI docs.

## Organizations

```bash
bw list organizations
bw list org-members      --organizationid <orgid>
bw list org-collections  --organizationid <orgid>
bw move <itemid> <orgid> < encoded-collection-id-array   # transfer an item to an org (encode a [collectionId] array first)
bw confirm org-member <memberid> --organizationid <orgid>
```

`move` requires an encoded JSON array of collection IDs:

```bash
echo '["<collectionId>"]' | bw encode | bw move <itemid> <orgid>
```

Before `confirm`, verify the member's fingerprint phrase (`bw get fingerprint <userId>`) matches what the user reports — confirmation grants decryption access.

### Device approval (admins/owners)

```bash
bw device-approval list        --organizationid <orgid>
bw device-approval approve     --organizationid <orgid> <requestId>
bw device-approval approve-all --organizationid <orgid>
bw device-approval deny        --organizationid <orgid> <requestId>
bw device-approval deny-all    --organizationid <orgid>
```

Bulk approval skips per-request fingerprint verification — prefer self-approval and review IdP controls before enabling it.

## Other Commands

```bash
bw config server <url>            # set server BEFORE login (self-hosted or EU)
bw config server https://vault.bitwarden.eu
bw config server                  # print current server
bw sync [--last]                  # pull vault from server (--last = timestamp only); writes auto-push
bw status                         # JSON: serverUrl, lastSync, userEmail, userId, status
bw encode                         # Base64-encode stdin (for create/edit pipelines)
bw import <format> <path>         # `bw import --formats` lists supported formats
bw import --organizationid <id> bitwardencsv ./source.csv
bw export [--output <path>] [--format csv|json|encrypted_json|zip] [--password <pw>] [--organizationid <id>] [--raw]
bw generate ...                   # see Generate
bw update                         # checks for a newer CLI; does NOT self-update
bw serve --port 8087 --hostname localhost   # local REST API over the vault
bw completion --shell zsh         # shell completion script
```

- `bw status` returns `"status"` as `unlocked` (session key active), `locked` (logged in, no session), or `unauthenticated` (not logged in).
- `bw config server` overwrites ALL prior URL settings each run — set every endpoint in one command if customizing individually.
- `bw serve` blocks cross-origin requests by default; `--hostname all` exposes it to the network (avoid). Pairs with the Vault Management API.

ZSH completion (add to `.zshrc`):

```bash
eval "$(bw completion --shell zsh); compdef _bw bw;"
```

## Global Options

| Option | Effect |
|--------|--------|
| `--pretty` | Tab-indent JSON output (2 spaces) |
| `--raw` | Bare output value, no descriptive message |
| `--response` | JSON-formatted response wrapper |
| `--quiet` | Suppress stdout (e.g. when piping a credential to a file) |
| `--nointeraction` | Never prompt for input (required for automation) |
| `--session <key>` | Pass the session key inline instead of via `BW_SESSION` |
| `-v, --version` | Print CLI version |
| `-h, --help` | Help for any command (`bw <command> --help`) |

## Enums

| Domain | Values |
|--------|--------|
| 2FA `--method` | Authenticator `0`, Email `1`, YubiKey `3` (FIDO2/Duo unsupported) |
| Item `.type` | Login `1`, Secure Note `2`, Card `3`, Identity `4`, SSH Key `5` |
| URI match | Domain `0`, Host `1`, Starts With `2`, Exact `3`, Regex `4`, Never `5` |
| Field `.type` | Text `0`, Hidden `1`, Boolean `2` |
| Org user type | Owner `0`, Admin `1`, User `2`, Manager `3`, Custom `4` |
| Org user status | Invited `0`, Accepted `1`, Confirmed `2`, Revoked `-1` |

## Security Practices

- **Never print or log master passwords or session keys.** Avoid `echo "$BW_SESSION"`; capture into a variable directly (`export BW_SESSION="$(bw unlock --raw ...)"`).
- Prefer `--passwordenv` / `--passwordfile` over inline `bw login [email] [password]` or `bw unlock <password>` — inline credentials leak into shell history and process listings.
- If using `--passwordfile`, restrict it to the running user with read-only perms (`chmod 600`).
- Retrieve a single credential with `bw get password <name> --raw` rather than dumping the whole item; pipe to the consumer, don't write secrets to disk.
- Never commit `BW_SESSION`, `BW_CLIENTSECRET`, exported vault files (`.json`/`.csv`/`.zip`), or `data.json` to a repo.
- Always `bw lock` / `bw logout` at the end of a session, especially in shared or CI environments.

## Common Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I logged in with `--apikey`, so I can read items now." | API-key login only authenticates. You still need `bw unlock` to get a session key before any vault-data command. |
| "I'll just `echo` the session key to check it." | Echoing a session key leaks a live decryption key into history/logs. Capture it into `BW_SESSION` without printing. |
| "`bw get password foo` returned nothing useful, I'll loop results." | `get` returns exactly one match or errors. Narrow the search term or use an exact `id`; use `bw list` for multiples. |
| "`delete` is fine, it's recoverable." | Only without `--permanent`. `delete --permanent` is irreversible — confirm intent before using it. |
| "I edited the item JSON in place." | `create`/`edit` need Base64 JSON via `bw encode`, and `edit` REPLACES the whole object. Use the `get → jq → encode → edit` pipeline. |
| "I changed something in the web vault; the CLI already knows." | The CLI caches. Run `bw sync` to pull remote changes (writes auto-push, reads do not auto-pull). |
| "I'll inline the master password to skip the prompt." | Inline passwords leak. Use `--passwordenv`/`--passwordfile`, or `--apikey` env vars. |

## Red Flags

- Running `get`/`list`/`edit` and getting `You are not logged in.` / `Vault is locked.` → you skipped `bw login` or `bw unlock`, or `BW_SESSION` isn't set in this shell.
- A session key, `client_secret`, or exported vault file appearing in command output, history, or a diff.
- Using `bw` for "secrets manager", "projects", or "machine accounts" — that's the separate `bws` CLI.
- `bw config server` run AFTER `bw login` and wondering why auth points at the wrong server — set the server first.
- Piping to `create`/`edit` without `bw encode` (raw JSON is rejected).

## Verification

- [ ] `bw status` shows the expected `serverUrl` and `"status": "unlocked"` before running vault-data commands.
- [ ] Vault-data commands run with `BW_SESSION` exported (or `--session` passed) and return data, not an auth error.
- [ ] `create`/`edit` operations went through `bw encode` and the returned JSON reflects the change.
- [ ] No master password, session key, or `client_secret` was echoed, logged, or committed.
- [ ] Session ended with `bw lock` or `bw logout` when finished.
