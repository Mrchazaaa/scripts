#!/usr/bin/env bats

load test_helper

setup() {
  setup_fake_path
}

@test "install-git exits when git is already installed" {
  write_fake_command git

  run_install_script "$repo_root/src/install-git.sh"

  [ "$status" -eq 0 ]
  assert_output_contains "git is already installed: git version 2.45.0"
  refute_log_contains "sudo"
}

@test "install-git fails clearly without apt-get" {
  run_install_script "$repo_root/src/install-git.sh"

  [ "$status" -eq 1 ]
  assert_output_contains "This installer supports Debian/Ubuntu systems with apt-get."
}

@test "install-git installs git through apt" {
  write_fake_apt_get
  write_fake_sudo

  run_install_script "$repo_root/src/install-git.sh"

  [ "$status" -eq 0 ]
  assert_log_contains "sudo apt-get update"
  assert_log_contains "sudo apt-get install -y git"
  assert_output_contains "Installed git version 2.45.0"
}

@test "install-git installs git directly when running as root" {
  write_fake_apt_get

  run_install_script_as_root "$repo_root/src/install-git.sh"

  [ "$status" -eq 0 ]
  assert_log_contains "apt-get update"
  assert_log_contains "apt-get install -y git"
  refute_log_contains "sudo"
  assert_output_contains "Installed git version 2.45.0"
}
