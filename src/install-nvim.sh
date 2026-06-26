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

sudo apt-get update
sudo apt-get install -y neovim

echo "Installed $(nvim --version | head -n 1)"
