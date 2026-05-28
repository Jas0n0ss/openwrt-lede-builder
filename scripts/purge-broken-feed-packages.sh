#!/usr/bin/env bash
# Remove feed packages that break Kconfig (nftables-json dupes from kenzo/small cache).
# Usage: purge-broken-feed-packages.sh <src_dir>

set -euo pipefail

SRC_DIR="${1:?source directory required}"
cd "$SRC_DIR"

while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  rm -rf "$dir"
  echo "==> purged broken package tree: ${dir}"
done < <(find feeds package/feeds package -maxdepth 6 -type d \
  \( -name nftables-json -o -name nftables-nojson \) 2>/dev/null || true)
