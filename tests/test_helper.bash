#!/usr/bin/env bash

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"

setup_fake_path() {
  case_dir="${BATS_TEST_TMPDIR:-$BATS_TMPDIR/$BATS_TEST_NAME}"
  fake_bin="$case_dir/bin"
  log_file="$case_dir/log"
  os_release_file="$case_dir/os-release"

  mkdir -p "$fake_bin"
  : > "$log_file"
}

write_executable() {
  local path="$1"
  local content="$2"

  printf "%s\n" "$content" > "$path"
  chmod +x "$path"
}

write_fake_head() {
  write_executable "$fake_bin/head" '#!/bin/bash
IFS= read -r line || exit 0
printf "%s\n" "$line"'
}

write_fake_command() {
  local command_name="$1"

  case "$command_name" in
    git)
      write_executable "$fake_bin/git" '#!/bin/bash
printf "git version 2.45.0\n"'
      ;;
    tmux)
      write_executable "$fake_bin/tmux" '#!/bin/bash
printf "tmux 3.4\n"'
      ;;
    nvim)
      write_executable "$fake_bin/nvim" '#!/bin/bash
printf "NVIM v0.10.0\nBuild type: Release\n"'
      ;;
    docker)
      write_executable "$fake_bin/docker" '#!/bin/bash
printf "Docker version 27.0.0, build test\n"'
      ;;
    *)
      printf "unknown fake command: %s\n" "$command_name" >&2
      return 1
      ;;
  esac
}

write_fake_apt_get() {
  write_executable "$fake_bin/apt-get" '#!/bin/bash
printf "apt-get %s\n" "$*" >> "$TEST_LOG"'
}

write_fake_curl() {
  write_executable "$fake_bin/curl" '#!/bin/bash
printf "curl %s\n" "$*" >> "$TEST_LOG"
printf "fake docker gpg key\n"'
}

write_fake_dpkg() {
  write_executable "$fake_bin/dpkg" '#!/bin/bash
if [[ "$*" == "--print-architecture" ]]; then
  printf "amd64\n"
else
  printf "unexpected dpkg call: %s\n" "$*" >&2
  exit 1
fi'
}

write_fake_sudo() {
  write_executable "$fake_bin/sudo" '#!/bin/bash
printf "sudo %s\n" "$*" >> "$TEST_LOG"

if [[ "$1" == "tee" ]]; then
  /bin/cat >/dev/null
fi

if [[ "$1" == "gpg" ]]; then
  /bin/cat >/dev/null
fi

if [[ "$1" == "apt-get" && "$2" == "install" ]]; then
  shift 2
  for package in "$@"; do
    case "$package" in
      git)
        /bin/cat > "$FAKE_BIN/git" <<'"'"'SCRIPT'"'"'
#!/bin/bash
printf "git version 2.45.0\n"
SCRIPT
        /bin/chmod +x "$FAKE_BIN/git"
        ;;
      tmux)
        /bin/cat > "$FAKE_BIN/tmux" <<'"'"'SCRIPT'"'"'
#!/bin/bash
printf "tmux 3.4\n"
SCRIPT
        /bin/chmod +x "$FAKE_BIN/tmux"
        ;;
      neovim)
        /bin/cat > "$FAKE_BIN/nvim" <<'"'"'SCRIPT'"'"'
#!/bin/bash
printf "NVIM v0.10.0\nBuild type: Release\n"
SCRIPT
        /bin/chmod +x "$FAKE_BIN/nvim"
        ;;
      docker-ce)
        /bin/cat > "$FAKE_BIN/docker" <<'"'"'SCRIPT'"'"'
#!/bin/bash
printf "Docker version 27.0.0, build test\n"
SCRIPT
        /bin/chmod +x "$FAKE_BIN/docker"
        ;;
    esac
  done
fi'
}

write_os_release() {
  printf "ID=%s\nVERSION_CODENAME=%s\n" "${1:-ubuntu}" "${2:-jammy}" > "$os_release_file"
}

run_install_script() {
  local script="$1"

  if [[ -f "$os_release_file" ]]; then
    run env \
      PATH="$fake_bin" \
      FAKE_BIN="$fake_bin" \
      TEST_LOG="$log_file" \
      OS_RELEASE_FILE="$os_release_file" \
      "$BASH" "$script"
  else
    run env \
      PATH="$fake_bin" \
      FAKE_BIN="$fake_bin" \
      TEST_LOG="$log_file" \
      "$BASH" "$script"
  fi
}

test_log() {
  cat "$log_file"
}

assert_output_contains() {
  local expected="$1"

  if [[ "$output" != *"$expected"* ]]; then
    printf "expected output to contain: %s\n" "$expected" >&2
    printf "actual output:\n%s\n" "$output" >&2
    return 1
  fi
}

assert_log_contains() {
  local expected="$1"
  local log

  log="$(test_log)"
  if [[ "$log" != *"$expected"* ]]; then
    printf "expected log to contain: %s\n" "$expected" >&2
    printf "actual log:\n%s\n" "$log" >&2
    return 1
  fi
}

refute_log_contains() {
  local unexpected="$1"
  local log

  log="$(test_log)"
  if [[ "$log" == *"$unexpected"* ]]; then
    printf "did not expect log to contain: %s\n" "$unexpected" >&2
    printf "actual log:\n%s\n" "$log" >&2
    return 1
  fi
}
