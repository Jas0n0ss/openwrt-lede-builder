#!/usr/bin/env bash
# One-shot LEDE tree fix: kenzo/small purge + nftables-json dupes + Makefile patches.
# Usage: ci-fix-kconfig-tree.sh <src_dir>

set -euo pipefail

SRC_DIR="${1:?source directory required}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SRC_DIR"

echo "==> ci-fix-kconfig-tree: start ($(pwd))"

if [ -f feeds.conf.default ]; then
  sed -i '\|kenzok8/openwrt-packages|d; \|kenzok8/small|d' feeds.conf.default 2>/dev/null || true
fi
if [ -f feeds.conf ]; then
  sed -i '\|kenzok8/openwrt-packages|d; \|kenzok8/small|d' feeds.conf 2>/dev/null || true
fi

rm -rf feeds/small feeds/kenzo package/feeds/small package/feeds/kenzo 2>/dev/null || true

bash "${SCRIPT_DIR}/purge-broken-feed-packages.sh" "$(pwd)"
bash "${SCRIPT_DIR}/patch-src-kconfig.sh" "$(pwd)"
bash "${SCRIPT_DIR}/purge-turboacc-duplicates.sh" "$(pwd)"

# nftables-json dupes must be gone; kmod-nft-fullcone may exist via package/nft-fullcone (TurboACC)
nft_json_count=0
while IFS= read -r mk; do
  [ -n "$mk" ] || continue
  nft_json_count=$((nft_json_count + 1))
done < <(grep -Rl 'PKG_NAME:=nftables-json' . 2>/dev/null \
  | grep -vE '^\./(dl|build_dir|staging_dir)/' || true)

if [ "$nft_json_count" -gt 0 ]; then
  echo "ERROR: still found ${nft_json_count} nftables-json package(s) after purge" >&2
  grep -Rl 'PKG_NAME:=nftables-json' . 2>/dev/null | grep -vE '^\./(dl|build_dir|staging_dir)/' >&2 || true
  exit 1
fi

if [ -f package/luci-app-turboacc/Makefile ] && [ ! -f package/nft-fullcone/Makefile ]; then
  echo "ERROR: luci-app-turboacc without package/nft-fullcone (incomplete TurboACC)" >&2
  exit 1
fi

# At most one luci-app-turboacc / nft-fullcone package tree (duplicate = Kconfig self-cycle)
luci_dupes=0
while IFS= read -r mk; do
  [ -n "$mk" ] || continue
  luci_dupes=$((luci_dupes + 1))
done < <(grep -Rl --include=Makefile 'PKG_NAME:=luci-app-turboacc' package package/feeds 2>/dev/null || true)

if [ "$luci_dupes" -gt 1 ]; then
  echo "ERROR: ${luci_dupes} luci-app-turboacc packages still present (expected 0–1)" >&2
  grep -Rl --include=Makefile 'PKG_NAME:=luci-app-turboacc' package package/feeds 2>/dev/null >&2 || true
  exit 1
fi

kmod_dupes=0
while IFS= read -r mk; do
  [ -n "$mk" ] || continue
  kmod_dupes=$((kmod_dupes + 1))
done < <(grep -Rl 'KernelPackage/nft-fullcone' package package/feeds 2>/dev/null || true)

if [ "$kmod_dupes" -gt 1 ]; then
  echo "ERROR: ${kmod_dupes} KernelPackage/nft-fullcone definitions (expected 0–1)" >&2
  grep -Rl 'KernelPackage/nft-fullcone' package package/feeds 2>/dev/null >&2 || true
  exit 1
fi

echo "==> ci-fix-kconfig-tree: OK"
