#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_DIR="/opt/vpn-manager"
BIN_PATH="/usr/local/bin/vpn"
CONFIG_PATH="/etc/vpn-manager.conf"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run installer as root."
  exit 1
fi

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

for required in bash tar gzip sha256sum find awk grep sed ss systemctl; do
  if ! command -v "$required" >/dev/null 2>&1; then
    echo "Missing required command: $required"
    exit 1
  fi
done

mkdir -p "$INSTALL_DIR"/{lib,backups,logs,reports}

install -m 644 "$SOURCE_DIR/VERSION" "$INSTALL_DIR/VERSION"
install -m 644 "$SOURCE_DIR"/lib/*.sh "$INSTALL_DIR/lib/"
install -m 755 "$SOURCE_DIR/bin/vpn" "$BIN_PATH"

if [[ ! -e "$CONFIG_PATH" ]]; then
  install -m 600 "$SOURCE_DIR/config/vpn-manager.conf.example" "$CONFIG_PATH"
fi

install -m 644 "$SOURCE_DIR/systemd/vpn-manager-monitor.service" \
  /etc/systemd/system/vpn-manager-monitor.service
install -m 644 "$SOURCE_DIR/systemd/vpn-manager-monitor.timer" \
  /etc/systemd/system/vpn-manager-monitor.timer
install -m 644 "$SOURCE_DIR/cron/vpn-manager-backup" \
  /etc/cron.d/vpn-manager-backup

systemctl daemon-reload
systemctl enable --now vpn-manager-monitor.timer

"$BIN_PATH" backup
"$BIN_PATH" monitor || true

echo
echo "VPN Manager installed."
echo "Run: vpn status"
