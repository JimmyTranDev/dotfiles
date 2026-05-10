select_project() {
  {
    local log_file="$HOME/.zshrc_widgets.log"
    local programming_dir="$HOME/Programming"
    local last_file="$HOME/.last_project"
    local last_sel=""
    [[ -f "$last_file" ]] && last_sel=$(<"$last_file")

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] select_project: started" >> "$log_file"

    local items=()
    while IFS= read -r org_dir; do
      [[ ! -d "$org_dir" ]] && continue
      local org_name="${org_dir%/}"
      org_name="${org_name##*/}"
      for dir in "$org_dir"/*(/N); do
        [[ -d "$dir" ]] || continue
        local dirname="${dir%/}"
        dirname="${dirname##*/}"
        items+=("[$org_name] $dirname")
      done
    done < <(get_org_dirs "$programming_dir")

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] select_project: found ${#items[@]} projects" >> "$log_file"

    if [[ ${#items[@]} -eq 0 ]]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] select_project: no projects found" >> "$log_file"
      zle -M "No projects found"
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
    selected=$(printf "%s\n" "${sorted_items[@]}" | fzf --prompt="Select project: ")
    if [[ -n "$selected" ]]; then
      printf "%s" "$selected" > "$last_file"
      local category="${selected%%]*}"
      category="${category#\[}"
      local project="${selected#*] }"
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] select_project: selected $category/$project" >> "$log_file"
      builtin cd "$HOME/Programming/$category/$project"
      zle reset-prompt
    else
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] select_project: cancelled by user" >> "$log_file"
    fi
  } 2>>"$HOME/.zshrc_widgets.log" </dev/tty
}
zle -N select_project
