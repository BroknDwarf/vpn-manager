#!/usr/bin/env bash

cmd_backup() {
  require_root

  local backup_dir="$BASE_DIR/backups"
  local log_file="$BASE_DIR/logs/backup.log"
  local stamp
  local output
  local temporary
  local -a items=()

  stamp="$(date +%F-%H%M%S)"
  output="$backup_dir/vpn-backup-$stamp.tar.gz"
  temporary="$output.tmp"

  mkdir -p "$backup_dir" "$BASE_DIR/logs"

  [[ -e /usr/local/x-ui ]] && items+=(/usr/local/x-ui)
  [[ -e /etc/systemd/system/x-ui.service ]] && items+=(/etc/systemd/system/x-ui.service)
  [[ -e /etc/systemd/system/x-ui.service.d ]] && items+=(/etc/systemd/system/x-ui.service.d)
  [[ -e /etc/x-ui ]] && items+=(/etc/x-ui)
  [[ -e /etc/vpn-manager.conf ]] && items+=(/etc/vpn-manager.conf)

  if [[ ${#items[@]} -eq 0 ]]; then
    log_fail "Nothing to back up"
    return 1
  fi

  if tar -czf "$temporary" "${items[@]}" 2>>"$log_file"; then
    mv "$temporary" "$output"
    tar -tzf "$output" >/dev/null
    find "$backup_dir" -maxdepth 1 -type f \
      -name 'vpn-backup-*.tar.gz' \
      -mtime "+$BACKUP_RETENTION_DAYS" -delete

    printf '%s OK: %s (%s)\n' \
      "$(date -Is)" "$output" "$(du -h "$output" | awk '{print $1}')" \
      | tee -a "$log_file"
  else
    rm -f "$temporary"
    printf '%s ERROR: backup failed\n' "$(date -Is)" | tee -a "$log_file"
    return 1
  fi
}
