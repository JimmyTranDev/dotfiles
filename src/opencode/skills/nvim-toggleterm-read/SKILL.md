---
name: nvim-toggleterm-read
description: Reads the live output of CLIs running inside Neovim's toggleterm terminals (opencode, claude, make/mvn/npm runs, dev servers) by talking to the running nvim over its RPC socket. Use when you need to see what a terminal CLI inside nvim is doing, check a build/test/dev-server's current output, inspect a long-running command's progress, or confirm a toggleterm process finished — without stealing the editor UI. Triggers on "read the nvim terminal", "what's in my toggleterm", "check the running CLI in nvim", "what did that terminal output".
---

# Reading nvim toggleterm CLIs

## Overview

This repo's Neovim runs CLIs inside `nvim-toggleterm` terminals managed by a
registry (`src/nvim/lua/custom/utils/terminal_registry.lua`) — opencode,
claudecode, `make`/`mvn`/`npm` runs, dev servers, Postgres, etc. Each is a
Neovim **terminal buffer**. This skill reads those buffers' scrollback over the
running nvim's RPC socket, so the agent can see live CLI output **read-only**
without sending keystrokes or changing the editor UI.

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

Neovim always exposes an RPC socket. When the agent runs inside a toggleterm,
`$NVIM` points at the parent nvim's socket; otherwise the script discovers
sockets under `$TMPDIR/nvim.$USER/`. Reads happen via
`nvim --server <addr> --remote-expr 'luaeval(...)'`, dumping terminal-buffer
lines. The buffer name embeds the command (`term://<dir>//<pid>:<cmd>`), used as
a friendly label.

## The Workflow

Use the bundled helper at `scripts/nvim-term.sh` (path is relative to this
skill's base directory).

1. **List the terminals** to get bufnr + command:
   ```bash
   scripts/nvim-term.sh list
   # 220	61 lines	opencode --port
   ```
2. **Read a terminal** by bufnr or by a substring of its command. Default is the
   last 200 lines; pass a number, or `all` for the whole scrollback:
   ```bash
   scripts/nvim-term.sh read 220 50      # last 50 lines of buffer 220
   scripts/nvim-term.sh read mvn all     # whole buffer whose cmd contains "mvn"
   scripts/nvim-term.sh read make-start  # last 200 lines, matched by substring
   ```
3. **If no socket / wrong nvim**, inspect or pin the target:
   ```bash
   scripts/nvim-term.sh sockets                  # list candidate sockets
   scripts/nvim-term.sh --server <addr> list     # target a specific nvim
   ```
4. **Interpret the tail.** Terminal scrollback includes TUI redraw artifacts
   (box-drawing chars, status lines). Focus on the last meaningful output lines;
   re-run `read` to poll a still-running command.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just run the command myself instead of reading the terminal." | The user is watching a *specific* running process in nvim; re-running it spawns a duplicate and loses context. Read the live buffer. |
| "I'll send keys to the terminal to scroll/clear." | This skill is read-only by design. Sending input can disrupt the user's running CLI. Use `read N`/`all` for more scrollback instead. |
| "No `$NVIM`, so I can't read it." | Run `scripts/nvim-term.sh sockets` and target one with `--server`. |
| "I'll cat the socket / parse `term://` files." | The socket is RPC, not a log. Use the script's `--remote-expr` path. |

## Red Flags

- Re-running a build/test/server that is already running in a toggleterm.
- Sending keystrokes or `--remote-send` to a terminal under this skill.
- Reporting "the terminal is empty" without trying a larger `N`/`all` or the
  correct socket.

## Verification

- [ ] `scripts/nvim-term.sh list` returns one or more terminal buffers (or a
      clear "no terminal buffers"/"no socket" message).
- [ ] `scripts/nvim-term.sh read <target>` prints a `# buf N | <cmd> | ...`
      header followed by that terminal's output.
- [ ] No input was sent to any terminal; the user's nvim UI is unchanged.
