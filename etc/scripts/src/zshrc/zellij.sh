zellij_tab_name_update() {
  if [[ -n $ZELLIJ ]]; then
    local current_dir="${PWD##*/}"
    [[ "$PWD" == "$HOME" ]] && current_dir="~"
    local tab_name
    local git_branch
    git_branch=$(git branch --show-current 2>/dev/null)
    if [[ -n "$git_branch" && "$git_branch" =~ ([A-Z]+-[0-9]+) ]]; then
      tab_name="$MATCH"
    elif [[ "$current_dir" =~ ^[A-Z]+-[0-9]+ ]]; then
      tab_name="$MATCH"
    else
      local max_length="${ZELLIJ_TAB_NAME_MAX_LENGTH:-20}"
      tab_name="${current_dir:0:$max_length}"
    fi
    local tab_index=$(zellij action dump-layout 2>/dev/null | awk '/^[[:space:]]*tab[[:space:]].*name=/ {count++; if (/focus=true/) {print count; exit}}')
    [[ -n $tab_index ]] && tab_name="${tab_index}.${tab_name}"
    if [[ -f "$OPENCODE_STATUS_FILE" ]]; then
      local ai_status=$(<"$OPENCODE_STATUS_FILE")
      if [[ -n $ai_status ]]; then
        tab_name="${tab_name} [${ai_status}]"
      fi
    fi
    zellij action rename-tab "$tab_name" 2>/dev/null
  fi
}

zellij_update_tab_indexes() {
  $DOTFILES_DIR/etc/scripts/src/zellij/update_tab_indexes.sh >/dev/null 2>&1
  zle reset-prompt
  return 0
}
zle -N zellij_update_tab_indexes

zellij_tab_name_update
chpwd_functions=(${chpwd_functions:#zellij_tab_name_update} zellij_tab_name_update)

zellij_clear_tab_notification() {
  if [[ -n $ZELLIJ && -f "$OPENCODE_STATUS_FILE" ]]; then
    local ai_status=$(<"$OPENCODE_STATUS_FILE")
    if [[ "$ai_status" == "✅" ]]; then
      rm -f "$OPENCODE_STATUS_FILE"
      zellij_tab_name_update
    fi
  fi
}
precmd_functions=(${precmd_functions:#zellij_clear_tab_notification} zellij_clear_tab_notification)

zellij() {
  command zellij "$@"
  local ret=$?
  if [[ $1 == "action" && -n $ZELLIJ ]]; then
    case $2 in
      new-tab|close-tab|go-to-tab|move-tab|toggle-tab|break-pane|break-pane-left|break-pane-right)
        zellij_tab_name_update
        ;;
    esac
  fi
  return $ret
}

