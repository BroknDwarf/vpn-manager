#!/usr/bin/env bash

backup_latest() {
  find "$BASE_DIR/backups" -maxdepth 1 -type f \
    -name 'vpn-backup-*.tar.gz' -printf '%T@ %p\n' 2>/dev/null |
    sort -nr | head -n1 | cut -d' ' -f2-
}

backup_resolve_file() {
  local requested="${1:-latest}"

  if [[ "$requested" == "latest" ]]; then
    backup_latest
  elif [[ "$requested" = /* ]]; then
    printf '%s\n' "$requested"
  else
    printf '%s/%s\n' "$BASE_DIR/backups" "$requested"
  fi
}

backup_create() {
  require_root

  local backup_dir="$BASE_DIR/backups"
  local log_file="$BASE_DIR/logs/backup.log"
  local stamp
  local output
  local temporary
  local checksum_file
  local -a items=()

  stamp="$(date +%F-%H%M%S)"
  output="$backup_dir/vpn-backup-$stamp.tar.gz"
  temporary="$output.tmp"
  checksum_file="$output.sha256"

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

    if ! tar -tzf "$output" >/dev/null; then
      rm -f "$output"
      log_fail "Created archive is invalid"
      return 1
    fi

    (
      cd "$backup_dir"
      sha256sum "$(basename "$output")" >"$(basename "$checksum_file")"
    )

    find "$backup_dir" -maxdepth 1 -type f \
      \( -name 'vpn-backup-*.tar.gz' -o -name 'vpn-backup-*.tar.gz.sha256' \) \
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

backup_list() {
  local backup_dir="$BASE_DIR/backups"

  mkdir -p "$backup_dir"

  printf '%-34s %10s %s\n' "BACKUP" "SIZE" "CREATED"
  find "$backup_dir" -maxdepth 1 -type f -name 'vpn-backup-*.tar.gz' \
    -printf '%f\n' 2>/dev/null |
    sort -r |
    while IFS= read -r file; do
      printf '%-34s %10s %s\n' \
        "$file" \
        "$(du -h "$backup_dir/$file" | awk '{print $1}')" \
        "$(date -r "$backup_dir/$file" '+%F %T')"
    done
}

backup_verify() {
  local archive
  local checksum_file
  local archive_dir
  local archive_name

  archive="$(backup_resolve_file "${1:-latest}")"

  if [[ -z "$archive" || ! -f "$archive" ]]; then
    log_fail "Backup not found: ${1:-latest}"
    return 1
  fi

  checksum_file="$archive.sha256"
  archive_dir="$(dirname "$archive")"
  archive_name="$(basename "$archive")"

  if ! gzip -t "$archive"; then
    log_fail "Gzip integrity check failed: $archive"
    return 1
  fi

  if ! tar -tzf "$archive" >/dev/null; then
    log_fail "Tar integrity check failed: $archive"
    return 1
  fi

  if [[ -f "$checksum_file" ]]; then
    if ! (
      cd "$archive_dir"
      sha256sum -c "$(basename "$checksum_file")"
    ); then
      log_fail "SHA-256 check failed: $archive"
      return 1
    fi
  else
    log_warn "Checksum file is missing for $archive_name"
  fi

  if ! tar -tzf "$archive" | grep -Eq '(^|/)usr/local/x-ui(/|$)'; then
    log_fail "Archive does not contain /usr/local/x-ui"
    return 1
  fi

  log_ok "Backup is valid: $archive"
}

cmd_backup() {
  local action="${1:-create}"

  case "$action" in
    create)
      backup_create
      ;;
    list)
      backup_list
      ;;
    verify)
      backup_verify "${2:-latest}"
      ;;
    *)
      log_fail "Unknown backup action: $action"
      printf '%s\n' "Usage:"
      printf '%s\n' "  vpn backup"
      printf '%s\n' "  vpn backup list"
      printf '%s\n' "  vpn backup verify [latest|FILE]"
      return 2
      ;;
  esac
}
