#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

while IFS= read -r -d '' file; do
  bash -n "$file"
done < <(find "$ROOT" -type f \( -name '*.sh' -o -path '*/bin/vpn' \) -print0)

echo "Bash syntax tests passed."
