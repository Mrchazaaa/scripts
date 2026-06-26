#!/usr/bin/env bash
set -euo pipefail

if command -v docker >/dev/null 2>&1; then
  echo "docker is already installed: $(docker --version)"
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This installer supports Debian/Ubuntu systems with apt-get." >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release
codename="${VERSION_CODENAME:-}"
if [[ -z "$codename" ]]; then
  echo "Could not determine Ubuntu/Debian codename from /etc/os-release." >&2
  exit 1
fi

case "${ID:-}" in
  ubuntu|debian)
    docker_repo_os="$ID"
    ;;
  *)
    echo "This installer supports Ubuntu and Debian. Detected: ${ID:-unknown}" >&2
    exit 1
    ;;
esac

arch="$(dpkg --print-architecture)"
echo \
  "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${docker_repo_os} ${codename} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Installed $(docker --version)"
echo "To run docker without sudo, run: sudo usermod -aG docker \"$USER\""
echo "Then log out and back in."
