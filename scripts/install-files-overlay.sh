#!/usr/bin/env bash
# Copy repo files/ overlay into <src>/files/ (not source root).
# Usage: install-files-overlay.sh <build_root> [overlay_src]

set -euo pipefail

BUILD_ROOT="${1:?build root required}"
OVERLAY_SRC="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/files}"

if [[ "$BUILD_ROOT" != /* ]]; then
  BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd)"
fi
if [[ "$OVERLAY_SRC" != /* ]]; then
  OVERLAY_SRC="$(cd "$OVERLAY_SRC" && pwd)"
fi

DEST="${BUILD_ROOT}/files"

if [ ! -d "$OVERLAY_SRC" ]; then
  echo "ERROR: overlay source not found: $OVERLAY_SRC" >&2
  exit 1
fi

mkdir -p "$DEST"
cp -a "${OVERLAY_SRC}/." "$DEST/"

if [ -d "${DEST}/etc/uci-defaults" ]; then
  chmod +x "${DEST}"/etc/uci-defaults/* 2>/dev/null || true
fi

[ -f "${DEST}/etc/banner" ] || {
  echo "ERROR: overlay missing ${DEST}/etc/banner (run generate-banner.sh first)" >&2
  exit 1
}

echo "==> Installed files overlay: ${OVERLAY_SRC} -> ${DEST}"
