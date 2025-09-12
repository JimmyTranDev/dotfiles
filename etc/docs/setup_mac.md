# This script is used to setup a new mac machine

## Install brew

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## Common Setup
[Common Setup](setup_common.md)

## Start services

```sh
skhd --start-service
yabai --start-service
```
