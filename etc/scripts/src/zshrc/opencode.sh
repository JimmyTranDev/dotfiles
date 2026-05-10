OPENCODE_STATUS_FILE="/tmp/opencode-status-$$"

o() {
	if [[ -n $ZELLIJ ]]; then
		printf "🤖" >"$OPENCODE_STATUS_FILE"
		zellij_tab_name_update
	fi
	opencode "$@"
	if [[ -n $ZELLIJ ]]; then
		printf "✅" >"$OPENCODE_STATUS_FILE"
		zellij_tab_name_update
	fi
}
