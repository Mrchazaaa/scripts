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

run_as_root() {
  if [[ "${SCRIPTS_RUN_AS_ROOT:-0}" == 1 || "$EUID" -eq 0 ]]; then
    "$@"
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required when not running as root." >&2
    exit 1
  fi

  sudo "$@"
}

run_as_root apt-get update
run_as_root apt-get install -y ca-certificates curl gnupg

run_as_root install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | run_as_root gpg --dearmor -o /etc/apt/keyrings/docker.gpg
run_as_root chmod a+r /etc/apt/keyrings/docker.gpg

os_release_file="${OS_RELEASE_FILE:-/etc/os-release}"
. "$os_release_file"
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
  | run_as_root tee /etc/apt/sources.list.d/docker.list >/dev/null

run_as_root apt-get update
run_as_root apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Installed $(docker --version)"
echo "To run docker without sudo, run: sudo usermod -aG docker \"$USER\""
echo "Then log out and back in."
