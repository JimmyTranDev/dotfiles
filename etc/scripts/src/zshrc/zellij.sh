# random_tab_name (used below) lives in the shared bash/zsh-portable helper.
source "$DOTFILES_DIR/etc/scripts/utils/zellij_tabs.sh"

zellij_tab_name_update() {
  if [[ -n $ZELLIJ ]]; then
    # Name the tab after a deterministic random "<adjective>-<noun>" derived
    # from the current directory: the same directory always maps to the same
    # name, so this recompute-on-cd hook never makes the tab name flicker.
    local tab_name
    tab_name=$(random_tab_name "$PWD")
    local layout
    layout=$(zellij action dump-layout 2>/dev/null)
    local tab_index
    tab_index=$(awk '/^[[:space:]]*tab[[:space:]].*name=/ {count++; if (/focus=true/) {print count; exit}}' <<<"$layout")
    [[ -n $tab_index ]] && tab_name="${tab_index}.${tab_name}"
    # Preserve any opencode status badge (⚙/✓) the zellij-tab-status plugin
    # appended as a suffix, so a cd or tab action does not wipe it.
    local current_name badge
    current_name=$(awk '/^[[:space:]]*tab[[:space:]].*name=/ && /focus=true/ {if (match($0, /name="[^"]*"/)) {print substr($0, RSTART+6, RLENGTH-7); exit}}' <<<"$layout")
    badge="${current_name##*[!⚙✓]}"
    tab_name="${tab_name}${badge}"
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
