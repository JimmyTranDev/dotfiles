# Unified single-select picker (^f).
#
# Lists every project under ~/Programming/<org>/<repo> and every worktree under
# wcreated/wcheckout in a single fzf list, most-recently used/created first
# (by .git mtime), then cd into the choice. Selecting touches the target's .git
# so it floats to the top next time. Replaces the old select_project (^f) and
# select_worktree (^g). Shares _collect_project_worktree_entries with the
# multi-select widget (^[f); both rely on project_worktree_common.sh being
# sourced first.
select_project_worktree() {
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

    local selected
    selected=$(printf "%s\n" "${labels[@]}" | fzf --prompt="Select project/worktree: ")
    if [[ -n "$selected" ]]; then
      local target_dir="${label_to_path[$selected]}"
      [[ -n "$target_dir" ]] || return 1
      _bump_recency "$target_dir"
      builtin cd "$target_dir"
      zle reset-prompt
    fi
  } &>/dev/null </dev/tty
}
zle -N select_project_worktree
