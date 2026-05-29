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

# Remove feeds duplicate of kmod-nft-fullcone; keep package/nft-fullcone from turboacc clone
purge_feeds_kmod_nft_fullcone() {
  local mk dir
  while IFS= read -r mk; do
    [ -n "$mk" ] || continue
    case "$mk" in
      ./package/nft-fullcone/*|./package/nft-fullcone/Makefile) continue ;;
    esac
    dir="$(dirname "$mk")"
    rm -rf "$dir"
    echo "==> patch-src-kconfig: removed duplicate ${dir}"
  done < <(grep -Rl 'PKG_NAME:=kmod-nft-fullcone' feeds package/feeds 2>/dev/null || true)
}

patch_dnsmasq
purge_feeds_kmod_nft_fullcone
