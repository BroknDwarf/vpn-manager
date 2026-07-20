#!/usr/bin/env bash

cmd_status() {
  local latest_backup=""

  printf 'VPN Manager %s — Status\n' "$VPN_MANAGER_VERSION"
  printf '%s\n' '----------------------------------------'
  printf 'Host:       %s\n' "$(hostname -f 2>/dev/null || hostname)"
  printf 'Uptime:     %s\n' "$(uptime -p 2>/dev/null || true)"
  printf 'Load:       %s\n' "$(cut -d' ' -f1-3 /proc/loadavg)"
  printf 'Memory:     %s\n' "$(free -h | awk '/^Mem:/ {print $3 " used / " $2 " total; " $7 " available"}')"
  printf 'Disk /:     %s\n' "$(df -h / | awk 'NR==2 {print $3 " used / " $2 " total (" $5 ")"}')"
  printf 'Swap:       %s\n' "$(free -h | awk '/^Swap:/ {print $3 " used / " $2 " total"}')"
  printf 'Congestion: %s\n' "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  printf '%s\n' '----------------------------------------'

  if service_active "$XUI_SERVICE"; then
    log_ok "$XUI_SERVICE is running"
  else
    log_fail "$XUI_SERVICE is not running"
  fi

  if port_listening "$VPN_PORT"; then
    log_ok "TCP port $VPN_PORT is listening"
  else
    log_fail "TCP port $VPN_PORT is not listening"
  fi

  if [[ -x "$XRAY_BIN" ]]; then
    log_ok "$("$XRAY_BIN" version 2>/dev/null | head -n1)"
  else
    log_warn "Xray binary not found: $XRAY_BIN"
  fi

  latest_backup=$(find "$BASE_DIR/backups" -maxdepth 1 -type f \
    -name 'vpn-backup-*.tar.gz' -printf '%T@ %f\n' 2>/dev/null |
    sort -nr | head -n1 | cut -d' ' -f2-)

  if [[ -n "$latest_backup" ]]; then
    printf 'Last backup: %s\n' "$latest_backup"
  else
    log_warn "No backup found"
  fi
}
