#!/bin/bash

set -euo pipefail
exec 1> >(stdbuf -oL cat) 2>&1

USERNAME="$(whoami)"

printf "\n-- Passwordless sudo '$USERNAME'"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USERNAME > /dev/null
chmod 440 /etc/sudoers.d/$USERNAME

printf "\n-- Fix SSH"
sshd_config="/etc/ssh/sshd_config"

cp --update=none $sshd_config ${sshd_config}.bak

sed -i 's/^#\?\s*PermitRootLogin .*/PermitRootLogin no/' $sshd_config
sed -i 's/^#\?\s*PasswordAuthentication .*/PasswordAuthentication no/' $sshd_config
sed -i 's/^#\?\s*UsePAM .*/UsePAM yes/' $sshd_config 

printf "\n-- Restart SSH"
systemctl restart ssh

printf "\n-- Install Docker\n"

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


printf "\n-- Adding '$USERNAME' to docker group"
sudo usermod -aG docker "$USERNAME"

printf "\n[✔] Docker installed and user '$USERNAME' now in docker group\n"

# Cilium CLI
printf "\n-- Install Cilium CLI\n"

CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

printf "\n[✔] Cilium CLI installed"