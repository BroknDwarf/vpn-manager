#!/usr/bin/env bash

cmd_logs() {
  printf '%s\n' '=== Monitor log ==='
  tail -n 30 "$BASE_DIR/logs/monitor.log" 2>/dev/null \
    || printf '%s\n' 'No monitor log yet.'

  printf '\n%s\n' '=== Backup log ==='
  tail -n 30 "$BASE_DIR/logs/backup.log" 2>/dev/null \
    || printf '%s\n' 'No backup log yet.'
}
