#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/zellij_tabs.sh"

LOG_FILE="/tmp/zellij_reindex.log"

log() {
	echo "$(date '+%H:%M:%S') $*" >>"$LOG_FILE"
}

# Re-exec the reindex as a daemon detached into its own session, then return at
# once. This script is launched synchronously inside a *floating* zellij Run
# pane bound to a tab op (tab-mode n/x and Alt n/Alt q/Alt i/Alt o/Alt y/Alt [/Alt ]); until
# it exits, that pane sits on screen as an empty terminal. zellij also SIGKILLs
# the pane's whole process group the instant the pane closes, so a plain
# background job (nohup &) gets killed mid-reindex — only a process in its own
# session survives. The double-fork + setsid detaches the worker before we
# return, so the floating pane closes near-instantly and never shows an empty
# terminal while the reindex finishes in the background. Prefer perl (tiny
# startup, always present on macOS, which has no setsid(1)); fall back to
# python3, which this script already requires.
detach_worker() {
	if command -v perl >/dev/null 2>&1; then
		perl -e 'use POSIX qw(setsid); my $p = fork(); if ($p) { waitpid($p, 0); exit 0; } setsid(); exit 0 if fork(); exec @ARGV;' "$0" --worker </dev/null >/dev/null 2>&1
	else
		python3 -c "
import os, sys
pid = os.fork()
if pid == 0:
    os.setsid()
    if os.fork() != 0:
        os._exit(0)
    os.execv(sys.argv[1], sys.argv[1:])
else:
    os.waitpid(pid, 0)
" "$0" --worker </dev/null >/dev/null 2>&1
	fi
}

main() {
	# Launcher pass: detach the real work (the --worker branch below) and return
	# immediately so the floating Run pane closes without flashing an empty
	# terminal. Nothing to do when we are not inside zellij.
	if [[ "$1" != "--worker" ]]; then
		if [[ -z "$ZELLIJ" ]]; then
			exit 0
		fi
		detach_worker
		exit 0
	fi

	>"$LOG_FILE"

	if [[ -z "$ZELLIJ" ]]; then
		log "Not in zellij, exiting"
		exit 0
	fi

	# Let any preceding native tab action (NewTab/CloseTab/MoveTab dispatched
	# from the same keybind) settle before querying the tab list.
	sleep 0.1

	local tabs_json
	tabs_json=$(zellij action list-tabs --json 2>/dev/null)
	if [[ -z "$tabs_json" ]]; then
		log "Failed to get tab list"
		exit 0
	fi

	local tab_count
	tab_count=$(echo "$tabs_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
	log "Found $tab_count tabs"

	if [[ "$tab_count" -eq 0 ]]; then
		exit 0
	fi

	# Map each tab (in position order) to its focused pane's folder name so a
	# lone-nvim tab can borrow that folder instead of showing "nvim". dump-layout
	# is the only source of pane cwds; list-tabs --json carries none. An empty or
	# failed dump leaves folders empty, so resolve_tab_base_name stays a no-op and
	# every tab keeps its existing base name.
	local layout
	layout=$(zellij action dump-layout 2>/dev/null || true)
	local folders=()
	while IFS= read -r folder_line; do
		folders+=("$folder_line")
	done < <(printf '%s\n' "$layout" | parse_focused_tab_folders)
	log "Parsed ${#folders[@]} tab folder(s) from layout"

	local needs_update=false
	local idx=0
	local pos=0

	while IFS= read -r line; do
		local tab_id name base_name folder
		((pos++)) || true
		tab_id=$(echo "$line" | cut -d'|' -f1)
		name=$(echo "$line" | cut -d'|' -f2)

		base_name=$(echo "$name" | sed 's/^[0-9][0-9]*\.//')
		base_name=$(echo "$base_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		if [[ -z "$base_name" ]]; then
			base_name="$name"
		fi

		if [[ -z "$base_name" ]]; then
			log "Skipping tab_id=$tab_id name='$name' (empty name)"
			continue
		fi

		folder="${folders[pos-1]}"
		base_name=$(resolve_tab_base_name "$base_name" "$folder")

		((idx++)) || true
		local expected_name="${idx}.${base_name}"

		if [[ "$name" != "$expected_name" ]]; then
			needs_update=true
			log "Tab '$name' should be '$expected_name' — update needed"
			break
		fi
	done < <(echo "$tabs_json" | python3 -c "
import sys, json
tabs = json.load(sys.stdin)
tabs.sort(key=lambda t: t['position'])
for t in tabs:
    print(f\"{t['tab_id']}|{t['name']}\")
")

	if [[ "$needs_update" == false ]]; then
		log "No update needed"
		exit 0
	fi

	idx=0
	pos=0
	while IFS= read -r line; do
		local tab_id name base_name folder
		((pos++)) || true
		tab_id=$(echo "$line" | cut -d'|' -f1)
		name=$(echo "$line" | cut -d'|' -f2)

		base_name=$(echo "$name" | sed 's/^[0-9][0-9]*\.//')
		base_name=$(echo "$base_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		if [[ -z "$base_name" ]]; then
			base_name="$name"
		fi

		if [[ -z "$base_name" ]]; then
			continue
		fi

		folder="${folders[pos-1]}"
		base_name=$(resolve_tab_base_name "$base_name" "$folder")

		((idx++)) || true
		local new_name="${idx}.${base_name}"

		if [[ "$name" != "$new_name" ]]; then
			log "Renaming tab_id=$tab_id from '$name' to '$new_name'"
			zellij action rename-tab-by-id "$tab_id" "$new_name" 2>/dev/null
		fi
	done < <(echo "$tabs_json" | python3 -c "
import sys, json
tabs = json.load(sys.stdin)
tabs.sort(key=lambda t: t['position'])
for t in tabs:
    print(f\"{t['tab_id']}|{t['name']}\")
")

	log "Reindex complete"
}

main "$@"
