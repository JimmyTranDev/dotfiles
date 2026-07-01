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
    local layout
    layout=$(zellij action dump-layout 2>/dev/null)
    local tab_index
    tab_index=$(awk '/^[[:space:]]*tab[[:space:]].*name=/ {count++; if (/focus=true/) {print count; exit}}' <<<"$layout")
    [[ -n $tab_index ]] && tab_name="${tab_index}.${tab_name}"
    zellij action rename-tab "$tab_name" 2>/dev/null
  fi
}

zellij_update_tab_indexes() {
  $DOTFILES_DIR/etc/scripts/src/zellij/update_tab_indexes.sh >/dev/null 2>&1
  zle reset-prompt
  return 0
}
zle -N zellij_update_tab_indexes

# Run the initial tab-name update in the background so startup is not blocked on
# zellij action round-trips (~200ms); chpwd + the zellij() wrapper stay sync.
if [[ -n $ZELLIJ ]]; then
  zellij_tab_name_update &!
fi
chpwd_functions=(${chpwd_functions:#zellij_tab_name_update} zellij_tab_name_update)

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
