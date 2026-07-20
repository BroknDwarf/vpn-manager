#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

systemctl disable --now vpn-manager-monitor.timer 2>/dev/null || true
rm -f /etc/systemd/system/vpn-manager-monitor.service
rm -f /etc/systemd/system/vpn-manager-monitor.timer
rm -f /etc/cron.d/vpn-manager-backup
rm -f /usr/local/bin/vpn
systemctl daemon-reload

echo "VPN Manager commands removed."
echo "Data remains in /opt/vpn-manager."
