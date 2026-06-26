#!/usr/bin/env bats

load test_helper

setup() {
  setup_fake_path
  write_fake_head
}

@test "install-nvim exits when nvim is already installed" {
  write_fake_command nvim

  run_install_script "$repo_root/src/install-nvim.sh"

  [ "$status" -eq 0 ]
  assert_output_contains "nvim is already installed: NVIM v0.10.0"
  refute_log_contains "sudo"
}

@test "install-nvim fails clearly without apt-get" {
  run_install_script "$repo_root/src/install-nvim.sh"

  [ "$status" -eq 1 ]
  assert_output_contains "This installer supports Debian/Ubuntu systems with apt-get."
}

@test "install-nvim installs neovim through apt" {
  write_fake_apt_get
  write_fake_sudo

  run_install_script "$repo_root/src/install-nvim.sh"

  [ "$status" -eq 0 ]
  assert_log_contains "sudo apt-get update"
  assert_log_contains "sudo apt-get install -y neovim"
  assert_output_contains "Installed NVIM v0.10.0"
}

@test "install-nvim installs neovim directly when running as root" {
  write_fake_apt_get

  run_install_script_as_root "$repo_root/src/install-nvim.sh"

  [ "$status" -eq 0 ]
  assert_log_contains "apt-get update"
  assert_log_contains "apt-get install -y neovim"
  refute_log_contains "sudo"
  assert_output_contains "Installed NVIM v0.10.0"
}
