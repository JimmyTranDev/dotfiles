ya pack --upgrade
nvim --headless "+Lazy! update" +qa
nvim --headless "+MasonUpdate" +qa
git -C ~/Programming/dotfiles pull

# Link opencode config
if [ -f ~/Programming/dotfiles/src/opencode/opencode.json ]; then
    mkdir -p ~/.config/opencode
    ln -sf ~/Programming/dotfiles/src/opencode/opencode.json ~/.config/opencode/opencode.json
    echo "OpenCode config linked"
fi

nvim --headless +"MasonInstall \
bash-language-server \
black \
css-lsp \
eslint-lsp \
gopls \
html-lsp \
json-lsp \
lua-language-server \
marksman \
pyright \
tailwindcss-language-server \
typescript-language-server" +qall
