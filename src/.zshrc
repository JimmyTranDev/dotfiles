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

alias a='eval "$(poetry env activate)"'
alias c='clear'
alias e='exit'
alias worktrees='$HOME/Programming/dotfiles/etc/scripts/worktrees/worktree'
alias o='opencode'
alias g='grep -rnw . -e'
alias i="$HOME/Programming/dotfiles/etc/scripts/install/install.sh"
alias I="$HOME/Programming/dotfiles/etc/scripts/update_dotfiles.sh"
alias n='nvim'
alias w='yabai --restart-service; skhd --restart-service'
alias y='yazi'
alias z='zellij'
alias l='ls -la'
alias f="$HOME/Programming/dotfiles/etc/scripts/install/fetch_all_folders.sh $HOME/Programming"
alias x='find ~/Programming/dotfiles/etc/scripts -type f -name "*.sh" -exec chmod +x {} +'
alias k="$HOME/Programming/dotfiles/etc/scripts/kill_port.sh"
alias nvm='fnm'
alias wo='$HOME/Programming/dotfiles/etc/scripts/worktrees/worktree checkout'
alias wn='$HOME/Programming/dotfiles/etc/scripts/worktrees/worktree create'
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
  fzf_select_git_repos_and_worktrees_and_cd "Select git repo/worktree: " "$HOME/Worktrees" "$HOME/.last_worktree" "" 3
}
zle -N select_worktree
bindkey '^g' select_worktree

eval "$(starship init zsh)"
eval "$(fnm env --use-on-cd --shell zsh)"

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

