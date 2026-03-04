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

DOTFILES_DIR="$HOME/Programming/dotfiles"

export BROWSER=firefox
export ARCHFLAGS="-arch $(uname -m)"
export MANPAGER='nvim +Man!'
export MANWIDTH=999
export ZELLIJ_TAB_NAME_MAX_LENGTH=10

if [[ "$(uname)" == "Darwin" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
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
[[ -f "$HOME/Programming/secrets/env.sh" ]] && source "$HOME/Programming/secrets/env.sh"

alias wD='$DOTFILES_DIR/etc/scripts/worktrees/worktree delete'
alias wC='$DOTFILES_DIR/etc/scripts/worktrees/worktree clean'
alias wr='$DOTFILES_DIR/etc/scripts/worktrees/worktree rename'
alias wu='$DOTFILES_DIR/etc/scripts/worktrees/worktree update'

alias nvm='fnm'
alias a='eval "$(poetry env activate)"'
alias d="$DOTFILES_DIR/etc/scripts/common/git_diff_commits.sh"
alias c='clear'
alias e='exit'
alias o='opencode'
alias g='rg'
alias n='nvim'
alias y='yazi'
alias z='zellij'
alias k="$DOTFILES_DIR/etc/scripts/kill_port.sh"
alias js="$DOTFILES_DIR/etc/scripts/sdk_select.sh"
alias ji="$DOTFILES_DIR/etc/scripts/sdk_install.sh"
alias knip='pnpm dlx knip'
alias knipw='pnpm dlx knip --watch'
alias loc='git ls-files | rg -v "(^|/)(assets|data)/" | xargs wc -l'
alias l="$DOTFILES_DIR/etc/scripts/select_git_folder_actx.sh"

if [[ "$(uname)" == "Darwin" ]]; then
  alias t='yabai --restart-service; skhd --restart-service'
fi

alias F="$DOTFILES_DIR/etc/scripts/pull_repos.sh"
alias I="$DOTFILES_DIR/etc/scripts/install.sh"
alias L="$DOTFILES_DIR/etc/scripts/sync_links.sh"
alias E="$DOTFILES_DIR/etc/scripts/sync_secrets.sh"
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
  fzf_select_all_projects_and_cd "Select project: " "$HOME/Programming" "$HOME/.last_project" 3
}
zle -N select_project
bindkey '^f' select_project

select_worktree() {
  fzf_select_git_repos_and_worktrees_and_cd "Select git repo/worktree: " "$HOME/Programming/Worktrees/" "$HOME/.last_worktree" 3
}
zle -N select_worktree
bindkey '^g' select_worktree

# Initialize starship if installed
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Initialize fnm if installed
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# # Initialize gcloud CLI if installed
# if [[ -f "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc" ]]; then
#   source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
#   source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"
# fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

zellij_tab_name_update() {
  if [[ -n $ZELLIJ ]]; then
    local current_dir="${PWD##*/}"
    [[ "$PWD" == "$HOME" ]] && current_dir="~"
    current_dir="${current_dir#[A-Z]*-[0-9]*-}"
    local max_length="${ZELLIJ_TAB_NAME_MAX_LENGTH:-20}"
    local tab_name="${current_dir:0:$max_length}"
    local tab_index=$(zellij action dump-layout 2>/dev/null | awk '/^[[:space:]]*tab[[:space:]].*name=/ {count++; if (/focus=true/) {print count; exit}}')
    [[ -n $tab_index ]] && tab_name="${tab_index}. ${tab_name}"
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
alias zj="zellij"
alias zja="zellij attach"
alias zjl="zellij list-sessions"
alias ghostty-use-script='sed -i "" "s|^#*initial-command.*|initial-command = $DOTFILES_DIR/etc/scripts/ghostty_zellij_startup.sh|" $DOTFILES_DIR/src/ghostty/config'
alias ghostty-use-zsh='sed -i "" "s|^initial-command.*|# initial-command = zsh|" $DOTFILES_DIR/src/ghostty/config'

export FZF_DEFAULT_OPTS="\
  --color=bg:#1e1e2e,fg:#cdd6f4,hl:#f38ba8 --color=fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8 --color=info:#89b4fa,prompt:#fab387,spinner:#f9e2af --color=header:#cba6f7,marker:#89dceb --color=border:#6c7086 \
"

# ===================================================================
# ZELLIJ AUTO-START (Alternative approach - disabled by default)
# ===================================================================

# Auto-start Zellij if:
# 1. We're in an interactive shell
# 2. Not already inside Zellij
# 3. Not in a terminal multiplexer already
# 4. Zellij command is available
# 5. Auto-attach is explicitly enabled
zellij_auto_start() {
  if [[ -o interactive ]] && [[ -z "$ZELLIJ" ]] && [[ -z "$TMUX" ]] && command -v zellij >/dev/null 2>&1; then
    if [[ "$ZELLIJ_AUTO_ATTACH" == "true" ]]; then
      # Auto-attach logic
      if zellij list-sessions >/dev/null 2>&1 && zellij list-sessions | grep -q .; then
        # There are existing sessions, attach to the first one
        echo "Attaching to existing Zellij session..."
        exec zellij attach
      else
        # No existing sessions, create a new one
        echo "Starting new Zellij session..."
        exec zellij
      fi
    fi
  fi
}

# Set default behavior (disabled by default, enable with zellij-enable-auto)
if [[ -z "$ZELLIJ_AUTO_ATTACH" ]]; then
  export ZELLIJ_AUTO_ATTACH="false"
fi

# # Uncomment the line below to enable auto-start in .zshrc
# # zellij_auto_start
# export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
