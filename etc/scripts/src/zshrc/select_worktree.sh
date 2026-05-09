select_worktree() {
  {
    local created_dir="$HOME/Programming/wcreated"
    local checkout_dir="$HOME/Programming/wcheckout"
    local last_file="$HOME/.last_worktree"
    local last_sel=""
    [[ -f "$last_file" ]] && last_sel=$(<"$last_file")

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

    if [[ -n "$last_sel" && ${label_to_path[$last_sel]+set} == set ]]; then
      local pinned=("$last_sel")
      for item in "${sorted_items[@]}"; do
        [[ "$item" != "$last_sel" ]] && pinned+=("$item")
      done
      sorted_items=("${pinned[@]}")
    fi

    local selected
    selected=$(printf "%s\n" "${sorted_items[@]}" | fzf --prompt="Select worktree: ")
    if [[ -n "$selected" ]]; then
      printf "%s" "$selected" > "$last_file"
      local target_dir="${label_to_path[$selected]}"
      [[ -f "$target_dir/.git" ]] && touch "$target_dir/.git" 2>/dev/null
      cd "$target_dir"
      zle reset-prompt
    fi
  } &>/dev/null </dev/tty
}
zle -N select_worktree
