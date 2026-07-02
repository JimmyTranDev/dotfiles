HISTFILE="${HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY

autoload -Uz compinit
# Run the full security audit + rebuild at most once every 24h; otherwise load
# the cached dump (-C skips the audit). Compile the dump to wordcode so the next
# shell starts faster.
zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ -n "$zcompdump"(#qN.mh+24) ]]; then
  compinit -d "$zcompdump"
else
  compinit -C -d "$zcompdump"
fi
if [[ -s "$zcompdump" && ( ! -s "$zcompdump.zwc" || "$zcompdump" -nt "$zcompdump.zwc" ) ]]; then
  zcompile -R -- "$zcompdump.zwc" "$zcompdump" 2>/dev/null
fi
unset zcompdump

DOTFILES_DIR="$HOME/Programming/JimmyTranDev/dotfiles"
if [[ "$(uname -m)" == "arm64" ]]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi

export BROWSER='firefox'
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
  --color=bg:#1e1e2e,fg:#cdd6f4,hl:#f38ba8 --color=fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8 --color=info:#89b4fa,prompt:#fab387,spinner:#f9e2af --color=header:#94e2d5,marker:#89dceb --color=border:#6c7086 \
"

export PATH="$HOMEBREW_PREFIX/opt/postgresql@15/bin:$PATH"

case ":$PATH:" in
*":$PNPM_HOME/bin:"*) ;;
*) export PATH="$PNPM_HOME/bin:$PATH" ;;
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

export SDKMAN_DIR="$HOME/.sdkman"
if [[ -d "$SDKMAN_DIR" ]]; then
  # Put the selected candidate bins on PATH now (cheap), but defer the slow
  # sdkman-init.sh until `sdk` is first invoked.
  for _sdk_bin in "$SDKMAN_DIR"/candidates/*/current/bin(N/); do
    path=("$_sdk_bin" $path)
  done
  unset _sdk_bin
  if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    sdk() { unset -f sdk; source "$SDKMAN_DIR/bin/sdkman-init.sh"; sdk "$@"; }
  fi
fi
[[ -f "$HOME/Programming/JimmyTranDev/secrets/env.sh" ]] && source "$HOME/Programming/JimmyTranDev/secrets/env.sh"

# gcloud CLI: run on Homebrew's Python 3.14 instead of system Python.
export CLOUDSDK_PYTHON="$HOMEBREW_PREFIX/opt/python@3.14/bin/python3.14"

if [[ -d "$HOMEBREW_PREFIX/Caskroom/gcloud-cli" ]]; then
  GCLOUD_SDK_DIR=($HOMEBREW_PREFIX/Caskroom/gcloud-cli/*/google-cloud-sdk(N/))
  if [[ ${#GCLOUD_SDK_DIR[@]} -gt 0 ]]; then
    source "${GCLOUD_SDK_DIR[-1]}/path.zsh.inc"
    source "${GCLOUD_SDK_DIR[-1]}/completion.zsh.inc"
  fi
fi

# Cache the (static) output of shell-init hooks so we do not fork a subprocess
# on every startup; regenerate only when the tool's binary is newer than the
# cache (e.g. after an upgrade).
_cache_eval() {
  local name=$1 bin=$2
  shift 2
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/${name}.zsh"
  local binpath
  binpath=$(command -v "$bin") || return
  if [[ ! -s "$cache" || "$binpath" -nt "$cache" ]]; then
    mkdir -p "${cache:h}"
    "$binpath" "$@" >| "$cache"
  fi
  source "$cache"
}

if command -v starship >/dev/null 2>&1; then
  _cache_eval starship starship init zsh
fi

if command -v fnm >/dev/null 2>&1; then
  # fnm env emits a per-shell FNM_MULTISHELL_PATH, so it must run live (uncached).
  eval "$(fnm env --use-on-cd --version-file-strategy=local --resolve-engines --shell zsh)"
  if [[ -f .nvmrc || -f .node-version ]]; then
    fnm use --install-if-missing >/dev/null 2>&1
  fi
fi

if command -v zoxide >/dev/null 2>&1; then
  _cache_eval zoxide zoxide init zsh
fi

alias c='clear'
alias g='rg'
alias n='nvim'
y() {
  # Open yazi. Press `o` inside to cd here and launch Neovim; `q` quits normally.
  local open_file dir
  open_file="$(mktemp -t yazi-open.XXXXXX)" || return
  YAZI_OPEN_FILE="$open_file" yazi "$@"
  dir="$(command cat -- "$open_file" 2>/dev/null)"
  command rm -f -- "$open_file"
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    builtin cd -- "$dir" || return
    nvim
  fi
}
alias z='zellij'
alias a='eval "$(poetry env activate)"'
alias d="$DOTFILES_DIR/etc/scripts/utils/git_diff_commits.sh"
alias too="$DOTFILES_DIR/etc/scripts/src/git_diff_base.sh"
alias k="$DOTFILES_DIR/etc/scripts/src/kill_port.sh"
alias l="$DOTFILES_DIR/etc/scripts/src/select_git_folder_actx.sh"
alias i='brew bundle --file=$DOTFILES_DIR/src/Brewfile --cleanup'

alias nvm='fnm'
alias js="$DOTFILES_DIR/etc/scripts/src/sdk_select.sh"
alias ji="$DOTFILES_DIR/etc/scripts/src/sdk_install.sh"
alias knip='pnpm dlx knip'
alias knipw='pnpm dlx knip --watch'
alias loc='git ls-files | rg -v "(^|/)(assets|data)/" | xargs wc -l'
alias locp='git ls-files --cached --others --exclude-standard -z | xargs -0 wc -l | tail -1'
alias csv='git ls-files "*/core/*.csv" 2>/dev/null | fzf --preview "head -20 {}" | xargs -r vd --csv-delimiter "|"'
alias google-chrome='"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"'

alias wl='$DOTFILES_DIR/etc/scripts/src/worktrees/worktree list'
alias wd='$DOTFILES_DIR/etc/scripts/src/worktrees/worktree diff'
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
source "$DOTFILES_DIR/etc/scripts/src/zshrc/project_worktree_common.sh"
source "$DOTFILES_DIR/etc/scripts/src/zshrc/select_project_worktree.sh"
source "$DOTFILES_DIR/etc/scripts/src/zshrc/select_project_opencode.sh"
source "$DOTFILES_DIR/etc/scripts/src/zshrc/select_project_nvim.sh"
source "$DOTFILES_DIR/etc/scripts/src/zshrc/select_projects_worktrees_multi.sh"
source "$DOTFILES_DIR/etc/scripts/src/zshrc/zellij.sh"

bindkey '^f' select_project_worktree
bindkey '^o' select_project_opencode_widget
bindkey '^n' select_project_nvim_widget
bindkey '^[f' select_projects_worktrees_multi
bindkey '^u' zellij_update_tab_indexes
