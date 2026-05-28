#!/usr/bin/env bash
# Setup feeds and clone custom packages for OpenWrt/LEDE builds.
# Usage: setup-custom-packages.sh <src_dir> [lede|append] [config_root]
#
# Does NOT run "feeds install -a" or bulk kenzo/small install (Kconfig cycles).
# Instead:
#   - feeds install -p passwall_* + targeted packages from builder .config
#   - scripts/patch-feeds.sh pins xray-core for golang/host 1.21

set -euo pipefail

SRC_DIR="${1:?source directory required (e.g. lede or src)}"
FEED_MODE="${2:-append}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="${3:-${SCRIPT_DIR}/../configs}"

cd "$SRC_DIR"

PASSWALL_FEEDS='
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
'
# kenzo/small bulk install causes Kconfig cycles (luci-ssl, unblockneteasemusic, nftables-json).

echo "==> Configuring feeds (mode: $FEED_MODE)"
if [ "$FEED_MODE" = "lede" ]; then
  cat > feeds.conf.default << EOF
${PASSWALL_FEEDS}
src-git packages https://git.openwrt.org/feed/packages.git;openwrt-23.05
src-git luci https://git.openwrt.org/project/luci.git;openwrt-23.05
EOF
else
  append_feed_line() {
    local line="$1"
    [ -n "$line" ] || return 0
    grep -qF "$line" feeds.conf.default 2>/dev/null || echo "$line" >> feeds.conf.default
  }
  while IFS= read -r line; do append_feed_line "$line"; done << EOF
${PASSWALL_FEEDS}
EOF
fi

./scripts/feeds update -a

echo "==> Removing conflicting feed packages"
rm -rf feeds/kenzo/luci-theme-alpha feeds/kenzo/luci-app-dockerman 2>/dev/null || true
rm -rf feeds/luci/luci-app-dae feeds/luci/luci-app-daed 2>/dev/null || true
find feeds -name "*fchomo*" -type d -exec rm -rf {} + 2>/dev/null || true

echo "==> Installing required feed packages (targeted)"
install_pkg() {
  local pkg="$1"
  if ./scripts/feeds install "$pkg" 2>/dev/null; then
    return 0
  fi
  return 1
}

# Base libraries first (PassWall / shadowsocks need these in the index)
BASE_PACKAGES=(
  pcre2 libpcre2 libxml2 libunistring
  libev libsodium c-ares libcurl libudns
  boost boost-system boost-program_options boost-date_time
  rust
  coreutils coreutils-nohup unzip bc pciutils lm-sensors jq yq
  libpam zoneinfo-all
  luci-compat luci-proto-ipv6 luci-lua-runtime
  ttyd luci-app-ttyd libwebsockets-full libuv libjson-c libcap
  kmod-nft-offload kmod-nft-fullcone kmod-tcp-bbr
  jsonfilter v2ray-geoip v2ray-geosite
  golang
)

for pkg in "${BASE_PACKAGES[@]}"; do
  install_pkg "$pkg" || echo "Skip feed package: $pkg"
done

# PassWall only (avoid kenzo/small bulk install → Kconfig recursive deps)
./scripts/feeds install -p passwall_packages 2>/dev/null || true
./scripts/feeds install -p passwall_luci 2>/dev/null || true

bash "${SCRIPT_DIR}/patch-feeds.sh" "$(pwd)"

# Packages explicitly enabled in builder configs (any feed)
echo "==> Installing packages from builder config files"
CONFIG_FILES=(
  "$CONFIG_ROOT/lede/common.config"
  "$CONFIG_ROOT/immortalwrt/common.config"
  "$CONFIG_ROOT/custom-plugins.config"
)
installed_configs=0
for cfg in "${CONFIG_FILES[@]}"; do
  [ -f "$cfg" ] || continue
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    install_pkg "$pkg" || true
    installed_configs=$((installed_configs + 1))
  done < <(grep -E '^CONFIG_PACKAGE_[^=]+=y' "$cfg" | sed 's/^CONFIG_PACKAGE_//;s/=y$//')
done
echo "    Processed CONFIG_PACKAGE entries from builder configs"

echo "==> Cloning custom packages into package/"
mkdir -p package
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# MosDNS (sbwml v5: luci-app-mosdns + mosdns + v2dat)
if [ ! -d package/luci-app-mosdns ]; then
  git clone --depth 1 -b v5 https://github.com/sbwml/luci-app-mosdns "$TMPDIR/mosdns-src"
  cp -r "$TMPDIR/mosdns-src/luci-app-mosdns" "$TMPDIR/mosdns-src/mosdns" "$TMPDIR/mosdns-src/v2dat" package/
  echo "Installed MosDNS packages"
fi

# TurboACC (chenmozhijin/turboacc, nft-fullcone only for CI stability)
if [ ! -d package/luci-app-turboacc ]; then
  git clone --depth 1 -b luci https://github.com/chenmozhijin/turboacc "$TMPDIR/turboacc-luci"
  git clone --depth 1 -b package https://github.com/chenmozhijin/turboacc "$TMPDIR/turboacc-pkg"
  cp -r "$TMPDIR/turboacc-luci/luci-app-turboacc" package/
  cp -r "$TMPDIR/turboacc-pkg/nft-fullcone" package/ 2>/dev/null || true
  echo "Installed TurboACC packages"
fi

# Aurora theme
if [ ! -d package/luci-theme-aurora ]; then
  git clone --depth 1 https://github.com/eamonxg/luci-theme-aurora.git package/luci-theme-aurora || true
  echo "Installed Aurora theme"
fi

# ARP bind (ImmortalWrt luci app)
if [ ! -d package/luci-app-arpbind ]; then
  git clone --depth 1 --filter=blob:none --sparse https://github.com/immortalwrt/luci "$TMPDIR/immortal-luci"
  (
    cd "$TMPDIR/immortal-luci"
    git sparse-checkout set applications/luci-app-arpbind
  )
  cp -r "$TMPDIR/immortal-luci/applications/luci-app-arpbind" package/
  echo "Installed luci-app-arpbind"
fi

echo "==> Custom package setup finished (packages under package/ are picked up by the build system)"
