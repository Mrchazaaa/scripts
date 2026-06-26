#!/usr/bin/env bash
set -euo pipefail

if command -v nvim >/dev/null 2>&1; then
  echo "nvim is already installed: $(nvim --version | head -n 1)"
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
run_as_root apt-get install -y neovim

echo "Installed $(nvim --version | head -n 1)"
