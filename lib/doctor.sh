#!/usr/bin/env bash

cmd_doctor() {
  local fails=0
  local warns=0
  local disk_used
  local mem_available
  local congestion

  doctor_ok() {
    log_ok "$*"
  }

  doctor_warn() {
    log_warn "$*"
    warns=$((warns + 1))
  }

  doctor_fail() {
    log_fail "$*"
    fails=$((fails + 1))
  }

  printf 'VPN Manager %s — Doctor\n' "$VPN_MANAGER_VERSION"
  printf '%s\n' 'Диагностика не изменяет настройки сервера.'
  printf '%s\n' '----------------------------------------'

  if service_active "$XUI_SERVICE"; then
    doctor_ok "$XUI_SERVICE is active"
  else
    doctor_fail "$XUI_SERVICE is inactive"
  fi

  if systemctl is-enabled --quiet "$XUI_SERVICE" 2>/dev/null; then
    doctor_ok "$XUI_SERVICE starts automatically"
  else
    doctor_warn "$XUI_SERVICE is not enabled at boot"
  fi

  if port_listening "$VPN_PORT"; then
    doctor_ok "TCP $VPN_PORT is listening"
  else
    doctor_fail "TCP $VPN_PORT is not listening"
  fi

  if [[ -x "$XRAY_BIN" && -r "$XRAY_CONFIG" ]]; then
    if "$XRAY_BIN" run -test -config "$XRAY_CONFIG" \
      >"$BASE_DIR/logs/xray-config-test.log" 2>&1; then
      doctor_ok "Xray configuration is valid"
    else
      doctor_fail "Xray configuration test failed"
    fi
  else
    doctor_warn "Xray binary or config not found at expected path"
  fi

  disk_used=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
  if (( disk_used < 80 )); then
    doctor_ok "Disk usage is ${disk_used}%"
  elif (( disk_used < MONITOR_DISK_FAIL_PERCENT )); then
    doctor_warn "Disk usage is ${disk_used}%"
  else
    doctor_fail "Disk usage is ${disk_used}%"
  fi

  mem_available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
  if (( mem_available > 262144 )); then
    doctor_ok "Available memory: $((mem_available / 1024)) MiB"
  else
    doctor_warn "Low available memory: $((mem_available / 1024)) MiB"
  fi

  congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)
  if [[ "$congestion" == "bbr" ]]; then
    doctor_ok "BBR is enabled"
  else
    doctor_warn "Congestion control is $congestion"
  fi

  if ip route | grep -q '^default '; then
    doctor_ok "IPv4 default route exists"
  else
    doctor_fail "IPv4 default route is missing"
  fi

  if ip -6 route | grep -q '^default '; then
    doctor_ok "IPv6 default route exists"
  else
    doctor_warn "IPv6 default route is missing"
  fi

  printf '%s\n' '----------------------------------------'
  printf 'Result: %s failure(s), %s warning(s)\n' "$fails" "$warns"

  (( fails == 0 ))
}
