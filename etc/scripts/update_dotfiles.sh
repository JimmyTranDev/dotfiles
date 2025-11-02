ya pack --upgrade
nvim --headless "+Lazy! update" +qa
nvim --headless "+MasonUpdate" +qa
git -C ~/Programming/dotfiles pull

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
