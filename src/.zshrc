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
HOMEBREW_PREFIX="$(brew --prefix)"

export BROWSER=google-chrome
export ARCHFLAGS="-arch $(uname -m)"
export MANPAGER='nvim +Man!'
export MANWIDTH=999
export ZELLIJ_TAB_NAME_MAX_LENGTH=4
export ESPANSO_CONFIG_DIR="$HOME/.config/espanso"
export HOMEBREW_AUTO_UPDATE_SECS=604800
export HOMEBREW_API_AUTO_UPDATE_SECS=604800
export PNPM_HOME="$HOME/Library/pnpm"

if [[ "$(uname)" == "Darwin" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/27.1.12297006"
  export MANPATH="/usr/local/man${MANPATH:+:$MANPATH}"
fi

export FZF_DEFAULT_OPTS="\
  --color=bg:#1e1e2e,fg:#cdd6f4,hl:#f38ba8 --color=fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8 --color=info:#89b4fa,prompt:#fab387,spinner:#f9e2af --color=header:#cba6f7,marker:#89dceb --color=border:#6c7086 \
"

export PATH="$HOMEBREW_PREFIX/opt/postgresql@15/bin:$PATH"

case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac

path_additions=(
  "$HOME/.local/bin"
  "$HOME/.local/share/pnpm"
  "$HOME/.lmstudio/bin"
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

if [[ -d "$HOMEBREW_PREFIX/Caskroom/gcloud-cli" ]]; then
  GCLOUD_SDK_DIR=($HOMEBREW_PREFIX/Caskroom/gcloud-cli/*/google-cloud-sdk(N/))
  if [[ ${#GCLOUD_SDK_DIR[@]} -gt 0 ]]; then
    source "${GCLOUD_SDK_DIR[-1]}/path.zsh.inc"
    source "${GCLOUD_SDK_DIR[-1]}/completion.zsh.inc"
  fi
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

alias c='clear'
alias g='rg'
alias n='nvim'
alias y='yazi'
alias z='zellij'
alias a='eval "$(poetry env activate)"'
alias d="$DOTFILES_DIR/etc/scripts/utils/git_diff_commits.sh"
alias k="$DOTFILES_DIR/etc/scripts/src/kill_port.sh"
alias l="$DOTFILES_DIR/etc/scripts/src/select_git_folder_actx.sh"
alias i='brew bundle --file=$DOTFILES_DIR/src/Brewfile --cleanup'

alias nvm='fnm'
alias js="$DOTFILES_DIR/etc/scripts/src/sdk_select.sh"
alias ji="$DOTFILES_DIR/etc/scripts/src/sdk_install.sh"
alias knip='pnpm dlx knip'
alias knipw='pnpm dlx knip --watch'
alias loc='git ls-files | rg -v "(^|/)(assets|data)/" | xargs wc -l'
alias csv='git ls-files "*/core/*.csv" 2>/dev/null | fzf --preview "head -20 {}" | xargs -r vd --csv-delimiter "|"'

alias wD='$DOTFILES_DIR/etc/scripts/src/worktrees/worktree delete'
alias wC='$DOTFILES_DIR/etc/scripts/src/worktrees/worktree clean'
alias wr='$DOTFILES_DIR/etc/scripts/src/worktrees/worktree rename'
alias wu='$DOTFILES_DIR/etc/scripts/src/worktrees/worktree update'

alias zja="zellij attach"
alias zjl="zellij list-sessions"

alias ghostty-use-script='sed -i "" "s|^#*initial-command.*|initial-command = $DOTFILES_DIR/etc/scripts/src/ghostty_zellij_startup.sh|" $DOTFILES_DIR/src/ghostty/config'
alias ghostty-use-zsh='sed -i "" "s|^initial-command.*|# initial-command = zsh|" $DOTFILES_DIR/src/ghostty/config'

if [[ "$(uname)" == "Darwin" ]]; then
  alias t='yabai --restart-service & skhd --restart-service & wait'
fi

alias P="$DOTFILES_DIR/etc/scripts/src/pull_repos.sh"
alias I="$DOTFILES_DIR/etc/scripts/src/install/install.sh"
alias L="$DOTFILES_DIR/etc/scripts/src/install/sync_links.sh"
alias N="$DOTFILES_DIR/etc/scripts/src/slack_post_prs.sh"
alias S="$DOTFILES_DIR/etc/scripts/src/sync_secrets.sh"
alias C='find "$DOTFILES_DIR/etc/scripts" -type f -name "*.sh" -exec chmod +x {} \;'

source "$DOTFILES_DIR/etc/scripts/utils/utility.sh"
source "$DOTFILES_DIR/etc/scripts/src/zshrc/opencode.sh"
source "$DOTFILES_DIR/etc/scripts/src/zshrc/worktree_helpers.sh"
source "$DOTFILES_DIR/etc/scripts/src/zshrc/select_project.sh"
source "$DOTFILES_DIR/etc/scripts/src/zshrc/select_worktree.sh"
source "$DOTFILES_DIR/etc/scripts/src/zshrc/select_projects_multi.sh"
source "$DOTFILES_DIR/etc/scripts/src/zshrc/select_worktrees_multi.sh"
source "$DOTFILES_DIR/etc/scripts/src/zshrc/zellij.sh"

bindkey '^f' select_project
bindkey '^g' select_worktree
bindkey '^[f' select_projects_multi
bindkey '^[g' select_worktrees_multi
bindkey '^u' zellij_update_tab_indexes
