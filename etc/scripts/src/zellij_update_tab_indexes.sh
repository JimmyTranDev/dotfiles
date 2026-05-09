#!/bin/bash

set -e

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	local layout
	layout=$(zellij action dump-layout 2>/dev/null)
	[[ -z "$layout" ]] && exit 0

	local current_tab_name
	current_tab_name=$(echo "$layout" | awk '/^[[:space:]]*tab[[:space:]].*name=.*focus=true/ {match($0, /name="[^"]*"/); print substr($0, RSTART+6, RLENGTH-7); exit}')
	[[ -z "$current_tab_name" ]] && exit 0
	local current_tab_base
	current_tab_base=$(echo "$current_tab_name" | sed 's/^[0-9][0-9]*\.//')

	local tab_lines
	tab_lines=$(echo "$layout" | awk '/^[[:space:]]*tab[[:space:]].*name=/ {print NR": "$0}')
	local tab_count
	tab_count=$(echo "$tab_lines" | wc -l | tr -d ' ')
	[[ "$tab_count" -eq 0 ]] && exit 0

	local needs_update=false
	local idx=0
	while IFS= read -r line; do
		local tab_line
		tab_line=$(echo "$line" | cut -d':' -f2-)
		local current_name
		current_name=$(echo "$tab_line" | sed -n 's/.*name="\([^"]*\)".*/\1/p')

		local base_name
		base_name=$(echo "$current_name" | sed 's/^[0-9][0-9]*\.//')
		base_name=$(echo "$base_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		[[ -z "$base_name" ]] && base_name="$current_name"

		if [[ -z "$base_name" ]] || [[ "$base_name" =~ ^[0-9]+\.?[[:space:]]*$ ]] || [[ "$base_name" =~ ^Tab\ #[0-9]+$ ]]; then
			continue
		fi

		((idx++)) || true
		local expected_name="${idx}.${base_name}"

		if [[ "$current_name" != "$expected_name" ]]; then
			needs_update=true
			break
		fi
	done <<<"$tab_lines"

	[[ "$needs_update" == false ]] && exit 0

	idx=0
	local tab_pos=0
	while IFS= read -r line; do
		((tab_pos++)) || true
		local tab_line
		tab_line=$(echo "$line" | cut -d':' -f2-)
		local current_name
		current_name=$(echo "$tab_line" | sed -n 's/.*name="\([^"]*\)".*/\1/p')

		local base_name
		base_name=$(echo "$current_name" | sed 's/^[0-9][0-9]*\.//')
		base_name=$(echo "$base_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		[[ -z "$base_name" ]] && base_name="$current_name"

		if [[ -z "$base_name" ]] || [[ "$base_name" =~ ^[0-9]+\.?[[:space:]]*$ ]] || [[ "$base_name" =~ ^Tab\ #[0-9]+$ ]]; then
			continue
		fi

		((idx++)) || true
		local new_name="${idx}.${base_name}"

		if [[ "$current_name" != "$new_name" ]]; then
			zellij action go-to-tab "$tab_pos" 2>/dev/null
			sleep 0.03
			zellij action rename-tab "$new_name" 2>/dev/null
		fi
	done <<<"$tab_lines"

	local target_idx=1
	local tab_idx=0
	while IFS= read -r line; do
		((tab_idx++)) || true
		local tab_line
		tab_line=$(echo "$line" | cut -d':' -f2-)
		local name
		name=$(echo "$tab_line" | sed -n 's/.*name="\([^"]*\)".*/\1/p')
		local base
		base=$(echo "$name" | sed 's/^[0-9][0-9]*\.//')
		if [[ "$base" == "$current_tab_base" ]]; then
			target_idx="$tab_idx"
			break
		fi
	done <<<"$tab_lines"
	zellij action go-to-tab "$target_idx" 2>/dev/null
}

main "$@"
