#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

# fzf-pick a single project under ~/Programming and print its absolute path on
# stdout. Mirrors the ^o / ^f shell pickers: shares ~/.last_project so the most
# recent selection floats to the top. Returns non-zero if nothing is chosen.
select_project_dir() {
	local programming_dir="$HOME/Programming"
	local last_file="$HOME/.last_project"
	local last_sel=""
	[[ -f "$last_file" ]] && last_sel=$(<"$last_file")

	local items=()
	local org_dir org_name dir dirname
	while IFS= read -r org_dir; do
		[[ -d "$org_dir" ]] || continue
		org_name="${org_dir%/}"
		org_name="${org_name##*/}"
		for dir in "$org_dir"*/; do
			[[ -d "$dir" ]] || continue
			dirname="${dir%/}"
			dirname="${dirname##*/}"
			items+=("[$org_name] $dirname")
		done
	done < <(get_org_dirs "$programming_dir")

	if [[ ${#items[@]} -eq 0 ]]; then
		log_error "No projects found in $programming_dir"
		return 1
	fi

	local selected
	selected=$(reorder_last_first "$last_sel" "${items[@]}" | fzf --prompt="Select project: ") || return 1
	[[ -z "$selected" ]] && return 1

	printf "%s" "$selected" >"$last_file"
	local category="${selected%%]*}"
	category="${category#\[}"
	local project="${selected#*] }"
	printf "%s" "$HOME/Programming/$category/$project"
}

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool opencode fzf || exit 1

	# Pick one project once; cancelling fzf exits cleanly without opening a tab.
	local target_dir
	target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# Open the 2x2 opencode grid with all four panes rooted in that project.
	"$SCRIPT_DIR/open_opencode_quad.sh" "$target_dir"
}

main "$@"
