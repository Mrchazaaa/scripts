#!/usr/bin/env bats

load test_helper

setup() {
  setup_fake_path
}

@test "install-tmux exits when tmux is already installed" {
  write_fake_command tmux

  run_install_script "$repo_root/src/install-tmux.sh"

  [ "$status" -eq 0 ]
  assert_output_contains "tmux is already installed: tmux 3.4"
  refute_log_contains "sudo"
}

@test "install-tmux fails clearly without apt-get" {
  run_install_script "$repo_root/src/install-tmux.sh"

  [ "$status" -eq 1 ]
  assert_output_contains "This installer supports Debian/Ubuntu systems with apt-get."
}

@test "install-tmux installs tmux through apt" {
  write_fake_apt_get
  write_fake_sudo

  run_install_script "$repo_root/src/install-tmux.sh"

  [ "$status" -eq 0 ]
  assert_log_contains "sudo apt-get update"
  assert_log_contains "sudo apt-get install -y tmux"
  assert_output_contains "Installed tmux 3.4"
}

@test "install-tmux installs tmux directly when running as root" {
  write_fake_apt_get

  run_install_script_as_root "$repo_root/src/install-tmux.sh"

  [ "$status" -eq 0 ]
  assert_log_contains "apt-get update"
  assert_log_contains "apt-get install -y tmux"
  refute_log_contains "sudo"
  assert_output_contains "Installed tmux 3.4"
}
