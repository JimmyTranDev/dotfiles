#!/usr/bin/env bash
#
# nvim-term.sh — read running CLIs inside live Neovim toggleterm terminals.
#
# Connects to running Neovim instances over their RPC sockets and dumps
# terminal-buffer contents WITHOUT taking over the UI. Read-only: it never
# sends keystrokes or changes editor state.
#
# Searches ACROSS every running nvim by default, so you can find a terminal
# without knowing which nvim owns it. Scope to one nvim with --server/--current.
#
# Usage:
#   nvim-term.sh sockets                 List discoverable nvim sockets (+ nvim:<pid> labels)
#   nvim-term.sh list                    List terminal buffers in EVERY nvim (SERVER BUF LINES CMD)
#   nvim-term.sh read <bufnr|substr> [N] Dump last N lines of a terminal (default 200; "all" for whole buffer)
#
# Aliases: list = ls | all | la | find
#
# Scope options:
#   --server <addr|nvim:PID|PID>   Target one nvim (socket path, or a short pid token)
#   --current, -c                  Target only the current nvim ($NVIM)
#   --all, -a                      Search every nvim (default)
#
# Examples:
#   nvim-term.sh list                       # every terminal across every nvim
#   nvim-term.sh read app:android 60        # find that terminal in whichever nvim, last 60 lines
#   nvim-term.sh read 27 all                # whole buffer 27 (searched across all nvims)
#   nvim-term.sh --server nvim:90541 list   # only the nvim with pid 90541
#   nvim-term.sh -c read opencode           # only the current nvim's opencode terminal
#
# When a substring matches terminals in more than one nvim, read lists the
# candidates and asks you to narrow it (add --server nvim:<pid> or a longer
# substring). The SERVER column marks the current nvim ($NVIM) with a "*".

set -euo pipefail

SERVER=""
SCOPE="global" # global | single

# --- parse scope flags anywhere before/after the subcommand ---
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --server) SERVER="${2:-}"; SCOPE="single"; shift 2 ;;
    --server=*) SERVER="${1#--server=}"; SCOPE="single"; shift ;;
    --current|-c) SERVER="${NVIM:-}"; SCOPE="single"; shift ;;
    --all|-a) SCOPE="global"; SERVER=""; shift ;;
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
  find "${base%/}/nvim.${user}" -type s 2>/dev/null | sort || true
  # XDG_RUNTIME_DIR fallback (common on Linux).
  if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    find "${XDG_RUNTIME_DIR%/}/nvim."* -type s 2>/dev/null | sort || true
  fi
}

# nvim.<pid>.0 -> nvim:<pid>
socket_label() {
  local b pid
  b="$(basename "$1")"
  pid="${b#nvim.}"
  pid="${pid%%.*}"
  printf 'nvim:%s' "$pid"
}

# Expand a --server value (socket path, nvim:PID, or bare PID) to a socket path.
expand_server() {
  local s="$1" pid m
  [ -z "$s" ] && return 0
  if [ -S "$s" ]; then printf '%s' "$s"; return 0; fi
  pid="$s"
  case "$s" in nvim:*) pid="${s#nvim:}" ;; esac
  if printf '%s' "$pid" | grep -qE '^[0-9]+$'; then
    m="$(discover_sockets | grep -E "nvim\.${pid}\." | head -n1 || true)"
    if [ -n "$m" ]; then printf '%s' "$m"; return 0; fi
  fi
  printf '%s' "$s"
}

# Resolve a single target socket: explicit SERVER (expanded), else newest.
resolve_single_server() {
  if [ -n "$SERVER" ]; then
    local s
    s="$(expand_server "$SERVER")"
    case "$SERVER" in
      nvim:*|[0-9]*)
        if [ ! -S "$s" ]; then
          err "No running nvim with id '$SERVER' (try: nvim-term.sh sockets)."
          return 1
        fi
        ;;
    esac
    printf '%s' "$s"
    return 0
  fi
  local socks
  socks="$(discover_sockets)"
  if [ -z "$socks" ]; then
    err "No running nvim socket found. Open nvim, or pass --server <addr>."
    return 1
  fi
  printf '%s\n' "$socks" \
    | while read -r s; do printf '%s\t%s\n' "$(stat -f '%m' "$s" 2>/dev/null || stat -c '%Y' "$s" 2>/dev/null)" "$s"; done \
    | sort -rn | head -n1 | cut -f2-
}

# Temp Lua file that returns "<buf>\t<lines>\t<cmd>" per terminal buffer.
list_lua_file() {
  local f
  f="$(mktemp "${TMPDIR:-/tmp}/nvimterm.XXXXXX")"
  cat > "$f" <<'LUA'
local o = {}
for _, b in ipairs(vim.api.nvim_list_bufs()) do
  if vim.bo[b].buftype == "terminal" then
    local n = vim.api.nvim_buf_get_name(b)
    local cmd = n:match("//%d+:(.*)$") or n
    o[#o+1] = string.format("%d\t%d\t%s", b, vim.api.nvim_buf_line_count(b), cmd)
  end
end
return table.concat(o, "\n")
LUA
  printf '%s' "$f"
}

# Emit "<buf>\t<lines>\t<cmd>" lines for one server (silent on dead sockets).
run_list_on() {
  local server="$1" f="$2"
  nvim --server "$server" --remote-expr "luaeval('dofile(\"$f\")')" 2>/dev/null || true
}

# Emit "<socket>\t<buf>\t<lines>\t<cmd>" for every terminal in every nvim.
collect_all() {
  local f s out line
  f="$(list_lua_file)"
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    out="$(run_list_on "$s" "$f")"
    [ -z "$out" ] && continue
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      printf '%s\t%s\n' "$s" "$line"
    done <<< "$out"
  done < <(discover_sockets)
  rm -f "$f"
}

# Dump a terminal buffer's tail from one server. Prepends the nvim label to the header.
read_on() {
  local server="$1" target="$2" n="$3" f esc_target esc_n out label
  f="$(mktemp "${TMPDIR:-/tmp}/nvimterm.XXXXXX")"
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
while #lines > 0 and lines[#lines]:match("^%s*$") do table.remove(lines) end
local name = vim.api.nvim_buf_get_name(b)
local cmd = name:match("//%d+:(.*)$") or name
local header = string.format("# buf %d  |  %s  |  %d lines total", b, cmd, total)
return header .. "\n" .. table.concat(lines, "\n")
LUA
  } > "$f"
  label="$(socket_label "$server")"
  out="$(nvim --server "$server" --remote-expr "luaeval('dofile(\"$f\")')")"
  rm -f "$f"
  printf '%s\n' "$out" | awk -v L="$label" 'NR==1 && /^# buf /{sub(/^# buf /, "# " L "  buf ")} {print}'
}

cmd_sockets() {
  local socks
  socks="$(discover_sockets)"
  if [ -z "$socks" ]; then err "No nvim sockets found."; return 1; fi
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    local mark=''
    [ -n "${NVIM:-}" ] && [ "$s" = "$NVIM" ] && mark=' *'
    printf '%-12s %s%s\n' "$(socket_label "$s")" "$s" "$mark"
  done <<< "$socks"
}

cmd_list() {
  if [ "$SCOPE" = "single" ]; then
    local server f out
    server="$(resolve_single_server)" || return 1
    f="$(list_lua_file)"
    out="$(run_list_on "$server" "$f")"
    rm -f "$f"
    if [ -z "$out" ]; then printf '(no terminal buffers in %s)\n' "$(socket_label "$server")"; return 0; fi
    printf '%-13s %-5s %-7s %s\n' "SERVER" "BUF" "LINES" "CMD"
    while IFS=$'\t' read -r buf lines cmd; do
      printf '%-13s %-5s %-7s %s\n' "$(socket_label "$server")" "$buf" "$lines" "$cmd"
    done <<< "$out"
    return 0
  fi

  local rows
  rows="$(collect_all | sort -t$'\t' -k1,1 -k2,2n)"
  if [ -z "$rows" ]; then err "No terminal buffers found in any running nvim (try: nvim-term.sh sockets)."; return 1; fi
  printf '%-13s %-5s %-7s %s\n' "SERVER" "BUF" "LINES" "CMD"
  while IFS=$'\t' read -r sock buf lines cmd; do
    local mark=''
    [ -n "${NVIM:-}" ] && [ "$sock" = "$NVIM" ] && mark='*'
    printf '%-13s %-5s %-7s %s\n' "$(socket_label "$sock")$mark" "$buf" "$lines" "$cmd"
  done <<< "$rows"
}

cmd_read() {
  local target="${1:-}" n="${2:-200}"
  if [ -z "$target" ]; then err "Usage: nvim-term.sh read <bufnr|substr> [N|all] [--server X]"; return 2; fi

  if [ "$SCOPE" = "single" ]; then
    local server
    server="$(resolve_single_server)" || return 1
    read_on "$server" "$target" "$n"
    return $?
  fi

  local rows matches count
  rows="$(collect_all)"
  if [ -z "$rows" ]; then err "No terminal buffers found in any running nvim (try: nvim-term.sh sockets)."; return 1; fi
  if printf '%s' "$target" | grep -qE '^[0-9]+$'; then
    matches="$(printf '%s\n' "$rows" | awk -F'\t' -v t="$target" '$2==t')"
  else
    matches="$(printf '%s\n' "$rows" | awk -F'\t' -v t="$target" 'index($4,t)')"
  fi
  count="$(printf '%s' "$matches" | grep -c . || true)"

  if [ "$count" -eq 0 ]; then
    err "No terminal matching \"$target\" in any nvim. Run: nvim-term.sh list"
    return 1
  fi
  if [ "$count" -gt 1 ]; then
    err "Multiple terminals match \"$target\" — narrow it or add --server nvim:<pid>:"
    while IFS=$'\t' read -r sock buf lines cmd; do
      err "  $(socket_label "$sock")  buf $buf  ($lines lines)  $cmd"
    done <<< "$matches"
    return 3
  fi

  local sock buf
  sock="$(printf '%s' "$matches" | cut -f1)"
  buf="$(printf '%s' "$matches" | cut -f2)"
  read_on "$sock" "$buf" "$n"
}

show_help() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; }

main() {
  local sub="${1:-}"
  [ $# -gt 0 ] && shift || true
  case "$sub" in
    sockets) cmd_sockets ;;
    list|ls|all|la|find) cmd_list ;;
    read|cat) cmd_read "$@" ;;
    ""|-h|--help|help) show_help ;;
    *) err "Unknown command: $sub (try: sockets | list | read)"; return 2 ;;
  esac
}

main "$@"
