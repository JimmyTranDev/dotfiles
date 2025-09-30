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
alias worktrees='zsh $HOME/Programming/dotfiles/etc/scripts/worktrees.sh'
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
alias wo='source $HOME/Programming/dotfiles/etc/scripts/worktrees.sh checkout'
alias wn='source $HOME/Programming/dotfiles/etc/scripts/worktrees.sh create'
alias wD='source $HOME/Programming/dotfiles/etc/scripts/worktrees.sh delete'
alias wC='source $HOME/Programming/dotfiles/etc/scripts/worktrees.sh clean'
alias wr='source $HOME/Programming/dotfiles/etc/scripts/worktrees.sh rename'
alias vsc='cd ~/Library/Application\ Support/Code/User/'

source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"

select_project() {
  fzf_select_git_repo_and_cd "Select project git repository: " "$HOME/Programming" "$HOME/.last_project" "nvim" 3
}
zle -N select_project
bindkey '^f' select_project

select_worktree() {
  fzf_select_git_repos_and_worktrees_and_cd "Select git repo/worktree: " "$HOME/Worktrees" "$HOME/.last_worktree" "nvim" 3
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

# Catppuccin Umocha colors for fzf
export FZF_DEFAULT_OPTS="\
  --color=bg:#1e1e2e,fg:#cdd6f4,hl:#f38ba8 --color=fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8 --color=info:#89b4fa,prompt:#fab387,spinner:#f9e2af --color=header:#cba6f7,marker:#89dceb --color=border:#6c7086 \
"

