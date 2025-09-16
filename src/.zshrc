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
alias wc='$HOME/Programming/dotfiles/etc/scripts/create_worktree.sh'
alias wD='$HOME/Programming/dotfiles/etc/scripts/delete_worktree.sh'
alias c='clear'
alias e='exit'
alias g='grep -rnw . -e'
alias i="$HOME/Programming/dotfiles/etc/scripts/install.sh"
alias I="$HOME/Programming/dotfiles/etc/scripts/update_dotfiles.sh"
alias n='nvim'
alias w='yabai --restart-service; skhd --restart-service'
alias y='yazi'
alias z='zellij'
alias l='ls -la'
alias f="$HOME/Programming/dotfiles/etc/scripts/fetch_all_folders.sh $HOME/Programming"
alias x='chmod +x ~/Programming/dotfiles/etc/scripts/*.sh'
alias k="$HOME/Programming/dotfiles/etc/scripts/kill_port.sh"
alias nvm='fnm'

select_project() {
  local selected_project
  selected_project=$(ls ~/Programming/ | fzf)
  [[ -n $selected_project ]] && cd "$HOME/Programming/$selected_project" && nvim
}
zle -N select_project
bindkey '^f' select_project

select_worktree() {
  local folder
    local folder_name folder_path
    folder_name=$(find "$HOME/Worktrees" -mindepth 1 -maxdepth 1 -type d | xargs -n1 basename | fzf --prompt="Select a worktree folder: ")
    if [[ -n "$folder_name" ]]; then
      folder_path="$HOME/Worktrees/$folder_name"
      cd "$folder_path"
    else
      echo "No folder selected."
      return 1
  fi
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
