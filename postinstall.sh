#!/bin/bash

set -euo pipefail
exec 1> >(stdbuf -oL cat) 2>&1

USERNAME="$(whoami)" # or better change

printf "\n-- Passwordless sudo for '$USERNAME'\n"
if [ ! -f /etc/sudoers.d/$USERNAME ]; then
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USERNAME > /dev/null
  sudo chmod 440 /etc/sudoers.d/$USERNAME
else
  echo "[!] Sudoers entry for '$USERNAME' already exists, skipping"
fi

printf "\n-- Fix SSH\n"
sshd_config="/etc/ssh/sshd_config"
if [ ! -f "${sshd_config}.bak" ]; then
  sudo cp $sshd_config ${sshd_config}.bak
  sudo sed -i 's/^#\?\s*PermitRootLogin .*/PermitRootLogin no/' $sshd_config
  sudo sed -i 's/^#\?\s*PasswordAuthentication .*/PasswordAuthentication no/' $sshd_config
  sudo sed -i 's/^#\?\s*UsePAM .*/UsePAM yes/' $sshd_config
  sudo systemctl restart ssh
else
  echo "[!] SSH already configured (backup exists), skipping"
fi

# Docker
printf "\n-- Install Docker\n"
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg lsb-release

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USERNAME"
  echo "[✔] Docker installed"
else
  echo "[!] Docker already installed, skipping"
fi

# Cilium CLI
printf "\n-- Install Cilium CLI\n"
if ! command -v cilium >/dev/null 2>&1; then
  CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
  CLI_ARCH=amd64
  if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
  curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
  sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
  sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
  rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
  echo "[✔] Cilium CLI installed"
else
  echo "[!] Cilium CLI already installed, skipping"
fi

# Helm
printf "\n-- Install Helm\n"
if ! command -v helm >/dev/null 2>&1; then
  curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
  sudo apt-get install -y apt-transport-https
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] \
    https://baltocdn.com/helm/stable/debian/ all main" | \
    sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

  sudo apt-get update
  sudo apt-get install -y helm
  echo "[✔] Helm installed"
else
  echo "[!] Helm already installed, skipping"
fi
