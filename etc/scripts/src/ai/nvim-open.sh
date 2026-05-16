#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/logging.sh"

DESCRIPTION="Open files in an existing nvim instance or start a new one"

show_help() {
  echo "Usage: nvim-open.sh [options] <file...>"
  echo ""
  echo "${DESCRIPTION}"
  echo ""
  echo "Options:"
  echo "  --help    Show this help message"
  echo ""
  echo "Behavior:"
  echo "  1. If NVIM env var is set (inside nvim terminal), opens in parent nvim"
  echo "  2. If a nvim server socket is found, opens in that instance"
  echo "  3. Otherwise, opens a new nvim instance"
}

find_nvim_socket() {
  local socket_dir="${XDG_RUNTIME_DIR:-/tmp}"
  local socket=""

  for candidate in "${socket_dir}"/nvim.*.0 "${socket_dir}"/nvimsocket /tmp/nvim.sock; do
    if [ -S "${candidate}" ]; then
      socket="${candidate}"
      break
    fi
  done

  if [ -z "${socket}" ]; then
    local found
    found=$(find /tmp -maxdepth 2 -name "nvim.*.0" -type s 2>/dev/null | head -1)
    if [ -n "${found}" ]; then
      socket="${found}"
    fi
  fi

  echo "${socket}"
}

main() {
  if [ "$1" = "--help" ]; then
    show_help
    exit 0
  fi

  if [ $# -eq 0 ]; then
    log_error "No files specified"
    show_help
    exit 1
  fi

  if [ -n "${NVIM}" ]; then
    log_info "Opening in parent nvim instance"
    for file in "$@"; do
      nvim --server "${NVIM}" --remote "$(realpath "${file}")"
    done
    return
  fi

  local socket
  socket=$(find_nvim_socket)

  if [ -n "${socket}" ]; then
    log_info "Opening in existing nvim (${socket})"
    for file in "$@"; do
      nvim --server "${socket}" --remote "$(realpath "${file}")"
    done
    return
  fi

  log_info "No running nvim found, starting new instance"
  nvim "$@"
}

main "$@"
