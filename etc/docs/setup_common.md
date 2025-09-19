
# Common Setup

## SSH Key
```sh
ssh-keygen -t ed25519 -C $PRI_EMAIL
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

## Install

```sh
~/Programming/dotfiles/etc/scripts/install/clone_essential_repos.sh
~/Programming/dotfiles/etc/scripts/install/install.sh
```

## Sync secrets
1. Put env.sh file in ~/Programming/secrets/env.sh
1. Sync secrets with neovim
