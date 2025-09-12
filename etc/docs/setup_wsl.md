# Setup Arch Linux on WSL
https://wsldl-pg.github.io/ArchW-docs/How-to-Setup/

## Arch Setup

### Install Wsl

1. Install windows terminal from the windows store

```powershell
wsl --install
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
windows_install.ps
```

### Set Password

```sh
passwd
```

### Create User

```powershell
<!-- Default user -->
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
useradd -m -G wheel -s /bin/bash jimmy
Arch.exe config --default-user jimmy
passwd jimmy
```

### Pacman

```sh
sudo pacman-key --init
sudo pacman-key --populate
sudo pacman -Sy archlinux-keyring
sudo pacman -Su
```

### SSH

```sh
sudo pacman -S git
sudo pacman -S openssh
sudo systemctl start sshd
sudo systemctl enable sshd
```

### SSH Key

```sh
ssh-keygen -t ed25519 -C $PRI_EMAIL
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Paru

```sh
sudo pacman -S --needed base-devel
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

### Make Gui Work

```sh
  rmdir /tmp/.X11-unix && ln -s /mnt/wslg/.X11-unix /tmp/.X11-unix
```

https://superuser.com/questions/1617298/wsl-2-running-ubuntu-x-server-cant-open-display/1834709#1834709

```
[Unit]
Description=symlink /tmp/.X11-unix
After=systemd-tmpfiles-setup.service

[Service]
Type=oneshot
ExecStart=rmdir /tmp/.X11-unix
ExecStart=ln -s /mnt/wslg/.X11-unix /tmp/

[Install]
WantedBy=sysinit.target
```

### Docker
sudo systemctl start docker.service

### Fonts

1. Install `Fira Code` at https://www.nerdfonts.com/font-downloads
2. Change fonr in windows terminal to `Fira Code`

## Common Setup

[Common Setup](./setup_common.md)

