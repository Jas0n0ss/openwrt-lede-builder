#!/usr/bin/env bash
# Fail fast if feed setup did not produce a buildable tree.
# Usage: verify-setup.sh <src_dir> [feeds|full]
#   feeds — PassWall feeds + xray/sing-box pins only (before custom package clones)
#   full  — default; includes package/luci-app-mosdns etc.

set -euo pipefail

SRC_DIR="${1:?source directory required}"
MODE="${2:-full}"
cd "$SRC_DIR"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[ -f feeds/passwall_packages/xray-core/Makefile ] \
  || fail "missing feeds/passwall_packages/xray-core (run feeds install -p passwall_packages)"

grep -q 'PKG_VERSION:=24.12.31' feeds/passwall_packages/xray-core/Makefile \
  || fail "xray-core not pinned to 24.12.31 — run scripts/patch-feeds.sh"

[ -f feeds/passwall_packages/sing-box/Makefile ] \
  || fail "missing sing-box in passwall_packages feed"

grep -q 'PKG_VERSION:=1.11.0' feeds/passwall_packages/sing-box/Makefile \
  || fail "sing-box not pinned to 1.11.0 — run scripts/patch-feeds.sh"

if [ ! -f feeds/passwall_luci/luci-app-passwall/Makefile ] \
  && [ ! -f package/feeds/passwall_luci/luci-app-passwall/Makefile ]; then
  fail "luci-app-passwall not installed from passwall_luci feed"
fi

if [ ! -f feeds/luci/luci-ssl/Makefile ] \
  && [ ! -f package/feeds/luci/luci-ssl/Makefile ]; then
  fail "luci-ssl missing (patch-feeds must not remove feeds/luci/luci-ssl)"
fi

if [ "$MODE" = "full" ]; then
  for pkg in luci-app-mosdns luci-app-turboacc luci-theme-aurora luci-app-arpbind; do
    [ -f "package/${pkg}/Makefile" ] || fail "missing custom package/${pkg}/Makefile"
  done
  [ -f package/nft-fullcone/Makefile ] \
    || fail "missing package/nft-fullcone (TurboACC fullcone kmod)"
fi

[ -d package ] || fail "package/ directory missing"

echo "==> verify-setup (${MODE}): OK"
