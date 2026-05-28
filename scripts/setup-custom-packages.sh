#!/usr/bin/env bash
# Setup feeds and clone custom packages for OpenWrt/LEDE builds.
# Usage: setup-custom-packages.sh <src_dir> [lede|append]

set -euo pipefail

SRC_DIR="${1:?source directory required (e.g. lede or src)}"
FEED_MODE="${2:-append}"

cd "$SRC_DIR"

echo "==> Configuring feeds (mode: $FEED_MODE)"
if [ "$FEED_MODE" = "lede" ]; then
  cat > feeds.conf.default << 'EOF'
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
src-git kenzo https://github.com/kenzok8/openwrt-packages.git
src-git small https://github.com/kenzok8/small.git
src-git packages https://git.openwrt.org/feed/packages.git;openwrt-23.05
src-git luci https://git.openwrt.org/project/luci.git;openwrt-23.05
EOF
else
  cat >> feeds.conf.default << 'EOF'

src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
src-git kenzo https://github.com/kenzok8/openwrt-packages.git
src-git small https://github.com/kenzok8/small.git

EOF
fi

./scripts/feeds update -a || ./scripts/feeds update -a

echo "==> Removing conflicting feed packages"
rm -rf feeds/kenzo/luci-theme-alpha feeds/kenzo/luci-app-dockerman 2>/dev/null || true
rm -rf feeds/luci/luci-app-dae feeds/luci/luci-app-daed 2>/dev/null || true
find feeds -name "*fchomo*" -type d -exec rm -rf {} + 2>/dev/null || true

echo "==> Installing feed dependencies"
FEED_PACKAGES=(
  bc pciutils lm-sensors wsdd2 luci-app-ksmbd luci-app-samba4
  libpam ddns-scripts wget-ssl luci-compat bash jq ntpdate
  smartmontools zoneinfo-all coreutils coreutils-nohup
  libunistring libxml2 liblzma libpcre2 libnetsnmp libcurl
  libtins libyaml-cpp glib2 libgpiod libtirpc libaio
  luci-lua-runtime maccalc luci-proto-ipv6
  dae-geoip dae-geosite daed-geoip daed-geosite
  hysteria xray-core sing-box v2ray-geodata geoview
  jsonfilter v2ray-geoip v2ray-geosite
  ttyd luci-app-ttyd libwebsockets-full libuv libjson-c libcap
  kmod-nft-offload kmod-nft-fullcone kmod-tcp-bbr
  ip
)

for pkg in "${FEED_PACKAGES[@]}"; do
  ./scripts/feeds install "$pkg" 2>/dev/null || echo "Skip feed package: $pkg"
done

./scripts/feeds install -a

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
