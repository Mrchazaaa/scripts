#!/usr/bin/env bats

load test_helper

setup() {
  setup_fake_path
}

@test "install-docker exits when docker is already installed" {
  write_fake_command docker

  run_install_script "$repo_root/src/install-docker.sh"

  [ "$status" -eq 0 ]
  assert_output_contains "docker is already installed: Docker version 27.0.0, build test"
  refute_log_contains "sudo"
}

@test "install-docker fails clearly without apt-get" {
  run_install_script "$repo_root/src/install-docker.sh"

  [ "$status" -eq 1 ]
  assert_output_contains "This installer supports Debian/Ubuntu systems with apt-get."
}

@test "install-docker installs docker through apt and configures the Docker repo" {
  write_os_release ubuntu jammy
  write_fake_apt_get
  write_fake_curl
  write_fake_dpkg
  write_fake_sudo

  run_install_script "$repo_root/src/install-docker.sh"

  [ "$status" -eq 0 ]
  assert_log_contains "sudo apt-get update"
  assert_log_contains "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
  assert_log_contains "curl -fsSL https://download.docker.com/linux/ubuntu/gpg"
  assert_log_contains "sudo tee /etc/apt/sources.list.d/docker.list"
  assert_output_contains "Installed Docker version 27.0.0, build test"
  assert_output_contains "To run docker without sudo"
}
