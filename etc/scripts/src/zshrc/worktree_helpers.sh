wn() {
  local script_dir="$DOTFILES_DIR/etc/scripts/src/worktrees"
  local lib_dir="$DOTFILES_DIR/etc/scripts/utils"
  source "$script_dir/config.sh"
  source "$lib_dir/worktree_core.sh" 
  source "$lib_dir/jira.sh"
  source "$script_dir/commands/create.sh"
  cmd_create "$@"
}

wo() {
  local script_dir="$DOTFILES_DIR/etc/scripts/src/worktrees"
  local lib_dir="$DOTFILES_DIR/etc/scripts/utils"
  source "$script_dir/config.sh"
  source "$lib_dir/worktree_core.sh"
  source "$lib_dir/jira.sh" 
  source "$script_dir/commands/checkout.sh"
  cmd_checkout "$@"
}
