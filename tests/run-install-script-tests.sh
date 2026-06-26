#!/usr/bin/env bash
set -u

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
tmp_root=""
failures=0

cleanup() {
  if [[ -n "$tmp_root" && -d "$tmp_root" ]]; then
    rm -rf "$tmp_root"
  fi
}
trap cleanup EXIT

tmp_root="$(mktemp -d)"

fail() {
  local message="$1"
  printf "not ok - %s\n" "$message"
  failures=$((failures + 1))
}

pass() {
  local message="$1"
  printf "ok - %s\n" "$message"
}

assert_status() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [[ "$actual" -ne "$expected" ]]; then
    fail "$message: expected status $expected, got $actual"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    fail "$message: expected to find '$needle'"
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    fail "$message: did not expect to find '$needle'"
    return 1
  fi
}

write_executable() {
  local path="$1"
  local content="$2"

  printf "%s\n" "$content" > "$path"
  chmod +x "$path"
}

write_fake_head() {
  local fake_bin="$1"

  write_executable "$fake_bin/head" '#!/bin/bash
IFS= read -r line || exit 0
printf "%s\n" "$line"'
}

write_target_command() {
  local fake_bin="$1"
  local command_name="$2"

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
      fail "unknown target command: $command_name"
      return 1
      ;;
  esac
}

write_fake_apt_get() {
  local fake_bin="$1"

  write_executable "$fake_bin/apt-get" '#!/bin/bash
printf "apt-get %s\n" "$*" >> "$TEST_LOG"'
}

write_fake_curl() {
  local fake_bin="$1"

  write_executable "$fake_bin/curl" '#!/bin/bash
printf "curl %s\n" "$*" >> "$TEST_LOG"
printf "fake docker gpg key\n"'
}

write_fake_dpkg() {
  local fake_bin="$1"

  write_executable "$fake_bin/dpkg" '#!/bin/bash
if [[ "$*" == "--print-architecture" ]]; then
  printf "amd64\n"
else
  printf "unexpected dpkg call: %s\n" "$*" >&2
  exit 1
fi'
}

write_fake_sudo() {
  local fake_bin="$1"

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

new_case_dir() {
  local name="$1"
  local case_dir

  case_dir="$tmp_root/$name"
  mkdir -p "$case_dir/bin"
  printf "%s\n" "$case_dir"
}

run_script_with_path() {
  local script="$1"
  local fake_bin="$2"
  local output_file="$3"
  local log_file="$4"
  local os_release_file="${5:-}"
  local status

  if [[ -n "$os_release_file" ]]; then
    (
      export PATH="$fake_bin"
      export FAKE_BIN="$fake_bin"
      export TEST_LOG="$log_file"
      export OS_RELEASE_FILE="$os_release_file"
      "$BASH" "$script"
    ) >"$output_file" 2>&1
  else
    (
      export PATH="$fake_bin"
      export FAKE_BIN="$fake_bin"
      export TEST_LOG="$log_file"
      "$BASH" "$script"
    ) >"$output_file" 2>&1
  fi
  status=$?
  return "$status"
}

script_path_for_target() {
  local target="$1"

  case "$target" in
    git)
      printf "%s/src/install-git.sh\n" "$repo_root"
      ;;
    tmux)
      printf "%s/src/install-tmux.sh\n" "$repo_root"
      ;;
    nvim)
      printf "%s/src/install-nvim.sh\n" "$repo_root"
      ;;
    docker)
      printf "%s/src/install-docker.sh\n" "$repo_root"
      ;;
  esac
}

package_for_target() {
  local target="$1"

  case "$target" in
    git)
      printf "git\n"
      ;;
    tmux)
      printf "tmux\n"
      ;;
    nvim)
      printf "neovim\n"
      ;;
    docker)
      printf "docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin\n"
      ;;
  esac
}

already_installed_message_for_target() {
  local target="$1"

  case "$target" in
    git)
      printf "git is already installed: git version 2.45.0\n"
      ;;
    tmux)
      printf "tmux is already installed: tmux 3.4\n"
      ;;
    nvim)
      printf "nvim is already installed: NVIM v0.10.0\n"
      ;;
    docker)
      printf "docker is already installed: Docker version 27.0.0, build test\n"
      ;;
  esac
}

installed_message_for_target() {
  local target="$1"

  case "$target" in
    git)
      printf "Installed git version 2.45.0\n"
      ;;
    tmux)
      printf "Installed tmux 3.4\n"
      ;;
    nvim)
      printf "Installed NVIM v0.10.0\n"
      ;;
    docker)
      printf "Installed Docker version 27.0.0, build test\n"
      ;;
  esac
}

test_already_installed() {
  local target="$1"
  local case_dir fake_bin output_file log_file output log status
  local test_name="${target}: exits when already installed"

  case_dir="$(new_case_dir "already-$target")"
  fake_bin="$case_dir/bin"
  output_file="$case_dir/output"
  log_file="$case_dir/log"
  : > "$log_file"

  write_target_command "$fake_bin" "$target"
  [[ "$target" == "nvim" ]] && write_fake_head "$fake_bin"

  run_script_with_path "$(script_path_for_target "$target")" "$fake_bin" "$output_file" "$log_file"
  status=$?
  output="$(<"$output_file")"
  log="$(<"$log_file")"

  assert_status 0 "$status" "$test_name" || return
  assert_contains "$output" "$(already_installed_message_for_target "$target")" "$test_name" || return
  assert_not_contains "$log" "sudo" "$test_name" || return
  pass "$test_name"
}

test_requires_apt_get() {
  local target="$1"
  local case_dir fake_bin output_file log_file output status
  local test_name="${target}: fails clearly without apt-get"

  case_dir="$(new_case_dir "no-apt-$target")"
  fake_bin="$case_dir/bin"
  output_file="$case_dir/output"
  log_file="$case_dir/log"
  : > "$log_file"

  run_script_with_path "$(script_path_for_target "$target")" "$fake_bin" "$output_file" "$log_file"
  status=$?
  output="$(<"$output_file")"

  assert_status 1 "$status" "$test_name" || return
  assert_contains "$output" "This installer supports Debian/Ubuntu systems with apt-get." "$test_name" || return
  pass "$test_name"
}

test_installs_expected_package() {
  local target="$1"
  local case_dir fake_bin output_file log_file os_release_file output log status package
  local test_name="${target}: installs expected package through apt"

  case_dir="$(new_case_dir "install-$target")"
  fake_bin="$case_dir/bin"
  output_file="$case_dir/output"
  log_file="$case_dir/log"
  os_release_file="$case_dir/os-release"
  : > "$log_file"

  printf "ID=ubuntu\nVERSION_CODENAME=jammy\n" > "$os_release_file"
  write_fake_apt_get "$fake_bin"
  write_fake_sudo "$fake_bin"
  [[ "$target" == "nvim" ]] && write_fake_head "$fake_bin"

  if [[ "$target" == "docker" ]]; then
    write_fake_curl "$fake_bin"
    write_fake_dpkg "$fake_bin"
  fi

  run_script_with_path "$(script_path_for_target "$target")" "$fake_bin" "$output_file" "$log_file" "$os_release_file"
  status=$?
  output="$(<"$output_file")"
  log="$(<"$log_file")"
  package="$(package_for_target "$target")"

  assert_status 0 "$status" "$test_name" || return
  assert_contains "$log" "sudo apt-get update" "$test_name" || return
  assert_contains "$log" "sudo apt-get install -y $package" "$test_name" || return
  assert_contains "$output" "$(installed_message_for_target "$target")" "$test_name" || return

  if [[ "$target" == "docker" ]]; then
    assert_contains "$log" "curl -fsSL https://download.docker.com/linux/ubuntu/gpg" "$test_name" || return
    assert_contains "$log" "sudo tee /etc/apt/sources.list.d/docker.list" "$test_name" || return
    assert_contains "$output" "To run docker without sudo" "$test_name" || return
  fi

  pass "$test_name"
}

targets=(git docker nvim tmux)
for target in "${targets[@]}"; do
  test_already_installed "$target"
  test_requires_apt_get "$target"
  test_installs_expected_package "$target"
done

if [[ "$failures" -gt 0 ]]; then
  printf "\n%s test(s) failed.\n" "$failures"
  exit 1
fi

printf "\nAll install script tests passed.\n"
