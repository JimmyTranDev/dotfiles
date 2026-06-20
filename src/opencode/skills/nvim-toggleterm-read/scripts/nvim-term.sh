#!/usr/bin/env bash
#
# nvim-term.sh — read running CLIs inside a live Neovim's toggleterm terminals.
#
# Connects to a running Neovim over its RPC socket and dumps terminal-buffer
# contents WITHOUT taking over the UI. Read-only: it never sends keystrokes or
# changes editor state.
#
# Usage:
#   nvim-term.sh sockets                 List discoverable nvim sockets
#   nvim-term.sh list                    List terminal buffers (bufnr / lines / cmd)
#   nvim-term.sh read <bufnr|substr> [N] Dump last N lines of a terminal (default 200; "all" for whole buffer)
#
# Options:
#   --server <addr>   Explicit nvim socket/address (else $NVIM, else newest discovered socket)
#
# Examples:
#   nvim-term.sh list
#   nvim-term.sh read 220 50
#   nvim-term.sh read opencode all
#   nvim-term.sh --server "$NVIM" read make-start

set -euo pipefail

SERVER="${NVIM:-}"

# --- parse --server anywhere before the subcommand ---
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --server) SERVER="${2:-}"; shift 2 ;;
    --server=*) SERVER="${1#--server=}"; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]:-}"

err() { printf '%s\n' "$*" >&2; }

discover_sockets() {
  local base="${TMPDIR:-/tmp}"
  local user
  user="$(id -un)"
  # Neovim stdpath('run') is $TMPDIR/nvim.$USER/<random>/ on macOS/Linux.
  find "${base%/}/nvim.${user}" -type s 2>/dev/null | sort
  # XDG_RUNTIME_DIR fallback (common on Linux).
  if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    find "${XDG_RUNTIME_DIR%/}/nvim."* -type s 2>/dev/null | sort || true
  fi
}

resolve_server() {
  if [ -n "$SERVER" ]; then
    printf '%s\n' "$SERVER"
    return 0
  fi
  local socks
  socks="$(discover_sockets)"
  if [ -z "$socks" ]; then
    err "No running nvim socket found. Open nvim, or pass --server <addr>."
    return 1
  fi
  # Newest socket wins when several are running.
  printf '%s\n' "$socks" | while read -r s; do printf '%s\t%s\n' "$(stat -f '%m' "$s" 2>/dev/null || stat -c '%Y' "$s" 2>/dev/null)" "$s"; done \
    | sort -rn | head -n1 | cut -f2-
}

# Run a Lua chunk (passed as a file) in the server; print its string return.
run_lua() {
  local server="$1" luafile="$2"
  nvim --server "$server" --remote-expr "luaeval('dofile(\"$luafile\")')"
}

cmd_sockets() {
  local socks
  socks="$(discover_sockets)"
  if [ -z "$socks" ]; then err "No nvim sockets found."; return 1; fi
  printf '%s\n' "$socks"
}

cmd_list() {
  local server luafile
  server="$(resolve_server)" || return 1
  luafile="$(mktemp "${TMPDIR:-/tmp}/nvimterm.XXXXXX")"
  cat > "$luafile" <<'LUA'
local o = {}
for _, b in ipairs(vim.api.nvim_list_bufs()) do
  if vim.bo[b].buftype == "terminal" then
    local n = vim.api.nvim_buf_get_name(b)
    local cmd = n:match("//%d+:(.*)$") or n
    o[#o+1] = string.format("%d\t%d lines\t%s", b, vim.api.nvim_buf_line_count(b), cmd)
  end
end
if #o == 0 then return "(no terminal buffers)" end
return table.concat(o, "\n")
LUA
  run_lua "$server" "$luafile"
  rm -f "$luafile"
}

cmd_read() {
  local target="${1:-}" n="${2:-200}" server luafile
  if [ -z "$target" ]; then err "Usage: nvim-term.sh read <bufnr|substr> [N|all]"; return 2; fi
  server="$(resolve_server)" || return 1
  luafile="$(mktemp "${TMPDIR:-/tmp}/nvimterm.XXXXXX")"
  # Escape target/N as Lua string literals (backslash + double-quote safe).
  local esc_target esc_n
  esc_target="${target//\\/\\\\}"; esc_target="${esc_target//\"/\\\"}"
  esc_n="${n//\\/\\\\}"; esc_n="${esc_n//\"/\\\"}"
  {
    printf 'local TARGET = "%s"\n' "$esc_target"
    printf 'local NREQ = "%s"\n' "$esc_n"
    cat <<'LUA'
local function find_buf()
  if TARGET:match("^%d+$") then
    local b = tonumber(TARGET)
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == "terminal" then return b end
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buftype == "terminal" then
      local n = vim.api.nvim_buf_get_name(b)
      if n:find(TARGET, 1, true) then return b end
    end
  end
  return nil
end
local b = find_buf()
if not b then return "No matching terminal buffer for: " .. TARGET end
local total = vim.api.nvim_buf_line_count(b)
local start
if NREQ == "all" then start = 0 else start = -1 * (tonumber(NREQ) or 200) end
local lines = vim.api.nvim_buf_get_lines(b, start, -1, false)
-- trim trailing blank lines
while #lines > 0 and lines[#lines]:match("^%s*$") do table.remove(lines) end
local name = vim.api.nvim_buf_get_name(b)
local cmd = name:match("//%d+:(.*)$") or name
local header = string.format("# buf %d  |  %s  |  %d lines total", b, cmd, total)
return header .. "\n" .. table.concat(lines, "\n")
LUA
  } > "$luafile"
  run_lua "$server" "$luafile"
  rm -f "$luafile"
}

main() {
  local sub="${1:-}"
  [ $# -gt 0 ] && shift || true
  case "$sub" in
    sockets) cmd_sockets ;;
    list|ls) cmd_list ;;
    read|cat) cmd_read "$@" ;;
    ""|-h|--help|help)
      sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'
      ;;
    *) err "Unknown command: $sub (try: sockets | list | read)"; return 2 ;;
  esac
}

main "$@"
