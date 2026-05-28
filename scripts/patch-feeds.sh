#!/usr/bin/env bash
# Pin Go-based PassWall packages for OpenWrt golang/host ~1.21; strip stale kenzo dupes.
# Usage: patch-feeds.sh <src_dir>

set -euo pipefail

SRC_DIR="${1:?source directory required}"
cd "$SRC_DIR"

pin_pkg_makefile() {
  local mk="$1" ver="$2" hash="$3" label="$4"
  [ -f "$mk" ] || {
    echo "ERROR: missing ${mk} (PassWall feed not installed?)" >&2
    exit 1
  }

  if grep -q "PKG_VERSION:=${ver}" "$mk"; then
    echo "==> ${label} already at ${ver}"
    return 0
  fi

  sed -i \
    -e "s/^PKG_VERSION:=.*/PKG_VERSION:=${ver}/" \
    -e "s/^PKG_HASH:=.*/PKG_HASH:=${hash}/" \
    "$mk"
  echo "==> Pinned ${label} to ${ver} (golang/host 1.21 compatible)"
}

patch_passwall_go_packages() {
  pin_pkg_makefile \
    "feeds/passwall_packages/xray-core/Makefile" \
    "24.12.31" \
    "e3c24b561ab422785ee8b7d4a15e44db159d9aa249eb29a36ad1519c15267be" \
    "xray-core"

  pin_pkg_makefile \
    "feeds/passwall_packages/sing-box/Makefile" \
    "1.11.0" \
    "d4a48b2fe450041fea2d25955ddc092a62afc8da7bb442b49cb12575123b2edb" \
    "sing-box"
}

strip_conflicting_feed_dirs() {
  local names=(
    luci-app-unblockneteasemusic
    luci-ssl
    nftables-json
  )
  local feed name dir
  for feed in feeds/kenzo feeds/small; do
    [ -d "$feed" ] || continue
    for name in "${names[@]}"; do
      while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        rm -rf "$dir"
        echo "==> Removed conflicting feed package: ${dir}"
      done < <(find "$feed" -maxdepth 3 -type d -name "$name" 2>/dev/null || true)
    done
  done
}

patch_passwall_go_packages
strip_conflicting_feed_dirs
