# Pick a project with fzf (last selection first), cd into it, then open Neovim.
# Sibling of select_project (^f) and select_project_opencode (^o): bound to ^n
# (see the widget below) but launches `nvim` instead of opencode. Shares
# ~/.last_project with ^f/^o.
select_project_nvim() {
	local programming_dir="$HOME/Programming"
	local last_file="$HOME/.last_project"
	local last_sel=""
	[[ -f "$last_file" ]] && last_sel=$(<"$last_file")

	local items=()
	local org_dir org_name dir dirname
	while IFS= read -r org_dir; do
		[[ ! -d "$org_dir" ]] && continue
		org_name="${org_dir%/}"
		org_name="${org_name##*/}"
		for dir in "$org_dir"/*(/N); do
			[[ -d "$dir" ]] || continue
			dirname="${dir%/}"
			dirname="${dirname##*/}"
			items+=("[$org_name] $dirname")
		done
	done < <(get_org_dirs "$programming_dir")

	if [[ ${#items[@]} -eq 0 ]]; then
		echo "No projects found in $programming_dir" >&2
		return 1
	fi

	local sorted_items=()
	if [[ -n "$last_sel" ]]; then
		for i in "${items[@]}"; do [[ "$i" == "$last_sel" ]] && sorted_items=("$i"); done
		for i in "${items[@]}"; do [[ "$i" != "$last_sel" ]] && sorted_items+=("$i"); done
	else
		sorted_items=("${items[@]}")
	fi

	local selected
	selected=$(printf "%s\n" "${sorted_items[@]}" | fzf --prompt="Select project: ") || return 1
	[[ -z "$selected" ]] && return 1

	printf "%s" "$selected" >"$last_file"
	local category="${selected%%]*}"
	category="${category#\[}"
	local project="${selected#*] }"
	builtin cd "$HOME/Programming/$category/$project" || return 1

	nvim
}

# ZLE widget for ^n: run the picker as a real foreground command (via the command
# line) so fzf and nvim get full control of the terminal. A ZLE widget can't
# cleanly hand a TUI the terminal itself, so stuff the function name into BUFFER
# and accept the line.
select_project_nvim_widget() {
	BUFFER="select_project_nvim"
	zle accept-line
}
zle -N select_project_nvim_widget
