#!/bin/bash

set -e

LOG_FILE="/tmp/zellij_reindex.log"

log() {
	echo "$(date '+%H:%M:%S') $*" >>"$LOG_FILE"
}

# Re-exec the reindex as a daemon detached into its own session, then return at
# once. This script is launched synchronously inside a *floating* zellij Run
# pane bound to a tab op (tab-mode n/x and Alt n/Alt q/Alt i/Alt o/Alt y); until
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

	# Reindex the whole tab list in a single python pass over the
	# position-sorted tabs. For each tab we strip a leading "N." index plus any
	# surrounding whitespace to recover its base name (falling back to the raw
	# name when stripping empties it, and skipping a blank-named tab without
	# consuming an index), then emit "tab_id<TAB>expected" only when the current
	# name already differs from the expected "<index>.<base>". This replaces the
	# previous two-pass, per-tab `echo | cut` / `echo | sed` fork storm with one
	# interpreter invocation; the loop below issues just the renames required.
	local tab_id new_name
	while IFS=$'\t' read -r tab_id new_name; do
		log "Renaming tab_id=$tab_id to '$new_name'"
		zellij action rename-tab-by-id "$tab_id" "$new_name" 2>/dev/null || true
	done < <(echo "$tabs_json" | python3 -c "
import sys, json, re
try:
    tabs = json.load(sys.stdin)
    tabs.sort(key=lambda t: t['position'])
except Exception:
    sys.exit(0)
idx = 0
for t in tabs:
    name = t['name']
    base = re.sub(r'^[0-9]+\.', '', name).strip()
    if not base:
        base = name
    if not base:
        continue
    idx += 1
    expected = '%d.%s' % (idx, base)
    if name != expected:
        sys.stdout.write('%s\t%s\n' % (t['tab_id'], expected))
")

	log "Reindex complete"
}

main "$@"
