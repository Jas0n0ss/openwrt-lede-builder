#!/usr/bin/env bash
# Output GitHub Actions matrix JSON from configs/devices.list
# Usage: device-matrix.sh [device_id]   (empty or "all" = all devices)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="${ROOT}/configs/devices.list"
DEVICE="${1:-all}"

if [ ! -f "$LIST" ]; then
  echo "ERROR: missing $LIST" >&2
  exit 1
fi

ALL=()
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%%#*}"
  line="$(echo "$line" | xargs)"
  [ -n "$line" ] && ALL+=("$line")
done < "$LIST"

if [ "$DEVICE" = "all" ] || [ -z "$DEVICE" ]; then
  json=$(printf '"%s",' "${ALL[@]}" | sed 's/,$//')
  echo "matrix={\"device\":[${json}]}"
  exit 0
fi

for d in "${ALL[@]}"; do
  if [ "$d" = "$DEVICE" ]; then
    echo "matrix={\"device\":[\"${DEVICE}\"]}"
    exit 0
  fi
done

echo "ERROR: unknown device '${DEVICE}'. Valid: ${ALL[*]}" >&2
exit 1
