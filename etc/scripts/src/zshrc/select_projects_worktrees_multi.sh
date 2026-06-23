# Unified multi-select picker (^[f).
#
# Same unified list as the single-select picker (^f) — every project and every
# worktree, most-recently used/created first — but with fzf --multi: pick one
# to cd into it, or several (TAB) to open each in its own Zellij tab. Selecting
# bumps each target's recency. Replaces the old select_projects_multi (^[f) and
# select_worktrees_multi (^[g). Relies on project_worktree_common.sh being
# sourced first.
select_projects_worktrees_multi() {
  {
    local programming_dir="$HOME/Programming"
    local created_dir="$programming_dir/wcreated"
    local checkout_dir="$programming_dir/wcheckout"

    typeset -A label_to_path
    local labels=()
    # NB: do not name this loop var `path`; in zsh `path` is the special array
    # tied to $PATH, so `local path` would wipe PATH inside this function and
    # break fzf/sort/touch.
    local mtime label entry_path
    while IFS=$'\t' read -r mtime label entry_path; do
      labels+=("$label")
      label_to_path[$label]="$entry_path"
    done < <(_collect_project_worktree_entries "$programming_dir" "$created_dir" "$checkout_dir" | sort -t$'\t' -k1,1 -rn)

    if (( ${#labels[@]} == 0 )); then
      zle -M "No projects or worktrees found"
      return 1
    fi

    local selected=()
    local line
    while IFS= read -r line; do
      [[ -n "$line" ]] && selected+=("$line")
    done < <(printf "%s\n" "${labels[@]}" | fzf --multi --prompt="Select projects/worktrees (TAB to multi-select): ")

    if (( ${#selected[@]} == 0 )); then
      return 0
    fi

    local item target_dir
    if (( ${#selected[@]} == 1 )); then
      target_dir="${label_to_path[${selected[1]}]}"
      [[ -n "$target_dir" ]] || return 1
      _bump_recency "$target_dir"
      builtin cd "$target_dir"
      zle reset-prompt
      return 0
    fi

    for item in "${selected[@]}"; do
      target_dir="${label_to_path[$item]}"
      [[ -n "$target_dir" ]] || continue
      _bump_recency "$target_dir"
      if [[ -n $ZELLIJ ]]; then
        zellij action new-tab --cwd "$target_dir" --name "${target_dir##*/}"
      fi
    done
    zle reset-prompt
  } &>/dev/null </dev/tty
}
zle -N select_projects_worktrees_multi
