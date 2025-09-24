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
  local all_projects
  all_projects=($(ls -d "$HOME/Programming"/*/ | sed "s#$HOME/Programming/##;s#/##" | sort))
  fzf_select_and_cd "Select project: " "$HOME/Programming" "$HOME/.last_project" "nvim" "${all_projects[@]}"
  nvim
}
zle -N select_project
bindkey '^f' select_project

select_worktree() {
  local all_worktrees
  all_worktrees=($(find "$HOME/Worktrees" -mindepth 1 -maxdepth 1 -type d | xargs -n1 basename | sort))
  fzf_select_and_cd "Select a worktree folder: " "$HOME/Worktrees" "$HOME/.last_worktree" "" "${all_worktrees[@]}"
  nvim
}
zle -N select_worktree
bindkey '^g' select_worktree

select_profile_folder() {
  local all_profiles
  all_profiles=($(ls -d "$HOME/Programming/profile"/*/ 2>/dev/null | xargs -n1 basename | sort))
  fzf_select_and_cd "Select profile folder: " "$HOME/Programming/profile" "$HOME/.last_profile" "" "${all_profiles[@]}"
  nvim
}
zle -N select_profile_folder
bindkey '^p' select_profile_folder

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

# Catppuccin Latte colors for fzf
export FZF_DEFAULT_OPTS="\
  --color=bg:#e1e2e7,fg:#4c4f69,hl:#d20f39 \
  --color=fg+:#4c4f69,bg+:#f5e0dc,hl+:#d20f39 \
  --color=info:#1e66f5,prompt:#fe640b,spinner:#df8e1d \
  --color=header:#8839ef,marker:#179299 \
  --color=border:#dce0e8 \
"
