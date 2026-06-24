---
name: nvim-toggleterm-read
description: Reads the live output of CLIs running inside Neovim's toggleterm terminals (opencode, claude, make/mvn/npm runs, dev servers) by talking to the running nvim over its RPC socket. Searches across every running nvim by default, so it finds a terminal even when you don't know which nvim owns it. Use when you need to see what a terminal CLI inside nvim is doing, check a build/test/dev-server's current output, inspect a long-running command's progress, or confirm a toggleterm process finished — without stealing the editor UI. Triggers on "read the nvim terminal", "what's in my toggleterm", "check the running CLI in nvim", "which nvim has that terminal", "what did that terminal output".
---

# Reading nvim toggleterm CLIs

## Overview

This repo's Neovim runs CLIs inside `nvim-toggleterm` terminals managed by a
registry (`src/nvim/lua/custom/utils/terminal_registry.lua`) — opencode,
claudecode, `make`/`mvn`/`npm` runs, dev servers, Postgres, etc. Each is a
Neovim **terminal buffer**. This skill reads those buffers' scrollback over the
nvim RPC socket, so the agent can see live CLI output **read-only** without
sending keystrokes or changing the editor UI. Multiple nvims commonly run at
once (one per project/worktree); the helper queries **all** of them by default
so you can find a terminal without first knowing which nvim it lives in.

## When to Use

- You need to see the current/last output of a CLI running in a nvim toggleterm.
- Checking whether a long-running `mvn`/`make`/`npm`/dev-server command in a
  toggleterm has progressed, errored, or finished.
- Inspecting another agent's terminal (e.g. a `claude`/`opencode` toggleterm).

**Do NOT use when:**

- You want to *change* the nvim config or add new terminals — that edits Lua,
  use normal editing (and `customize-opencode` is unrelated).
- You need to *run* a command — just run it directly with the Bash tool.
- No nvim is running (the script reports no socket).

This skill is strictly **read-only**: it never sends input to a terminal.

## How It Works

Each running Neovim exposes an RPC socket. Several nvims usually run at once
(one per project/worktree), each with its own toggleterms — so the thing you
want is often **not** in the current nvim. The script therefore searches
**every** running nvim by default: it discovers all sockets under
`$TMPDIR/nvim.$USER/` and queries each. Reads happen via
`nvim --server <addr> --remote-expr 'luaeval(...)'`, dumping terminal-buffer
lines. The buffer name embeds the command (`term://<dir>//<pid>:<cmd>`), used as
a friendly label. Each nvim is labelled `nvim:<pid>` (from its socket name);
`$NVIM` (the current nvim, when running inside a toggleterm) is marked with `*`.

## The Workflow

Use the bundled helper at `scripts/nvim-term.sh` (path is relative to this
skill's base directory). `list` and `read` span **all** nvims by default — you
do not need to know which nvim owns a terminal.

1. **List every terminal across every nvim** (SERVER tells you which nvim; `*`
   marks the current one):
   ```bash
   scripts/nvim-term.sh list
   # SERVER        BUF   LINES   CMD
   # nvim:90541    27    854     pnpm app:android;#toggleterm#1
   # nvim:90541    48    21      pnpm server:dev;#toggleterm#5
   # nvim:1939     154   47      pnpm app:start:clear;#toggleterm#7
   ```
   (`all`, `ls`, `find` are aliases.)
2. **Read a terminal** by bufnr or by a substring of its command — searched
   across all nvims. Default is the last 200 lines; pass a number, or `all` for
   the whole scrollback. The header shows which nvim it came from:
   ```bash
   scripts/nvim-term.sh read app:android 60  # find that terminal in any nvim, last 60 lines
   scripts/nvim-term.sh read 48 all          # whole buffer 48 (located across all nvims)
   scripts/nvim-term.sh read mvn             # last 200 lines of the "mvn" terminal
   ```
   If a substring matches terminals in **more than one** nvim, `read` prints the
   candidates and exits non-zero — narrow the substring or scope to one nvim.
3. **Scope to one nvim** when a match is ambiguous, or to see only the current
   editor's terminals:
   ```bash
   scripts/nvim-term.sh sockets                    # list nvims (nvim:<pid> + socket)
   scripts/nvim-term.sh --server nvim:90541 list   # only that nvim (by pid token)
   scripts/nvim-term.sh -c list                    # only the current nvim ($NVIM)
   scripts/nvim-term.sh --server nvim:1939 read opencode
   ```
   `--server` accepts a `nvim:<pid>` token, a bare `<pid>`, or a full socket path.
4. **Interpret the tail.** Terminal scrollback includes TUI redraw artifacts
   (box-drawing chars, status lines). Focus on the last meaningful output lines;
   re-run `read` to poll a still-running command.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just run the command myself instead of reading the terminal." | The user is watching a *specific* running process in nvim; re-running it spawns a duplicate and loses context. Read the live buffer. |
| "I'll send keys to the terminal to scroll/clear." | This skill is read-only by design. Sending input can disrupt the user's running CLI. Use `read N`/`all` for more scrollback instead. |
| "The terminal isn't in this nvim, so I can't see it." | `list`/`read` already span every running nvim. Run `list` (or `read <substr>`) — the SERVER column tells you which nvim owns it. |
| "`read <substr>` returned 'multiple match' — I'll give up." | That's the disambiguation prompt. Pick one from the printed candidates: re-run with `--server nvim:<pid>` or a longer substring. |
| "I'll cat the socket / parse `term://` files." | The socket is RPC, not a log. Use the script's `--remote-expr` path. |

## Red Flags

- Re-running a build/test/server that is already running in a toggleterm.
- Sending keystrokes or `--remote-send` to a terminal under this skill.
- Manually looping over `sockets` with `--server` to find a terminal — plain
  `list`/`read` already search every nvim.
- Reporting "the terminal is empty" without trying a larger `N`/`all` or the
  correct nvim.

## Verification

- [ ] `scripts/nvim-term.sh list` returns a `SERVER BUF LINES CMD` table across
      all running nvims (or a clear "no terminal buffers"/"no socket" message).
- [ ] `scripts/nvim-term.sh read <target>` prints a `# nvim:<pid>  buf N | <cmd> | ...`
      header followed by that terminal's output (or a disambiguation list when
      the substring matches more than one nvim).
- [ ] No input was sent to any terminal; the user's nvim UI is unchanged.
