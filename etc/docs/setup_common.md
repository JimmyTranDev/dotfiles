
# Common Setup

## SSH Key
```sh
ssh-keygen -t ed25519 -C $PRI_EMAIL
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

## Install

```sh
~/Programming/JimmyTranDev/dotfiles/etc/scripts/install/clone_essential_repos.sh
~/Programming/JimmyTranDev/dotfiles/etc/scripts/install.sh
```
