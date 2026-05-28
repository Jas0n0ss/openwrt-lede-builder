#!/usr/bin/env bash
# Setup feeds and clone custom packages for OpenWrt/LEDE builds.
# Usage: setup-custom-packages.sh <src_dir> [lede|append]
#
# Only installs feeds/packages required by configs/common.config and
# configs/custom-plugins.config. Does NOT run "feeds install -a".

set -euo pipefail

SRC_DIR="${1:?source directory required (e.g. lede or src)}"
FEED_MODE="${2:-append}"

cd "$SRC_DIR"

echo "==> Configuring feeds (mode: $FEED_MODE)"
if [ "$FEED_MODE" = "lede" ]; then
  cat > feeds.conf.default << 'EOF'
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
src-git packages https://git.openwrt.org/feed/packages.git;openwrt-23.05
src-git luci https://git.openwrt.org/project/luci.git;openwrt-23.05
EOF
else
  # Append PassWall feeds only; keep upstream feeds.conf (ImmortalWrt/LEDE defaults).
  if ! grep -q 'passwall_packages' feeds.conf.default 2>/dev/null; then
    cat >> feeds.conf.default << 'EOF'

src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main

EOF
  fi
fi

./scripts/feeds update -a

echo "==> Installing required feed packages (targeted only)"
install_pkg() {
  local pkg="$1"
  if ./scripts/feeds install "$pkg" 2>/dev/null; then
    return 0
  fi
  echo "Skip feed package: $pkg"
  return 1
}

# Base libraries first (PassWall shadowsocks-* need pcre2/libxml2 in the index)
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
)

for pkg in "${BASE_PACKAGES[@]}"; do
  install_pkg "$pkg" || true
done

# PassWall feeds (all binaries + LuCI app) — after base deps are linked
./scripts/feeds install -p passwall_packages
./scripts/feeds install -p passwall_luci

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
