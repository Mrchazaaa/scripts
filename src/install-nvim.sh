#!/usr/bin/env bash
set -euo pipefail

install_config="${INSTALL_NVIM_CONFIG:-}"
vimconfig_repo="https://github.com/Mrchazaaa/vimconfig.git"

usage() {
  printf "%s\n" \
    "Usage: install-nvim.sh [--with-vimconfig]" \
    "" \
    "Options:" \
    "  --with-vimconfig  Install the nvim config from ${vimconfig_repo}." \
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

config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
nvim_config_dir="${config_home}/nvim"
vimconfig_dir="${VIMCONFIG_INSTALL_DIR:-${nvim_config_dir}/vimconfig}"

if command -v git >/dev/null 2>&1; then
  git_installed=1
fi

needs_apt=0
if [[ "$nvim_installed" -eq 0 || ( "$install_config" == 1 && ! -d "$vimconfig_dir/.git" && "$git_installed" -eq 0 ) ]]; then
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

  if [[ "$install_config" == 1 && ! -d "$vimconfig_dir/.git" && "$git_installed" -eq 0 ]]; then
    packages+=(git)
  fi

  run_as_root apt-get update
  run_as_root apt-get install -y "${packages[@]}"

  if [[ "$nvim_installed" -eq 0 ]]; then
    echo "Installed $(nvim --version | head -n 1)"
  fi
fi

if [[ "$install_config" == 1 ]]; then
  if [[ -d "$vimconfig_dir/.git" ]]; then
    echo "vimconfig checkout already exists at ${vimconfig_dir}; leaving it unchanged."
  else
    if [[ -e "$vimconfig_dir" ]]; then
      echo "${vimconfig_dir} already exists but is not a Git checkout. Move it aside or set VIMCONFIG_INSTALL_DIR to another path." >&2
      exit 1
    fi

    vimconfig_parent="${vimconfig_dir%/*}"
    if [[ "$vimconfig_parent" == "$vimconfig_dir" ]]; then
      vimconfig_parent="."
    fi

    /bin/mkdir -p "$vimconfig_parent"
    git clone "$vimconfig_repo" "$vimconfig_dir"
  fi

  if [[ ! -x "$vimconfig_dir/install.sh" ]]; then
    echo "vimconfig installer not found or not executable: ${vimconfig_dir}/install.sh" >&2
    exit 1
  fi

  VIMCONFIG_INSTALL_DIR="$vimconfig_dir" "$vimconfig_dir/install.sh" --nvim
  echo "Installed nvim config from ${vimconfig_repo} to ${vimconfig_dir}"
fi
