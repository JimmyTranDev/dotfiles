select_projects_multi() {
	{
		local programming_dir="$HOME/Programming"
		local items=()
		while IFS= read -r org_dir; do
			[[ ! -d "$org_dir" ]] && continue
			local org_name="${org_dir%/}"
			org_name="${org_name##*/}"
			for dir in "$org_dir"/*/; do
				[[ -d "$dir" ]] || continue
				local dirname="${dir%/}"
				dirname="${dirname##*/}"
				items+=("[$org_name] $dirname")
			done
		done < <(get_org_dirs "$programming_dir")

		if [[ ${#items[@]} -eq 0 ]]; then
			zle -M "No projects found"
			return 1
		fi

		local selected=()
		while IFS= read -r line; do
			[[ -n "$line" ]] && selected+=("$line")
		done < <(printf "%s\n" "${items[@]}" | fzf --multi --prompt="Select projects (TAB to multi-select): ")

		if [[ ${#selected[@]} -eq 0 ]]; then
			return 0
		fi

		if [[ ${#selected[@]} -eq 1 ]]; then
			local category="${selected[1]%%]*}"
			category="${category#\[}"
			local project="${selected[1]#*] }"
			builtin cd "$HOME/Programming/$category/$project"
			zle reset-prompt
			return 0
		fi

		for item in "${selected[@]}"; do
			local category="${item%%]*}"
			category="${category#\[}"
			local project="${item#*] }"
			local target_dir="$HOME/Programming/$category/$project"
			if [[ -n $ZELLIJ ]]; then
				zellij action new-tab --cwd "$target_dir" --name "$project"
			fi
		done
		zle reset-prompt
	} &>/dev/null </dev/tty
}
zle -N select_projects_multi
