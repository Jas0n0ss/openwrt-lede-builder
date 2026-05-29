#!/usr/bin/env bash
# Patch upstream Makefiles that cause Kconfig recursive dependencies on LEDE.
# Usage: patch-src-kconfig.sh <src_dir>

set -euo pipefail

SRC_DIR="${1:?source directory required}"
cd "$SRC_DIR"

patch_dnsmasq() {
  local mk="package/network/services/dnsmasq/Makefile"
  [ -f "$mk" ] || return 0
  if grep -q 'PACKAGE_dnsmasq_full_nftset:nftables-json' "$mk"; then
    sed -i 's/+PACKAGE_dnsmasq_full_nftset:nftables-json//' "$mk"
    echo "==> patch-src-kconfig: removed dnsmasq_full_nftset -> nftables-json DEPENDS"
  fi
}

patch_dnsmasq
