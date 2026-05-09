select_worktrees_multi() {
  {
    local created_dir="$HOME/Programming/wcreated"
    local checkout_dir="$HOME/Programming/wcheckout"

    zmodload -F zsh/stat b:zstat
    typeset -A label_to_path
    local entries=()
    for dir in "$created_dir" "$checkout_dir"; do
      [[ -d "$dir" ]] || continue
      for wt_dir in "$dir"/*/(N); do
        [[ -d "$wt_dir" ]] || continue
        local git_file="$wt_dir.git"
        [[ -f "$git_file" ]] || continue
        local wt_name="${wt_dir%/}"
        wt_name="${wt_name##*/}"
        local gitdir="${$(<"$git_file")#gitdir: }"
        local repo_root="${gitdir%/.git/worktrees/*}"
        local project_name="${repo_root##*/}"
        local label="[$project_name] $wt_name"
        local mtime
        mtime=$(zstat +mtime "$git_file" 2>/dev/null) || mtime=0
        entries+=("$mtime $label")
        label_to_path[$label]="${wt_dir%/}"
      done
    done

    if [[ ${#entries[@]} -eq 0 ]]; then
      zle -M "No worktrees found"
      return 1
    fi

    local sorted_items=()
    local line
    while IFS= read -r line; do
      sorted_items+=("${line#* }")
    done < <(printf "%s\n" "${entries[@]}" | sort -rn)

    local selected=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && selected+=("$line")
    done < <(printf "%s\n" "${sorted_items[@]}" | fzf --multi --prompt="Select worktrees (TAB to multi-select): ")

    if [[ ${#selected[@]} -eq 0 ]]; then
      return 0
    fi

    if [[ ${#selected[@]} -eq 1 ]]; then
      local target_dir="${label_to_path[${selected[1]}]}"
      [[ -f "$target_dir/.git" ]] && touch "$target_dir/.git" 2>/dev/null
      cd "$target_dir"
      zle reset-prompt
      return 0
    fi

    for item in "${selected[@]}"; do
      local target_dir="${label_to_path[$item]}"
      if [[ -n $ZELLIJ && -n "$target_dir" ]]; then
        local wt_name="${target_dir##*/}"
        zellij action new-tab --cwd "$target_dir" --name "$wt_name"
      fi
    done
    zle reset-prompt
  } &>/dev/null </dev/tty
}
zle -N select_worktrees_multi
