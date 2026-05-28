#!/usr/bin/env bash
# Resolve CI inputs → GitHub Actions outputs (repo, upstream, matrix).
# Usage: ci-resolve-build.sh <source> <device> <event_name> >> $GITHUB_OUTPUT

set -euo pipefail

SOURCE="${1:-immortalwrt}"
DEVICE="${2:-all}"
EVENT="${3:-schedule}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$SOURCE" in
  lede)
    echo "repo=lede"
    echo "upstream=coolsnowwolf/lede"
    ;;
  immortalwrt)
    echo "repo=immortalwrt"
    echo "upstream=immortalwrt/immortalwrt"
    ;;
  *)
    echo "ERROR: unknown source '$SOURCE' (use lede or immortalwrt)" >&2
    exit 1
    ;;
esac

if [ "$EVENT" = "workflow_dispatch" ] && [ -n "$DEVICE" ] && [ "$DEVICE" != "all" ]; then
  bash "${SCRIPT_DIR}/device-matrix.sh" "$DEVICE"
else
  bash "${SCRIPT_DIR}/device-matrix.sh" all
fi

bash "${SCRIPT_DIR}/ci-validate-configs.sh" "$SOURCE" "$DEVICE"
