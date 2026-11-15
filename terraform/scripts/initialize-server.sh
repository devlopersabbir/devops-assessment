#!/usr/bin/env bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

# Add Docker's official GPG key:
sudo apt update -y
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
# shellcheck source=/dev/null
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update -y

# Install Docker packages:
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker

# Docker Linux post-installation steps (allow running `docker ps` without sudo)
sudo groupadd -f docker

# Ensure ssm-user exists before first SSM login so it gets added to the docker group at boot
if ! id -u ssm-user >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash ssm-user
fi

sudo usermod -aG docker "${USER:-root}"
sudo usermod -aG docker ssm-user
if id -u admin >/dev/null 2>&1; then
  sudo usermod -aG docker admin
fi

# Install and configure Caddy Server as reverse proxy to container port 8080
sudo apt install -y caddy

sudo tee /etc/caddy/Caddyfile <<'EOF'
:80 {
    reverse_proxy 127.0.0.1:8080
}
EOF

sudo systemctl enable --now caddy
sudo systemctl reload caddy || sudo systemctl restart caddy
