#!/usr/bin/env bash

restore_archive_to_root() {
  local archive="$1"
  tar -xzf "$archive" -C /
}

restart_service_if_needed() {
  local service_was_active="$1"

  if [[ "$service_was_active" == "yes" ]]; then
    systemctl start "$XUI_SERVICE" || true
  fi
}

cmd_restore() {
  require_root

  local requested="${1:-}"
  local confirmation="${2:-}"
  local archive
  local emergency_backup
  local service_was_active="no"

  if [[ -z "$requested" ]]; then
    log_fail "Backup file is required"
    printf '%s\n' "Usage: vpn restore <latest|FILE> --confirm"
    return 2
  fi

  archive="$(backup_resolve_file "$requested")"

  if [[ "$confirmation" != "--confirm" ]]; then
    printf '%s\n' "Restore plan:"
    printf '  Archive: %s\n' "$archive"
    printf '  Service: %s will be stopped temporarily\n' "$XUI_SERVICE"
    printf '%s\n' "  Safety:  an emergency backup will be created first"
    printf '%s\n' "  Rollback: automatic if validation or startup fails"
    printf '\n%s\n' "No changes were made."
    printf '%s\n' "To continue, run:"
    printf '  sudo vpn restore %q --confirm\n' "$requested"
    return 2
  fi

  if ! backup_verify "$requested"; then
    return 1
  fi

  if service_active "$XUI_SERVICE"; then
    service_was_active="yes"
  fi

  log_info "Creating emergency backup before restore"
  backup_create
  emergency_backup="$(backup_latest)"

  if [[ -z "$emergency_backup" || ! -f "$emergency_backup" ]]; then
    log_fail "Emergency backup was not created"
    return 1
  fi

  log_info "Stopping $XUI_SERVICE"
  systemctl stop "$XUI_SERVICE"

  if ! restore_archive_to_root "$archive"; then
    log_fail "Restore extraction failed; rolling back"
    restore_archive_to_root "$emergency_backup" || true
    systemctl daemon-reload
    restart_service_if_needed "$service_was_active"
    return 1
  fi

  systemctl daemon-reload

  if [[ ! -x "$XRAY_BIN" || ! -r "$XRAY_CONFIG" ]]; then
    log_fail "Restored Xray binary or config is missing; rolling back"
    restore_archive_to_root "$emergency_backup" || true
    systemctl daemon-reload
    restart_service_if_needed "$service_was_active"
    return 1
  fi

  if ! "$XRAY_BIN" run -test -config "$XRAY_CONFIG" \
    >"$BASE_DIR/logs/restore-xray-test.log" 2>&1; then
    log_fail "Restored Xray configuration is invalid; rolling back"
    restore_archive_to_root "$emergency_backup" || true
    systemctl daemon-reload
    restart_service_if_needed "$service_was_active"
    return 1
  fi

  log_info "Starting $XUI_SERVICE"
  systemctl start "$XUI_SERVICE"
  sleep 2

  if ! service_active "$XUI_SERVICE" || ! port_listening "$VPN_PORT"; then
    log_fail "Health check failed after restore; rolling back"
    systemctl stop "$XUI_SERVICE" || true
    restore_archive_to_root "$emergency_backup" || true
    systemctl daemon-reload
    systemctl start "$XUI_SERVICE" || true
    return 1
  fi

  log_ok "Restore completed successfully"
  log_info "Emergency rollback backup: $emergency_backup"
}
