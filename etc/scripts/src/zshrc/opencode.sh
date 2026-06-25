o() {
	if [[ -n $ZELLIJ ]]; then
		zellij_tab_name_update
	fi
	opencode "$@"
	if [[ -n $ZELLIJ ]]; then
		zellij_tab_name_update
	fi
}
