select_project() {
  {
    local programming_dir="$HOME/Programming"
    local last_file="$HOME/.last_project"
    local last_sel=""
    [[ -f "$last_file" ]] && last_sel=$(<"$last_file")

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
      builtin cd "$HOME/Programming/$category/$project"
      zle reset-prompt
    fi
  } &>/dev/null </dev/tty
}
zle -N select_project
