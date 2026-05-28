#!/usr/bin/env bash
# Post-feed patches: pin xray-core for OpenWrt golang/host 1.21, strip duplicate kenzo packages.
# Usage: patch-feeds.sh <src_dir>

set -euo pipefail

SRC_DIR="${1:?source directory required}"
cd "$SRC_DIR"

patch_xray_core() {
  local mk="feeds/passwall_packages/xray-core/Makefile"
  [ -f "$mk" ] || return 0

  # Xray >=25 needs Go 1.25+; LEDE/OpenWrt host golang is typically 1.21.x.
  local ver hash
  ver="24.12.31"
  hash="e3c24b561ab422785ee8b7d4a15e44db159d9aa249eb29a36ad1519c15267be"

  if grep -q "PKG_VERSION:=${ver}" "$mk"; then
    echo "==> xray-core already pinned to ${ver}"
    return 0
  fi

  sed -i \
    -e "s/^PKG_VERSION:=.*/PKG_VERSION:=${ver}/" \
    -e "s/^PKG_HASH:=.*/PKG_HASH:=${hash}/" \
    "$mk"
  echo "==> Pinned xray-core to ${ver} (compatible with golang/host 1.21)"
}

strip_conflicting_feed_dirs() {
  local names=(
    luci-app-unblockneteasemusic
    luci-ssl
    nftables-json
  )
  for name in "${names[@]}"; do
    find feeds/kenzo feeds/small -maxdepth 3 -type d -name "$name" 2>/dev/null \
      | while read -r dir; do
          rm -rf "$dir"
          echo "==> Removed conflicting feed package: $dir"
        done
  done
}

patch_xray_core
strip_conflicting_feed_dirs
