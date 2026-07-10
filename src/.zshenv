# .zshenv is sourced by EVERY zsh invocation, including non-interactive
# `zsh -c "..."` shells (e.g. the ones zellij's `Run` keybinds spawn). PATH
# entries that tools launched outside an interactive shell must see belong
# here, NOT in .zshrc (which only interactive shells source). Keep this file
# fast and side-effect-free: only PATH/env, no completions or plugin init.

# User-local binaries (e.g. storecode, standalone CLIs). This must be visible
# to non-interactive shells so zellij launcher scripts can find these tools.
path_additions=(
  "$HOME/.local/bin"
  "$HOME/.local/share/pnpm"
  "$HOME/.lmstudio/bin"
)

if [[ "$(uname)" == "Darwin" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  path_additions+=(
    "$ANDROID_HOME/emulator"
    "$ANDROID_HOME/platform-tools"
  )
fi

for p in "${path_additions[@]}"; do
  [[ ":$PATH:" != *":$p:"* ]] && export PATH="$PATH:$p"
done
unset path_additions p
