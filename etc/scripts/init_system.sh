sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
git clone git@github.com:JimmyTranDev/nvim-config.git $HOME/Programming/nvim
git clone git@github.com:JimmyTranDev/dotfiles.git $HOME/Programming/dotfiles
$HOME/Programming/dotfiles/etc/scripts/sync_links.sh
$HOME/Programming/dotfiles/etc/scripts/sync_secrets.sh
$HOME/Programming/dotfiles/etc/scripts/sync_packages.sh.sh
