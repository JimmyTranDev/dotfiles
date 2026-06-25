---
name: opencode-cli
description: Operates the `opencode` CLI from the terminal, grounded in the official CLI docs. Use when running non-interactive prompts (`opencode run`, `--format json` for scripting/automation), starting or attaching to a headless server (`opencode serve`/`web`/`attach`, `run --attach`), or managing auth, agents, MCP, models, sessions (`stats`, `export`/`import`), plugins, `pr`, `db`, and `upgrade`/`uninstall` — and when choosing global flags (`--model`, `--agent`, `--dangerously-skip-permissions`, `--log-level`) or `OPENCODE_*` env vars. Triggers on "opencode CLI", "opencode run", "opencode serve", "opencode auth login", "opencode agent create", "opencode mcp add", "headless opencode server". Use ONLY for operating the `opencode` binary — to edit opencode config/agents/skills/plugins content use customize-opencode, skill-authoring, or local-skill-index.
---

# OpenCode CLI

## Overview

`opencode` is the OpenCode CLI. Run with no arguments it launches the [TUI](https://opencode.ai/docs/tui); with a subcommand it drives OpenCode programmatically — ideal for scripting, automation, CI, and headless or remote use. It is self-documenting: `opencode --help` and `opencode <command> --help`.

This skill operates the **`opencode` binary**. It does NOT author opencode configuration — to edit `opencode.json`, agents, skills, plugins, MCP, or permission rules, use `customize-opencode`, `skill-authoring`, or `local-skill-index`. Commands that *scaffold* config (`opencode agent create`, `opencode mcp add`, `opencode plugin`) are invoked here, but the *content* decisions belong to those skills.

Source of truth: https://opencode.ai/docs/cli/ — confirm flags with `--help`, since the CLI evolves.

## When to Use

- Running a one-shot, non-interactive prompt: `opencode run "..."` (scripting, automation, quick answers).
- Machine-readable output for pipelines: `opencode run --format json`.
- Standing up a headless backend and attaching to it: `opencode serve` / `web` / `attach`, or `run --attach`.
- Managing provider credentials: `opencode auth login|list|logout`.
- Creating or listing agents: `opencode agent create|list`.
- Managing MCP servers: `opencode mcp add|list|auth|logout|debug`.
- Listing models: `opencode models [provider]`.
- Session lifecycle and reporting: `opencode session list|delete`, `opencode stats`, `opencode export`, `opencode import`.
- Installing a plugin, checking out a PR, querying the local DB, or upgrading: `opencode plugin|pr|db|upgrade`.

**Do NOT use when:**

- Editing opencode *config content* (`opencode.json`, agents, skills, plugins, permissions) — use `customize-opencode` / `skill-authoring` / `local-skill-index`.
- Working inside the running TUI (keybinds, in-app commands) — that is the TUI, not the CLI.
- You only need OpenCode's HTTP API surface — see the [server docs](https://opencode.ai/docs/server); this skill covers the CLI that starts it.

## Self-Documenting First

Before guessing a flag, ask the binary:

```bash
opencode --help                 # global help + command list
opencode <command> --help       # flags for a specific command
opencode --version              # -v
```

The reference below mirrors the CLI docs, but `--help` is authoritative for your installed version.

## Non-Interactive: `opencode run` (most common for agents)

```bash
opencode run "Explain how closures work in JavaScript"
opencode run Explain the use of context in Go      # message is variadic; quotes are safer
```

| Flag | Short | Purpose |
|------|-------|---------|
| `--command` | | Run a configured command; pass the message as its args |
| `--continue` | `-c` | Continue the last session |
| `--session` | `-s` | Continue a specific session ID |
| `--fork` | | Fork the session when continuing |
| `--share` | | Share the session |
| `--model` | `-m` | `provider/model` |
| `--agent` | | Agent to use |
| `--file` | `-f` | Attach file(s) to the message |
| `--format` | | `default` (formatted) or `json` (raw JSON events) |
| `--title` | | Session title (truncated prompt if omitted) |
| `--attach` | | Attach to a running server, e.g. `http://localhost:4096` |
| `--password` / `--username` | `-p` / `-u` | Basic auth for an attached server |
| `--dir` | | Working directory (or remote path when attaching) |
| `--port` | | Port for the local server (random by default) |
| `--variant` | | Model variant (provider-specific reasoning effort) |
| `--thinking` | | Show thinking blocks |
| `--dangerously-skip-permissions` | | Auto-approve permissions not explicitly denied — **dangerous** |

Warm-server pattern — attach to skip MCP cold-boot on every run:

```bash
opencode serve                                                                  # terminal 1 (headless)
opencode run --attach http://localhost:4096 "Explain async/await in JavaScript" # terminal 2
```

Use `--format json` to emit raw JSON events for parsing in scripts/CI.

## Headless Server Model: `serve` / `web` / `attach`

```bash
opencode serve --port 4096                           # HTTP API only, localhost (see /docs/server)
opencode web   --port 4096                           # HTTP API + opens a web UI, localhost

# Remote access: bind all interfaces — REQUIRE auth, only on trusted networks
OPENCODE_SERVER_PASSWORD=secret opencode web --port 4096 --hostname 0.0.0.0
opencode attach http://10.20.30.40:4096              # point a TUI at the running backend
```

- Shared server flags: `--port`, `--hostname`, `--mdns`, `--mdns-domain`, `--cors`.
- Set `OPENCODE_SERVER_PASSWORD` to enable HTTP basic auth (username defaults to `opencode`; override with `OPENCODE_SERVER_USERNAME`).
- `attach` flags: `--dir`, `--continue`/`-c`, `--session`/`-s`, `--fork`, `--password`/`-p`, `--username`/`-u`.
- **Network exposure:** `--hostname 0.0.0.0` (or `all`) exposes the server beyond localhost — only with auth enabled, on trusted networks. See [Destructive & Security-Sensitive Commands](#destructive--security-sensitive-commands).
- **mDNS exposure:** `--mdns` *without* an explicit `--hostname` defaults the bind address to `0.0.0.0` — so `opencode serve --mdns` silently exposes the server to the LAN. Treat `--mdns` like `--hostname 0.0.0.0`: require `OPENCODE_SERVER_PASSWORD`, or pin `--hostname 127.0.0.1`.

## Command Reference

### agent — manage agents

```bash
opencode agent create        # interactive wizard (system prompt + permissions)
opencode agent list          # list available agents
```

`create` flags: `--path`, `--description`, `--mode` (`all`|`primary`|`subagent`), `--permissions`/`--tools` (comma list from `bash,read,edit,glob,grep,webfetch,task,todowrite,websearch,lsp,skill` — anything omitted is denied), `--model`/`-m`. Passing all of `--path`, `--description`, `--mode`, and `--permissions` runs it non-interactively. For the agent's prompt/permission *design*, defer to `customize-opencode`.

### auth — provider credentials

```bash
opencode auth login          # configure an API key (stored in ~/.local/share/opencode/auth.json)
opencode auth list           # alias: ls
opencode auth logout         # remove a provider's credentials
```

`login` flags: `--provider`/`-p`, `--method`/`-m` (skip the selection menus).

> `providers` is the canonical name for this command; `auth` is an alias (`opencode providers login` ≡ `opencode auth login`). The docs and this skill use `auth`.

### mcp — Model Context Protocol servers

```bash
opencode mcp add             # guided add (local or remote)
opencode mcp list            # alias: ls — shows connection status
opencode mcp auth [name]     # OAuth login; `mcp auth list`/`ls` shows OAuth status
opencode mcp logout [name]   # remove OAuth credentials
opencode mcp debug <name>    # debug OAuth connection issues
```

For MCP *config content*, defer to `customize-opencode`.

### models — list available models

```bash
opencode models              # all models as provider/model
opencode models anthropic    # filter by provider
opencode models --refresh    # refresh the cache from models.dev
opencode models --verbose    # include metadata (e.g. costs)
```

### session — manage sessions

```bash
opencode session list                 # flags: --max-count/-n, --format table|json
opencode session delete <sessionID>   # destructive — permanently removes a session
```

### stats — usage & cost

```bash
opencode stats               # flags: --days N, --tools N, --models [N], --project [name]
```

### export / import — session data

```bash
opencode export [sessionID] [--sanitize]      # JSON to stdout; --sanitize redacts sensitive data
opencode import <file>                        # from a local file...
opencode import https://opncd.ai/s/abc123     # ...or an OpenCode share URL
```

### github — repository automation agent

```bash
opencode github install      # set up the GitHub Actions workflow
opencode github run          # run the agent (usually in CI); flags: --event, --token
```

### plugin / pr / db / debug

```bash
opencode plugin <module>     # alias: plug; flags: --global/-g, --force/-f
opencode pr <number>         # fetch & checkout a GitHub PR branch, then run opencode
opencode db [query]          # query the local DB; --format json|tsv
opencode db path             # print the DB path
opencode debug [command]     # debugging / troubleshooting tools
```

### acp — Agent Client Protocol server

```bash
opencode acp                 # nd-JSON over stdin/stdout; flags: --cwd, --port, --hostname, --mdns, --mdns-domain, --cors
```

### upgrade / uninstall

```bash
opencode upgrade             # latest version
opencode upgrade v0.1.48     # specific version; flag --method/-m curl|npm|pnpm|bun|brew
opencode uninstall           # removes OpenCode and related files
```

`uninstall` flags: `--keep-config`/`-c`, `--keep-data`/`-d`, `--dry-run`, `--force`/`-f`. Run `--dry-run` first.

### completion — shell completion

```bash
opencode completion          # print a shell completion script to stdout
```

Source it (or append to your shell rc, e.g. `opencode completion >> ~/.zshrc`) for tab-completion of commands and flags.

> **Internal/undocumented commands:** the binary also registers `opencode console` (hosted-account login — hidden from `--help`) and `opencode generate` (dumps the server's OpenAPI spec; a codegen/dev tool). Neither is part of normal CLI use or the official docs — use `opencode auth` for provider credentials.

## TUI Launch Flags

`opencode [project]` starts the TUI. Useful flags: `--continue`/`-c`, `--session`/`-s`, `--fork`, `--prompt`, `--model`/`-m`, `--agent`, `--port`, `--hostname`, `--mdns`, `--mdns-domain`, `--cors`.

## Global Flags

| Flag | Short | Effect |
|------|-------|--------|
| `--help` | `-h` | Help for the CLI or any command |
| `--version` | `-v` | Print the version number |
| `--print-logs` | | Print logs to stderr |
| `--log-level` | | `DEBUG`, `INFO`, `WARN`, `ERROR` |
| `--pure` | | Run without external plugins |

## Environment Variables

Common variables (the docs list the full set, plus `OPENCODE_EXPERIMENTAL*` toggles):

| Variable | Purpose |
|----------|---------|
| `OPENCODE_CONFIG` | Path to a config file |
| `OPENCODE_CONFIG_DIR` | Config directory |
| `OPENCODE_CONFIG_CONTENT` | Inline JSON config content |
| `OPENCODE_PERMISSION` | Inline JSON permissions config |
| `OPENCODE_SERVER_PASSWORD` | Enable basic auth for `serve`/`web` |
| `OPENCODE_SERVER_USERNAME` | Override the basic-auth username (default `opencode`) |
| `OPENCODE_AUTO_SHARE` | Automatically share sessions |
| `OPENCODE_DISABLE_AUTOUPDATE` | Disable automatic update checks |
| `OPENCODE_DISABLE_AUTOCOMPACT` | Disable automatic context compaction |

`OPENCODE_EXPERIMENTAL*` flags are experimental and may change or be removed — do not depend on them in stable automation.

## Destructive & Security-Sensitive Commands

Confirm intent with the user before running these:

| Command / flag | Why |
|----------------|-----|
| `opencode uninstall` | Removes OpenCode and related files. Run `--dry-run` first; consider `--keep-config`/`--keep-data`. |
| `opencode session delete` | Permanently removes a session. |
| `opencode auth logout` / `opencode mcp logout` | Deletes stored credentials; re-auth required. |
| `opencode upgrade` | Changes the installed version — may alter behavior. |
| `run --dangerously-skip-permissions` | Auto-approves every non-denied permission, bypassing the safety prompt. Avoid; never in untrusted contexts. |
| `serve`/`web` with `--hostname 0.0.0.0`/`all` (or `--mdns`, which defaults to `0.0.0.0`) | Exposes the backend to the network. Require `OPENCODE_SERVER_PASSWORD`; prefer localhost. |
| `--share` / `OPENCODE_AUTO_SHARE` | Publishes session content via a share URL. Confirm nothing sensitive is shared; use `export --sanitize` for transcripts. |

Credentials live in `~/.local/share/opencode/auth.json` — never print, commit, or share it.

## Common Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I'll memorize the flags." | The CLI evolves. `opencode <command> --help` is authoritative for the installed version; this skill is the map. |
| "`--dangerously-skip-permissions` makes automation easier." | It disables the permission guard. Use scoped agent permissions or an explicit allowlist instead; never on untrusted input. |
| "I'll start `serve` on `0.0.0.0` so I can reach it." | That exposes the backend to the network. Set `OPENCODE_SERVER_PASSWORD` and bind to localhost unless the user accepts the exposure. |
| "`opencode agent create` — I'll just write the prompt here." | Authoring agent prompts/permissions is `customize-opencode`'s job. Use the CLI to scaffold; defer the content. |
| "Each `run` is slow because MCP cold-boots." | Start `opencode serve` once and `run --attach` to it. |
| "I'll parse the formatted `run` output." | Use `--format json` for stable, machine-readable events instead of scraping pretty output. |
| "`uninstall` is fine, I'll just reinstall." | It deletes session data and snapshots unless you pass `--keep-data`/`--keep-config`. `--dry-run` first. |

## Red Flags

- Reaching for `--dangerously-skip-permissions` to "make it work".
- `serve`/`web` bound to `0.0.0.0`/`all` without `OPENCODE_SERVER_PASSWORD`.
- Running `uninstall`, `session delete`, or `auth logout` without confirming intent (and without `--dry-run` for uninstall).
- Editing `opencode.json` / agents / skills here instead of deferring to `customize-opencode` / `skill-authoring`.
- Scraping pretty `run` output instead of using `--format json`.
- Printing or committing `auth.json`, or a share URL containing sensitive data.
- Guessing a flag instead of checking `opencode <command> --help`.

## Verification

- [ ] The command and flags match `opencode <command> --help` (authoritative for the installed version).
- [ ] Non-interactive runs use `opencode run` (with `--format json` when the output is parsed).
- [ ] Attached runs point `--attach` at a reachable `serve`/`web` backend; auth set if the server requires it.
- [ ] No destructive command (`uninstall`, `session delete`, `auth logout`) ran without explicit user intent; `uninstall` was `--dry-run`'d first.
- [ ] `--dangerously-skip-permissions` was not used (or was explicitly authorized for a trusted context).
- [ ] Any server exposed beyond localhost has `OPENCODE_SERVER_PASSWORD` set.
- [ ] Config/agent/skill *content* changes were routed to `customize-opencode` / `skill-authoring` / `local-skill-index`, not improvised here.
