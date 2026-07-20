#!/usr/bin/env bash

cmd_monitor() {
  local log_file="$BASE_DIR/logs/monitor.log"
  local state_file="$BASE_DIR/logs/monitor.state"
  local status="OK"
  local previous
  local disk_used
  local -a details=()

  mkdir -p "$BASE_DIR/logs"

  service_active "$XUI_SERVICE" || {
    status="FAIL"
    details+=("${XUI_SERVICE}_inactive")
  }

  port_listening "$VPN_PORT" || {
    status="FAIL"
    details+=("port_${VPN_PORT}_closed")
  }

  disk_used=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
  if (( disk_used >= MONITOR_DISK_FAIL_PERCENT )); then
    status="FAIL"
    details+=("disk_${disk_used}pct")
  fi

  previous=$(cat "$state_file" 2>/dev/null || echo UNKNOWN)
  printf '%s\n' "$status" >"$state_file"

  if [[ "$status" != "$previous" || "$status" == "FAIL" ]]; then
    printf '%s status=%s details=%s\n' \
      "$(date -Is)" "$status" "${details[*]:-none}" >>"$log_file"
  fi

  [[ "$status" == "OK" ]]
}
