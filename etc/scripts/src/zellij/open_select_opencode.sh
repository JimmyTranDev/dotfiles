#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool opencode fzf || exit 1

	# Pick one project once (select_project_dir lives in utils/utility.sh);
	# cancelling fzf exits cleanly without opening a tab.
	local target_dir
	target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# Open the 2x2 opencode grid with all four panes rooted in that project.
	"$SCRIPT_DIR/open_opencode_quad.sh" "$target_dir"
}

main "$@"
