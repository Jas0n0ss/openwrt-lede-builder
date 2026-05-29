#!/usr/bin/env bash
# Patch cloned TurboACC Makefiles: safe Kconfig defaults (enabled later in ci-enable-turboacc).
# Usage: patch-turboacc-packages.sh <src_dir>

set -euo pipefail

SRC_DIR="${1:?source directory required}"
cd "$SRC_DIR"

LUCI_MK="package/luci-app-turboacc/Makefile"
[ -f "$LUCI_MK" ] || exit 0

if ! grep -q 'ci-patched-turboacc-defaults' "$LUCI_MK"; then
  sed -i \
    -e '/INCLUDE_OFFLOADING/,/^config /{
      s/^[[:space:]]*default y if.*/	default n # ci-patched-turboacc-defaults/
    }' \
    -e '/INCLUDE_NFT_FULLCONE/,/^config /{
      s/^[[:space:]]*default y[[:space:]]*$/	default n # ci-patched-turboacc-defaults/
    }' \
    -e '/INCLUDE_BBR_CCA/,/^config /{
      s/^[[:space:]]*default y[[:space:]]*$/	default n # ci-patched-turboacc-defaults/
    }' \
    "$LUCI_MK"
  echo "==> patch-turboacc-packages: set INCLUDE_* defaults to n until ci-enable-turboacc"
fi
