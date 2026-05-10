#!/bin/bash

set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALL_DIR/../../utils/logging.sh"

has_systemd() {
	pidof systemd >/dev/null 2>&1
}

setup_pacman_keys() {
	if [[ -d /etc/pacman.d/gnupg ]]; then
		log_success "Pacman keyring already initialized"
	else
		log_info "Initializing pacman keyring..."
		sudo pacman-key --init
		sudo pacman-key --populate
	fi
	sudo pacman -Syu --needed --noconfirm archlinux-keyring
	log_success "Pacman keyring up to date"
}

install_paru() {
	if command -v paru >/dev/null 2>&1; then
		log_success "paru already installed"
		return
	fi
	log_info "Installing paru..."
	sudo pacman -S --needed --noconfirm base-devel
	local paru_dir
	paru_dir="$(mktemp -d)"
	git clone https://aur.archlinux.org/paru.git "$paru_dir"
	(cd "$paru_dir" && makepkg -si --noconfirm)
	rm -rf "$paru_dir"
	log_success "paru installed"
}

setup_ssh() {
	log_info "Setting up SSH..."
	sudo pacman -S --needed --noconfirm openssh
	if has_systemd; then
		sudo systemctl start sshd
		sudo systemctl enable sshd
		log_success "SSH daemon enabled"
	else
		log_warning "systemd not available, skipping sshd service"
	fi
}

setup_ssh_key() {
	if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
		log_success "SSH key already exists"
		return
	fi
	log_warning "Generating SSH key with no passphrase"
	local keygen_args=(-t ed25519 -f "$HOME/.ssh/id_ed25519" -N "")
	if [[ -n "${PRI_EMAIL:-}" ]]; then
		keygen_args+=(-C "$PRI_EMAIL")
	fi
	ssh-keygen "${keygen_args[@]}"
	eval "$(ssh-agent -s)"
	ssh-add "$HOME/.ssh/id_ed25519"
	log_success "SSH key generated"
	log_info "Add this public key to GitHub:"
	cat "$HOME/.ssh/id_ed25519.pub"
}

fix_x11_socket() {
	local service_file="/etc/systemd/system/x11-symlink.service"
	if ! has_systemd; then
		log_warning "systemd not available, skipping X11 socket fix"
		return
	fi
	if [[ -f "$service_file" ]]; then
		log_success "X11 socket symlink service already exists"
		return
	fi
	log_info "Creating X11 socket symlink service for WSLg..."
	sudo tee "$service_file" >/dev/null <<'UNIT'
[Unit]
Description=symlink /tmp/.X11-unix
After=systemd-tmpfiles-setup.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c "rm -rf /tmp/.X11-unix && ln -sf /mnt/wslg/.X11-unix /tmp/"

[Install]
WantedBy=sysinit.target
UNIT
	sudo systemctl enable x11-symlink.service
	log_success "X11 socket symlink service installed"
}

setup_docker() {
	if ! command -v docker >/dev/null 2>&1; then
		log_info "Installing docker..."
		sudo pacman -S --needed --noconfirm docker docker-compose
	fi
	if has_systemd; then
		sudo systemctl start docker.service
		sudo systemctl enable docker.service
	else
		log_warning "systemd not available, skipping docker service"
	fi
	if ! getent group docker | grep -q "$USER"; then
		sudo usermod -aG docker "$USER"
		log_info "Added $USER to docker group (re-login required)"
	fi
	log_success "Docker configured"
}

main() {
	log_header "Running WSL (Arch) setup..."

	setup_pacman_keys
	install_paru
	setup_ssh
	setup_ssh_key
	fix_x11_socket
	setup_docker

	log_success "WSL setup completed"
}

main "$@"
