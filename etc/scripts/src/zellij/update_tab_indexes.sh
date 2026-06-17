#!/bin/bash

set -e

LOG_FILE="/tmp/zellij_reindex.log"

log() {
	echo "$(date '+%H:%M:%S') $*" >>"$LOG_FILE"
}

main() {
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

	local needs_update=false
	local idx=0

	while IFS= read -r line; do
		local tab_id name base_name
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
	while IFS= read -r line; do
		local tab_id name base_name
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
