#!/usr/bin/env bash
# Ensure every device in the matrix has configs/<repo>/<device>.config
# Usage: ci-validate-configs.sh <repo> <device|all>

set -euo pipefail

REPO="${1:?repo: lede|immortalwrt}"
DEVICE="${2:-all}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="${ROOT}/configs/devices.list"

case "$REPO" in
  lede|immortalwrt) ;;
  *) echo "ERROR: invalid repo '$REPO'" >&2; exit 1 ;;
esac

devices=()
if [ "$DEVICE" = "all" ] || [ -z "$DEVICE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [ -n "$line" ] && devices+=("$line")
  done < "$LIST"
else
  devices+=("$DEVICE")
fi

missing=0
for dev in "${devices[@]}"; do
  cfg="${ROOT}/configs/${REPO}/${dev}.config"
  if [ ! -f "$cfg" ]; then
    echo "ERROR: missing $cfg" >&2
    missing=1
  fi
done

[ "$missing" -eq 0 ] || exit 1
echo "==> ci-validate-configs: ${#devices[@]} device(s) OK for ${REPO}" >&2
