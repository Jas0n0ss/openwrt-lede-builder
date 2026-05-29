#!/usr/bin/env bash
# Remove duplicate nftables-json/nojson packages (kenzo/small) — self-referential Kconfig.
# Usage: purge-broken-feed-packages.sh <src_dir>

set -euo pipefail

SRC_DIR="${1:?source directory required}"
cd "$SRC_DIR"

purge_pkg_by_name() {
  local name="$1"
  local mk dir
  while IFS= read -r mk; do
    [ -n "$mk" ] || continue
    case "$mk" in
      ./dl/*|./build_dir/*|./staging_dir/*) continue ;;
    esac
    dir="$(dirname "$mk")"
    rm -rf "$dir"
    echo "==> purged package ${name}: ${dir}"
  done < <(grep -Rl "PKG_NAME:=${name}" . 2>/dev/null || true)
}

purge_pkg_by_name nftables-json
purge_pkg_by_name nftables-nojson

# Directory names from stale feed symlinks (fallback)
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  case "$dir" in
    ./dl/*|./build_dir/*|./staging_dir/*) continue ;;
  esac
  rm -rf "$dir"
  echo "==> purged directory: ${dir}"
done < <(find feeds package/feeds -type d \( -name nftables-json -o -name nftables-nojson \) 2>/dev/null || true)

echo "==> purge-broken-feed-packages: done"
