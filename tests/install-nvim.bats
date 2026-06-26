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
  refute_log_contains "git clone"
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

@test "install-nvim optionally installs vimconfig with flag" {
  write_fake_apt_get
  write_fake_sudo

  run_install_script "$repo_root/src/install-nvim.sh" --with-vimconfig

  [ "$status" -eq 0 ]
  assert_log_contains "sudo apt-get update"
  assert_log_contains "sudo apt-get install -y neovim git"
  assert_log_contains "git clone https://github.com/Mrchazaaa/vimconfig.git $case_dir/config/nvim/vimconfig"
  assert_log_contains "vimconfig install.sh VIMCONFIG_INSTALL_DIR=$case_dir/config/nvim/vimconfig args=--nvim"
  assert_output_contains "Installed NVIM v0.10.0"
  assert_output_contains "Installed nvim config from https://github.com/Mrchazaaa/vimconfig.git to $case_dir/config/nvim/vimconfig"
}

@test "install-nvim optionally installs vimconfig with environment variable" {
  write_fake_command nvim
  write_fake_command git

  run env \
    PATH="$fake_bin" \
    FAKE_BIN="$fake_bin" \
    HOME="$case_dir/home" \
    XDG_CONFIG_HOME="$case_dir/config" \
    TEST_LOG="$log_file" \
    INSTALL_NVIM_CONFIG=1 \
    "$BASH" "$repo_root/src/install-nvim.sh"

  [ "$status" -eq 0 ]
  refute_log_contains "apt-get"
  assert_log_contains "git clone https://github.com/Mrchazaaa/vimconfig.git $case_dir/config/nvim/vimconfig"
  assert_log_contains "vimconfig install.sh VIMCONFIG_INSTALL_DIR=$case_dir/config/nvim/vimconfig args=--nvim"
  assert_output_contains "nvim is already installed: NVIM v0.10.0"
  assert_output_contains "Installed nvim config from https://github.com/Mrchazaaa/vimconfig.git to $case_dir/config/nvim/vimconfig"
}

@test "install-nvim installs vimconfig when nvim is already installed" {
  write_fake_command nvim
  write_fake_apt_get
  write_fake_sudo

  run_install_script "$repo_root/src/install-nvim.sh" --with-vimconfig

  [ "$status" -eq 0 ]
  assert_log_contains "sudo apt-get update"
  assert_log_contains "sudo apt-get install -y git"
  assert_log_contains "git clone https://github.com/Mrchazaaa/vimconfig.git $case_dir/config/nvim/vimconfig"
  assert_log_contains "vimconfig install.sh VIMCONFIG_INSTALL_DIR=$case_dir/config/nvim/vimconfig args=--nvim"
  refute_log_contains "sudo apt-get install -y neovim"
  assert_output_contains "nvim is already installed: NVIM v0.10.0"
  assert_output_contains "Installed nvim config from https://github.com/Mrchazaaa/vimconfig.git to $case_dir/config/nvim/vimconfig"
}

@test "install-nvim uses an existing vimconfig checkout" {
  write_fake_command nvim
  /bin/mkdir -p "$case_dir/config/nvim/vimconfig/.git"
  /bin/cat > "$case_dir/config/nvim/vimconfig/install.sh" <<'SCRIPT'
#!/bin/bash
printf "existing vimconfig install.sh VIMCONFIG_INSTALL_DIR=%s args=%s\n" "$VIMCONFIG_INSTALL_DIR" "$*" >> "$TEST_LOG"
SCRIPT
  /bin/chmod +x "$case_dir/config/nvim/vimconfig/install.sh"

  run_install_script "$repo_root/src/install-nvim.sh" --with-vimconfig

  [ "$status" -eq 0 ]
  refute_log_contains "apt-get"
  refute_log_contains "git clone"
  assert_log_contains "existing vimconfig install.sh VIMCONFIG_INSTALL_DIR=$case_dir/config/nvim/vimconfig args=--nvim"
  assert_output_contains "vimconfig checkout already exists at $case_dir/config/nvim/vimconfig; leaving it unchanged."
  assert_output_contains "Installed nvim config from https://github.com/Mrchazaaa/vimconfig.git to $case_dir/config/nvim/vimconfig"
}

@test "install-nvim does not install git for an existing vimconfig checkout" {
  write_fake_apt_get
  write_fake_sudo
  /bin/mkdir -p "$case_dir/config/nvim/vimconfig/.git"
  /bin/cat > "$case_dir/config/nvim/vimconfig/install.sh" <<'SCRIPT'
#!/bin/bash
printf "existing vimconfig install.sh VIMCONFIG_INSTALL_DIR=%s args=%s\n" "$VIMCONFIG_INSTALL_DIR" "$*" >> "$TEST_LOG"
SCRIPT
  /bin/chmod +x "$case_dir/config/nvim/vimconfig/install.sh"

  run_install_script "$repo_root/src/install-nvim.sh" --with-vimconfig

  [ "$status" -eq 0 ]
  assert_log_contains "sudo apt-get install -y neovim"
  refute_log_contains "sudo apt-get install -y neovim git"
  refute_log_contains "git clone"
  assert_log_contains "existing vimconfig install.sh VIMCONFIG_INSTALL_DIR=$case_dir/config/nvim/vimconfig args=--nvim"
  assert_output_contains "Installed NVIM v0.10.0"
}
