#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

test -f "$ROOT/VERSION"
test -x "$ROOT/bin/vpn"
test -f "$ROOT/lib/common.sh"
test -f "$ROOT/lib/status.sh"
test -f "$ROOT/lib/doctor.sh"
test -f "$ROOT/lib/backup.sh"
test -f "$ROOT/lib/restore.sh"
test -f "$ROOT/lib/report.sh"
test -f "$ROOT/lib/monitor.sh"
test -f "$ROOT/lib/logs.sh"
test -f "$ROOT/lib/self-update.sh"
test -f "$ROOT/install.sh"

grep -q 'vpn status' "$ROOT/README.md"
grep -q 'set -Eeuo pipefail' "$ROOT/bin/vpn"
grep -q 'vpn backup verify' "$ROOT/bin/vpn"
grep -q 'vpn restore' "$ROOT/bin/vpn"
grep -q 'vpn report' "$ROOT/bin/vpn"
grep -q 'config.json contents' "$ROOT/lib/report.sh"

echo "Smoke tests passed."
