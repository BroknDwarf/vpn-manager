#!/usr/bin/env bash

report_redact_stream() {
  sed -E \
    -e 's/([Uu][Uu][Ii][Dd][[:space:]]*[:=][[:space:]]*)[^[:space:]",}]+/\1[REDACTED]/g' \
    -e 's/([Pp]rivate[Kk]ey[[:space:]]*[:=][[:space:]]*)[^[:space:]",}]+/\1[REDACTED]/g' \
    -e 's/([Pp]ublic[Kk]ey[[:space:]]*[:=][[:space:]]*)[^[:space:]",}]+/\1[REDACTED]/g' \
    -e 's/([Pp]assword[[:space:]]*[:=][[:space:]]*)[^[:space:]",}]+/\1[REDACTED]/g' \
    -e 's/([Tt]oken[[:space:]]*[:=][[:space:]]*)[^[:space:]",}]+/\1[REDACTED]/g' \
    -e 's/([Ss]hort[Ii]d[[:space:]]*[:=][[:space:]]*)[^[:space:]",}]+/\1[REDACTED]/g'
}

report_write_command() {
  local output_file="$1"
  shift

  {
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'

    "$@" 2>&1 || true
  } | report_redact_stream >"$output_file"
}

report_write_shell() {
  local output_file="$1"
  local command_text="$2"

  {
    printf '$ %s\n\n' "$command_text"
    bash -lc "$command_text" 2>&1 || true
  } | report_redact_stream >"$output_file"
}

report_collect_doctor() {
  local output_file="$1"

  {
    printf '$ vpn doctor\n\n'
    cmd_doctor || true
  } | report_redact_stream >"$output_file"
}

report_collect_xray_version() {
  local output_file="$1"

  {
    printf '$ %q version\n\n' "$XRAY_BIN"
    if [[ -x "$XRAY_BIN" ]]; then
      "$XRAY_BIN" version 2>&1 || true
    else
      printf 'Xray binary not found: %s\n' "$XRAY_BIN"
    fi
  } | report_redact_stream >"$output_file"
}

report_collect_xray_test() {
  local output_file="$1"

  {
    printf '$ %q run -test -config %q\n\n' "$XRAY_BIN" "$XRAY_CONFIG"
    if [[ -x "$XRAY_BIN" && -r "$XRAY_CONFIG" ]]; then
      "$XRAY_BIN" run -test -config "$XRAY_CONFIG" 2>&1 || true
    else
      printf 'Xray binary or config not found at expected path.\n'
    fi
  } | report_redact_stream >"$output_file"
}

report_collect_backup_status() {
  local output_file="$1"

  {
    printf '$ vpn backup list\n\n'
    backup_list
    printf '\n$ vpn backup verify latest\n\n'
    backup_verify latest || true
  } | report_redact_stream >"$output_file"
}

cmd_report() {
  require_root

  local reports_dir="$BASE_DIR/reports"
  local stamp
  local work_dir
  local archive
  local manifest

  stamp="$(date +%F-%H%M%S)"
  work_dir="$reports_dir/report-$stamp"
  archive="$reports_dir/vpn-report-$stamp.tar.gz"
  manifest="$work_dir/MANIFEST.txt"

  mkdir -p "$work_dir"

  log_info "Collecting diagnostic report"

  report_write_command "$work_dir/system.txt" hostnamectl
  report_write_command "$work_dir/kernel.txt" uname -a
  report_write_command "$work_dir/cpu.txt" lscpu
  report_write_command "$work_dir/memory.txt" free -h
  report_write_command "$work_dir/disk.txt" df -h
  report_write_command "$work_dir/uptime.txt" uptime
  report_write_command "$work_dir/services.txt" systemctl status "$XUI_SERVICE" --no-pager -l
  report_write_command "$work_dir/service-properties.txt" systemctl show "$XUI_SERVICE" \
    -p ActiveState -p SubState -p UnitFileState -p NRestarts -p ExecMainStatus
  report_write_command "$work_dir/ports.txt" ss -lntup
  report_write_command "$work_dir/routes-ipv4.txt" ip route
  report_write_command "$work_dir/routes-ipv6.txt" ip -6 route
  report_write_command "$work_dir/addresses.txt" ip -brief address
  report_write_command "$work_dir/network-sysctl.txt" sysctl \
    net.ipv4.tcp_congestion_control \
    net.core.default_qdisc \
    net.ipv4.ip_forward \
    net.ipv6.conf.all.disable_ipv6
  report_write_command "$work_dir/x-ui-journal.txt" journalctl -u "$XUI_SERVICE" \
    -n 200 --no-pager
  report_write_shell "$work_dir/recent-system-errors.txt" \
    "journalctl -p warning..alert -n 150 --no-pager"
  report_collect_doctor "$work_dir/doctor.txt"
  report_collect_xray_version "$work_dir/xray-version.txt"
  report_collect_xray_test "$work_dir/xray-config-test.txt"
  report_collect_backup_status "$work_dir/backups.txt"

  if [[ -r "$BASE_DIR/logs/monitor.log" ]]; then
    tail -n 200 "$BASE_DIR/logs/monitor.log" |
      report_redact_stream >"$work_dir/monitor.log"
  else
    printf 'No monitor log found.\n' >"$work_dir/monitor.log"
  fi

  if [[ -r "$BASE_DIR/logs/backup.log" ]]; then
    tail -n 200 "$BASE_DIR/logs/backup.log" |
      report_redact_stream >"$work_dir/backup.log"
  else
    printf 'No backup log found.\n' >"$work_dir/backup.log"
  fi

  {
    printf 'VPN Manager diagnostic report\n'
    printf 'Created: %s\n' "$(date -Is)"
    printf 'Host: %s\n' "$(hostname -f 2>/dev/null || hostname)"
    printf 'Version: %s\n' "$VPN_MANAGER_VERSION"
    printf '\nIncluded files:\n'
    find "$work_dir" -maxdepth 1 -type f -printf '%f\n' | sort
    printf '\nExcluded by design:\n'
    printf '%s\n' '- Xray config.json contents'
    printf '%s\n' '- Reality private keys'
    printf '%s\n' '- Client UUIDs'
    printf '%s\n' '- Panel passwords'
    printf '%s\n' '- Telegram tokens'
  } >"$manifest"

  (
    cd "$reports_dir" || exit 1
    tar -czf "$(basename "$archive")" "$(basename "$work_dir")"
    sha256sum "$(basename "$archive")" >"$(basename "$archive").sha256"
  )

  rm -rf "$work_dir"

  if ! tar -tzf "$archive" >/dev/null; then
    rm -f "$archive" "$archive.sha256"
    log_fail "Report archive verification failed"
    return 1
  fi

  log_ok "Report created: $archive"
  log_info "Checksum: $archive.sha256"
  log_warn "Review the archive before sharing it outside trusted support channels."
}
