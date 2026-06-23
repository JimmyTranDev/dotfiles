#!/bin/bash

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

# fzf-pick another active Zellij session and switch to it without leaving the
# current one. `zellij list-sessions -ns` prints clean, unformatted names; the
# current session is filtered out so the top (preselected) fzf entry is always
# a different session reachable with a single <Enter>. Prints the chosen name on
# stdout; non-zero if nothing is available or the picker is cancelled.
select_session() {
	local current="${ZELLIJ_SESSION_NAME:-}"
	local sessions=()
	local name

	while IFS= read -r name; do
		[[ -z "$name" ]] && continue
		[[ "$name" == "$current" ]] && continue
		sessions+=("$name")
	done < <(zellij list-sessions -ns)

	if [[ ${#sessions[@]} -eq 0 ]]; then
		log_warning "No other Zellij sessions to switch to"
		return 1
	fi

	printf '%s\n' "${sessions[@]}" | fzf --prompt="Switch session: "
}

main() {
	# Only meaningful inside a running Zellij session.
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool zellij fzf || exit 1

	# Pick one session; cancelling fzf exits cleanly without switching.
	local selected
	selected="$(select_session)" || exit 0
	[[ -z "$selected" ]] && exit 0

	# switch-session jumps to another session from within Zellij (no nesting).
	zellij action switch-session "$selected"
}

main "$@"
