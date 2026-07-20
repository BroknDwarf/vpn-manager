#!/usr/bin/env bash

cmd_self_update() {
  require_root

  local temp_dir
  local archive_url

  if ! command_exists curl; then
    log_fail "curl is required for self-update"
    return 1
  fi

  temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' RETURN

  archive_url="https://github.com/${GITHUB_REPOSITORY}/archive/refs/heads/${GITHUB_BRANCH}.tar.gz"

  log_info "Downloading $archive_url"
  curl -fsSL "$archive_url" -o "$temp_dir/source.tar.gz"
  tar -xzf "$temp_dir/source.tar.gz" -C "$temp_dir"

  local source_dir
  source_dir=$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)

  if [[ ! -x "$source_dir/install.sh" ]]; then
    chmod +x "$source_dir/install.sh"
  fi

  bash "$source_dir/install.sh"
  log_ok "VPN Manager updated"
}
