#!/usr/bin/env bash
set -euo pipefail

if command -v tmux >/dev/null 2>&1; then
  echo "tmux is already installed: $(tmux -V)"
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This installer supports Debian/Ubuntu systems with apt-get." >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y tmux

echo "Installed $(tmux -V)"
