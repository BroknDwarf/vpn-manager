#!/usr/bin/env bash

set -u

VPN_MANAGER_CONFIG="${VPN_MANAGER_CONFIG:-/etc/vpn-manager.conf}"

if [[ -r "$VPN_MANAGER_CONFIG" ]]; then
  # shellcheck source=/dev/null
  source "$VPN_MANAGER_CONFIG"
fi

BASE_DIR="${BASE_DIR:-/opt/vpn-manager}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
MONITOR_DISK_FAIL_PERCENT="${MONITOR_DISK_FAIL_PERCENT:-90}"
XRAY_BIN="${XRAY_BIN:-/usr/local/x-ui/bin/xray-linux-amd64}"
XRAY_CONFIG="${XRAY_CONFIG:-/usr/local/x-ui/bin/config.json}"
XUI_SERVICE="${XUI_SERVICE:-x-ui}"
VPN_PORT="${VPN_PORT:-443}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-BroknDwarf/vpn-manager}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

log_info() { printf '[INFO] %s\n' "$*"; }
log_ok()   { printf '[OK]   %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_fail() { printf '[FAIL] %s\n' "$*" >&2; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log_fail "Команда должна выполняться от root."
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

service_active() {
  systemctl is-active --quiet "$1"
}

port_listening() {
  local port="$1"
  ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$"
}
