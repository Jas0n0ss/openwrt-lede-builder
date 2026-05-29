#!/usr/bin/env bash
# Hide/show cloned TurboACC packages so base make defconfig never loads their Kconfig.
# Usage: ci-turboacc-stash.sh <src_dir> hide|unhide

set -euo pipefail

SRC_DIR="${1:?source directory required}"
ACTION="${2:?hide or unhide}"
STASH="${SRC_DIR}/.ci-stash-turboacc"

cd "$SRC_DIR"

case "$ACTION" in
  hide)
    mkdir -p "$STASH"
    for d in luci-app-turboacc nft-fullcone; do
      if [ -d "package/${d}" ]; then
        rm -rf "${STASH}/${d}"
        mv "package/${d}" "${STASH}/${d}"
        echo "==> ci-turboacc-stash: hid package/${d}"
      fi
    done
    ;;
  unhide)
    for d in luci-app-turboacc nft-fullcone; do
      if [ -d "${STASH}/${d}" ]; then
        rm -rf "package/${d}"
        mv "${STASH}/${d}" "package/${d}"
        echo "==> ci-turboacc-stash: restored package/${d}"
      fi
    done
    ;;
  *)
    echo "ERROR: unknown action '$ACTION' (use hide|unhide)" >&2
    exit 1
    ;;
esac
