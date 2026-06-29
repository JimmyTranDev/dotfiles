# Shared discovery for the unified project + worktree pickers.
#
# Sourced by .zshrc *before* select_project_worktree.sh (^f) and
# select_projects_worktrees_multi.sh (^[f). Depends on get_org_dirs from
# etc/scripts/utils/utility.sh, which .zshrc sources earlier.
#
# _collect_project_worktree_entries <programming_dir> <created_dir> <checkout_dir>
#   Emits one TAB-separated record per project and per worktree:
#       <mtime-epoch>\t<label>\t<absolute-path>
#   Projects:  <programming_dir>/<org>/<repo>  -> label "[org] repo"
#              recency = the repo's .git mtime (dir for normal repos), falling
#              back to the repo directory's own mtime for non-git folders.
#   Worktrees: <created_dir>|<checkout_dir>/<wt> -> label "[parent-repo] wt"
#              recency = the worktree's .git file mtime.
#   Missing directories are skipped silently. Callers sort by field 1 desc to
#   get "recently used/created first".
_collect_project_worktree_entries() {
  emulate -L zsh
  setopt local_options no_nomatch
  local programming_dir="$1" created_dir="$2" checkout_dir="$3"
  zmodload -F zsh/stat b:zstat 2>/dev/null

  local org_dir org_name repo_dir repo_path repo_name git_path mtime
  while IFS= read -r org_dir; do
    [[ -d "$org_dir" ]] || continue
    org_dir="${org_dir%/}"
    org_name="${org_dir##*/}"
    for repo_dir in "$org_dir"/*(/N); do
      repo_path="${repo_dir%/}"
      repo_name="${repo_path##*/}"
      git_path="$repo_path/.git"
      mtime="$(zstat +mtime "$git_path" 2>/dev/null)"
      [[ -n "$mtime" ]] || mtime="$(zstat +mtime "$repo_path" 2>/dev/null)"
      [[ -n "$mtime" ]] || mtime=0
      printf '%s\t[%s] %s\t%s\n' "$mtime" "$org_name" "$repo_name" "$repo_path"
    done
  done < <(get_org_dirs "$programming_dir")

  local dir wt_dir wt_path wt_name git_file gitdir repo_root project_name
  for dir in "$created_dir" "$checkout_dir"; do
    [[ -d "$dir" ]] || continue
    for wt_dir in "$dir"/*/(N); do
      wt_path="${wt_dir%/}"
      git_file="$wt_path/.git"
      [[ -f "$git_file" ]] || continue
      wt_name="${wt_path##*/}"
      gitdir="${$(<"$git_file")#gitdir: }"
      repo_root="${gitdir%/.git/worktrees/*}"
      project_name="${repo_root##*/}"
      mtime="$(zstat +mtime "$git_file" 2>/dev/null)"
      [[ -n "$mtime" ]] || mtime=0
      printf '%s\t[%s] %s\t%s\n' "$mtime" "$project_name" "$wt_name" "$wt_path"
    done
  done
}

# _bump_recency <path>
#   Mark a project/worktree as just-used so it sorts to the top next time, by
#   touching the same thing _collect_project_worktree_entries reads for mtime:
#   the .git entry when present (file for worktrees, dir for repos), otherwise
#   the directory itself.
_bump_recency() {
  local target_dir="$1"
  [[ -n "$target_dir" ]] || return 0
  if [[ -e "$target_dir/.git" ]]; then
    touch "$target_dir/.git" 2>/dev/null
  else
    touch "$target_dir" 2>/dev/null
  fi
}
