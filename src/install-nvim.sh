#!/usr/bin/env bash
set -euo pipefail

install_config="${INSTALL_NVIM_CONFIG:-}"
vimconfig_repo="https://github.com/Mrchazaaa/vimconfig"

usage() {
  printf "%s\n" \
    "Usage: install-nvim.sh [--with-vimconfig]" \
    "" \
    "Options:" \
    "  --with-vimconfig  Clone ${vimconfig_repo} into the nvim config directory." \
    "  -h, --help        Show this help message." \
    "" \
    "You can also set INSTALL_NVIM_CONFIG=1 to install the config or 0 to skip the prompt."
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --with-vimconfig|--with-config)
      install_config=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

prompt_for_vimconfig() {
  local answer

  if [[ -n "$install_config" ]]; then
    return
  fi

  if ! { exec 3<>/dev/tty; } 2>/dev/null; then
    install_config=0
    return
  fi

  printf "Install nvim config from %s? [y/N] " "$vimconfig_repo" >&3
  IFS= read -r answer <&3 || answer=""
  exec 3>&-

  case "$answer" in
    y|Y|yes|YES|Yes)
      install_config=1
      ;;
    *)
      install_config=0
      ;;
  esac
}

nvim_installed=0
git_installed=0

if command -v nvim >/dev/null 2>&1; then
  nvim_installed=1
  echo "nvim is already installed: $(nvim --version | head -n 1)"
fi

prompt_for_vimconfig

if command -v git >/dev/null 2>&1; then
  git_installed=1
fi

needs_apt=0
if [[ "$nvim_installed" -eq 0 || ( "$install_config" == 1 && "$git_installed" -eq 0 ) ]]; then
  needs_apt=1
fi

if [[ "$needs_apt" -eq 1 ]] && ! command -v apt-get >/dev/null 2>&1; then
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

if [[ "$needs_apt" -eq 1 ]]; then
  packages=()

  if [[ "$nvim_installed" -eq 0 ]]; then
    packages+=(neovim)
  fi

  if [[ "$install_config" == 1 && "$git_installed" -eq 0 ]]; then
    packages+=(git)
  fi

  run_as_root apt-get update
  run_as_root apt-get install -y "${packages[@]}"

  if [[ "$nvim_installed" -eq 0 ]]; then
    echo "Installed $(nvim --version | head -n 1)"
  fi
fi

if [[ "$install_config" == 1 ]]; then
  config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
  nvim_config_dir="${config_home}/nvim"

  if [[ -e "$nvim_config_dir" ]]; then
    echo "nvim config already exists at ${nvim_config_dir}; leaving it unchanged."
    exit 0
  fi

  /bin/mkdir -p "$config_home"
  git clone "$vimconfig_repo" "$nvim_config_dir"
  echo "Installed nvim config from ${vimconfig_repo} to ${nvim_config_dir}"
fi
