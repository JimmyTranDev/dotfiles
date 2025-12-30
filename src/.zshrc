zmodload zsh/zprof

ZSH_THEME='robbyrussell'
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

export ARCHFLAGS="-arch x86_64"
export MANPAGER='nvim +Man!'
export MANWIDTH=999
export ANDROID_HOME="$HOME/Library/Android/sdk"
export MANPATH="/usr/local/man:$MANPATH"

path_additions=(
  "$ANDROID_HOME/emulator"
  "$ANDROID_HOME/platform-tools"
  "$HOME/.local/bin"
  "$HOME/.local/share/pnpm"
)
for p in "${path_additions[@]}"; do
  [[ ":$PATH:" != *":$p:"* ]] && export PATH="$PATH:$p"
done

[[ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
[[ -f "$HOME/Programming/secrets/env.sh" ]] && source "$HOME/Programming/secrets/env.sh"

alias nvm='fnm'
alias a='eval "$(poetry env activate)"'
alias c='clear'
alias w='worktree'
alias e='exit'
alias o='opencode'
alias g='grep -rnw . -e'
alias n='nvim'
alias t='yabai --restart-service; skhd --restart-service'
alias y='yazi'
alias z='zellij'
alias l='ls -la'
alias k="$HOME/Programming/dotfiles/etc/scripts/kill_port.sh"
alias l="$HOME/Programming/dotfiles/etc/scripts/select_git_folder_actx.sh"

alias F="$HOME/Programming/dotfiles/etc/scripts/install/fetch_all_folders.sh"
alias C="$HOME/Programming/dotfiles/etc/scripts/install/clone_essential_repos.sh"
alias I="$HOME/Programming/dotfiles/etc/scripts/install/install.sh"
alias L="$HOME/Programming/dotfiles/etc/scripts/install/link.sh"

wn() {
  # Source the worktree configuration and libraries
  local script_dir="$HOME/Programming/dotfiles/etc/scripts/worktrees"
  source "$script_dir/config.sh"
  source "$script_dir/lib/core.sh" 
  source "$script_dir/lib/jira.sh"
  source "$script_dir/commands/create.sh"
  
  # Call the create command function directly
  cmd_create "$@"
}

wo() {
  # Source the worktree configuration and libraries
  local script_dir="$HOME/Programming/dotfiles/etc/scripts/worktrees"
  source "$script_dir/config.sh"
  source "$script_dir/lib/core.sh"
  source "$script_dir/lib/jira.sh" 
  source "$script_dir/commands/checkout.sh"
  
  # Call the checkout command function directly
  cmd_checkout "$@"
}
alias wD='$HOME/Programming/dotfiles/etc/scripts/worktrees/worktree delete'
alias wC='$HOME/Programming/dotfiles/etc/scripts/worktrees/worktree clean'
alias wr='$HOME/Programming/dotfiles/etc/scripts/worktrees/worktree rename'
alias wu='$HOME/Programming/dotfiles/etc/scripts/worktrees/worktree update'
alias vsc='cd ~/Library/Application\ Support/Code/User/'

source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"

select_project() {
  fzf_select_all_projects_and_cd "Select project: " "$HOME/Programming" "$HOME/.last_project" "" 3
}
zle -N select_project
bindkey '^f' select_project

select_worktree() {
  fzf_select_git_repos_and_worktrees_and_cd "Select git repo/worktree: " "$HOME/Programming/Worktrees/" "$HOME/.last_worktree" "" 3
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

zellij_tab_name_update() {
  if [[ -n $ZELLIJ ]]; then
    local current_dir="${PWD/#$HOME/~}"
    current_dir="${current_dir##*/}"
    local tab_name="${current_dir:0:20}"
    command nohup zellij action rename-tab "$tab_name" >/dev/null 2>&1
  fi
}
zellij_tab_name_update
chpwd_functions+=(zellij_tab_name_update)

# ===================================================================
# THEME MANAGEMENT
# ===================================================================

# Source theme configuration
if [[ -f "$HOME/Programming/dotfiles/etc/theme.conf" ]]; then
  source "$HOME/Programming/dotfiles/etc/theme.conf"
fi

# Theme management aliases
alias theme-set="zsh $HOME/Programming/dotfiles/etc/scripts/theme.sh set"
alias theme-get="zsh $HOME/Programming/dotfiles/etc/scripts/theme.sh get"
alias theme-list="zsh $HOME/Programming/dotfiles/etc/scripts/theme.sh list"

# ===================================================================
# STORAGE MANAGEMENT
# ===================================================================

# Storage management aliases
alias storage-init="$HOME/Programming/dotfiles/etc/scripts/storage.sh init"
alias storage-sync="$HOME/Programming/dotfiles/etc/scripts/storage.sh sync"

# Zellij management aliases
alias zellij-enable-auto="export ZELLIJ_AUTO_ATTACH=true"
alias zellij-disable-auto="export ZELLIJ_AUTO_ATTACH=false"
alias zj="zellij"
alias zja="zellij attach"
alias zjl="zellij list-sessions"
alias ghostty-use-script='sed -i.bak "s|^#*initial-command.*|initial-command = /Users/jimmy/Programming/dotfiles/etc/scripts/ghostty_zellij_startup.sh|" $HOME/Programming/dotfiles/src/ghostty/config'
alias ghostty-use-zsh='sed -i.bak "s|^initial-command.*|# initial-command = zsh|" $HOME/Programming/dotfiles/src/ghostty/config'

# Catppuccin Umocha colors for fzf
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

# Uncomment the line below to enable auto-start in .zshrc
# zellij_auto_start

