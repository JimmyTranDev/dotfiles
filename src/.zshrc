ZSH_THEME=''
export ZSH="$HOME/.oh-my-zsh"

zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 14

COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"

HIST_STAMPS="dd/mm/yyyy"

plugins=(
  colored-man-pages
  history
)

DOTFILES_DIR="$HOME/Programming/JimmyTranDev/dotfiles"
export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"

export BROWSER=firefox
export ARCHFLAGS="-arch $(uname -m)"
export MANPAGER='nvim +Man!'
export MANWIDTH=999
export ZELLIJ_TAB_NAME_MAX_LENGTH=4
export ESPANSO_CONFIG_DIR="$HOME/.config/espanso"
export HOMEBREW_AUTO_UPDATE_SECS=604800
export HOMEBREW_API_AUTO_UPDATE_SECS=604800

if [[ "$(uname)" == "Darwin" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/27.1.12297006"
  export MANPATH="/usr/local/man${MANPATH:+:$MANPATH}"
fi

path_additions=(
  "$HOME/.local/bin"
  "$HOME/.local/share/pnpm"
)

if [[ -n "$ANDROID_HOME" ]]; then
  path_additions+=(
    "$ANDROID_HOME/emulator"
    "$ANDROID_HOME/platform-tools"
  )
fi
for p in "${path_additions[@]}"; do
  [[ ":$PATH:" != *":$p:"* ]] && export PATH="$PATH:$p"
done

[[ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
[[ -f "$HOME/Programming/JimmyTranDev/secrets/env.sh" ]] && source "$HOME/Programming/JimmyTranDev/secrets/env.sh"

alias wD='$DOTFILES_DIR/etc/scripts/worktrees/worktree delete'
alias wC='$DOTFILES_DIR/etc/scripts/worktrees/worktree clean'
alias wr='$DOTFILES_DIR/etc/scripts/worktrees/worktree rename'
alias wu='$DOTFILES_DIR/etc/scripts/worktrees/worktree update'

alias nvm='fnm'
alias a='eval "$(poetry env activate)"'
alias e='zellij'
alias d="$DOTFILES_DIR/etc/scripts/common/git_diff_commits.sh"
alias c='clear'
alias e='exit'
OPENCODE_STATUS_FILE="/tmp/opencode-status-$$"

o() {
  if [[ -n $ZELLIJ ]]; then
    printf "running" > "$OPENCODE_STATUS_FILE"
    zellij_tab_name_update
  fi
  opencode "$@"
  if [[ -n $ZELLIJ ]]; then
    printf "done" > "$OPENCODE_STATUS_FILE"
    zellij_tab_name_update
  fi
}
alias g='rg'
alias n='nvim'
alias y='yazi'
alias i='brew bundle --file=$DOTFILES_DIR/src/Brewfile --cleanup'
alias k="$DOTFILES_DIR/etc/scripts/kill_port.sh"
alias js="$DOTFILES_DIR/etc/scripts/sdk_select.sh"
alias ji="$DOTFILES_DIR/etc/scripts/sdk_install.sh"
alias knip='pnpm dlx knip'
alias knipw='pnpm dlx knip --watch'
alias loc='git ls-files | rg -v "(^|/)(assets|data)/" | xargs wc -l'
alias l="$DOTFILES_DIR/etc/scripts/select_git_folder_actx.sh"
alias csv='git ls-files "*/core/*.csv" 2>/dev/null | fzf --preview "head -20 {}" | xargs -r vd --csv-delimiter "|"'

if [[ "$(uname)" == "Darwin" ]]; then
  alias t='yabai --restart-service; skhd --restart-service'
fi

alias F="$DOTFILES_DIR/etc/scripts/pull_repos.sh"
alias I="$DOTFILES_DIR/etc/scripts/install.sh"
alias L="$DOTFILES_DIR/etc/scripts/sync_links.sh"
alias S="$DOTFILES_DIR/etc/scripts/slack_post_prs.sh"
alias C='find "$DOTFILES_DIR/etc/scripts" -type f -name "*.sh" -exec chmod +x {} \;'

wn() {
  local script_dir="$DOTFILES_DIR/etc/scripts/worktrees"
  source "$script_dir/config.sh"
  source "$script_dir/lib/core.sh" 
  source "$script_dir/lib/jira.sh"
  source "$script_dir/commands/create.sh"
  cmd_create "$@"
}

wo() {
  local script_dir="$DOTFILES_DIR/etc/scripts/worktrees"
  source "$script_dir/config.sh"
  source "$script_dir/lib/core.sh"
  source "$script_dir/lib/jira.sh" 
  source "$script_dir/commands/checkout.sh"
  cmd_checkout "$@"
}

source "$DOTFILES_DIR/etc/scripts/common/utility.sh"

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
      cd "${label_to_path[$selected]}"
      zle reset-prompt
    fi
  } &>/dev/null </dev/tty
}
zle -N select_worktree
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

bindkey '^f' select_project
bindkey '^g' select_worktree

zellij_tab_name_update() {
  if [[ -n $ZELLIJ ]]; then
    local current_dir="${PWD##*/}"
    [[ "$PWD" == "$HOME" ]] && current_dir="~"
    current_dir="${current_dir#[A-Z]*-[0-9]*-}"
    local max_length="${ZELLIJ_TAB_NAME_MAX_LENGTH:-20}"
    local tab_name="${current_dir:0:$max_length}"
    local tab_index=$(zellij action dump-layout 2>/dev/null | awk '/^[[:space:]]*tab[[:space:]].*name=/ {count++; if (/focus=true/) {print count; exit}}')
    [[ -n $tab_index ]] && tab_name="${tab_index}. ${tab_name}"
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
  $DOTFILES_DIR/etc/scripts/zellij_update_tab_indexes.sh >/dev/null 2>&1
  zle reset-prompt
  return 0
}
zle -N zellij_update_tab_indexes
bindkey '^u' zellij_update_tab_indexes

zellij_tab_name_update
chpwd_functions=(${chpwd_functions:#zellij_tab_name_update} zellij_tab_name_update)

zellij_clear_tab_notification() {
  if [[ -n $ZELLIJ && -f "$OPENCODE_STATUS_FILE" ]]; then
    local ai_status=$(<"$OPENCODE_STATUS_FILE")
    if [[ "$ai_status" == "done" ]]; then
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

alias zellij-enable-auto="export ZELLIJ_AUTO_ATTACH=true"
alias zellij-disable-auto="export ZELLIJ_AUTO_ATTACH=false"
alias zja="zellij attach"
alias zjl="zellij list-sessions"
alias ghostty-use-script='sed -i "" "s|^#*initial-command.*|initial-command = $DOTFILES_DIR/etc/scripts/ghostty_zellij_startup.sh|" $DOTFILES_DIR/src/ghostty/config'
alias ghostty-use-zsh='sed -i "" "s|^initial-command.*|# initial-command = zsh|" $DOTFILES_DIR/src/ghostty/config'

export FZF_DEFAULT_OPTS="\
  --color=bg:#1e1e2e,fg:#cdd6f4,hl:#f38ba8 --color=fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8 --color=info:#89b4fa,prompt:#fab387,spinner:#f9e2af --color=header:#cba6f7,marker:#89dceb --color=border:#6c7086 \
"

zellij_auto_start() {
  if [[ -o interactive ]] && [[ -z "$ZELLIJ" ]] && [[ -z "$TMUX" ]] && command -v zellij >/dev/null 2>&1; then
    if [[ "$ZELLIJ_AUTO_ATTACH" == "true" ]]; then
      if zellij list-sessions >/dev/null 2>&1 && zellij list-sessions | grep -q .; then
        exec zellij attach
      else
        exec zellij
      fi
    fi
  fi
}

if [[ -z "$ZELLIJ_AUTO_ATTACH" ]]; then
  export ZELLIJ_AUTO_ATTACH="false"
fi

# Google Cloud SDK
source "/opt/homebrew/Caskroom/gcloud-cli/561.0.0/google-cloud-sdk/path.zsh.inc"
source "/opt/homebrew/Caskroom/gcloud-cli/561.0.0/google-cloud-sdk/completion.zsh.inc"

# pnpm
export PNPM_HOME="/Users/jimmy/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/jimmy/.lmstudio/bin"
# End of LM Studio CLI section

