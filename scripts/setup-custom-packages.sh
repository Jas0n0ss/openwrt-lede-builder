#!/usr/bin/env bash
# Setup feeds and clone custom packages for OpenWrt/LEDE builds.
# Usage: setup-custom-packages.sh <src_dir> [append] [config_root]
#
# Always appends PassWall feeds to the tree's feeds.conf.default (never replaces LEDE feeds).
# Does NOT bulk-install kenzo/small (Kconfig cycles). Pins Go packages via patch-feeds.sh.

set -euo pipefail

SRC_DIR="${1:?source directory required (e.g. lede or src)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="${3:-${SCRIPT_DIR}/../configs}"

cd "$SRC_DIR"

PASSWALL_FEEDS='
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
'

append_feed_line() {
  local line="$1"
  line="$(echo "$line" | xargs)"
  [ -n "$line" ] || return 0
  grep -qF "$line" feeds.conf.default 2>/dev/null || echo "$line" >> feeds.conf.default
}

echo "==> Appending PassWall feeds to feeds.conf.default"
if [ ! -f feeds.conf.default ]; then
  echo "ERROR: feeds.conf.default not found in $(pwd)" >&2
  exit 1
fi
while IFS= read -r line; do append_feed_line "$line"; done << EOF
${PASSWALL_FEEDS}
EOF

./scripts/feeds update -a

echo "==> Purging kenzo/small feeds (stale cache / Kconfig noise)"
sed -i '\|kenzok8/openwrt-packages|d; \|kenzok8/small|d' feeds.conf.default 2>/dev/null || true
rm -rf feeds/small feeds/kenzo package/feeds/small package/feeds/kenzo 2>/dev/null || true

echo "==> Removing conflicting feed packages"
if [ -d feeds/kenzo ]; then
  rm -rf feeds/kenzo/luci-theme-alpha feeds/kenzo/luci-app-dockerman 2>/dev/null || true
fi
rm -rf feeds/luci/luci-app-dae feeds/luci/luci-app-daed 2>/dev/null || true
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  rm -rf "$dir"
done < <(find feeds -name '*fchomo*' -type d 2>/dev/null || true)

echo "==> Installing required feed packages (targeted)"
install_pkg() {
  local pkg="$1"
  ./scripts/feeds install "$pkg"
}

# Base libraries (failures are non-fatal; PassWall install is mandatory)
BASE_PACKAGES=(
  pcre2 libpcre2 libpcre2-8 libxml2 libunistring
  libev libsodium c-ares libcurl libudns
  boost boost-system boost-program_options boost-date_time
  coreutils coreutils-nohup unzip bc pciutils lm-sensors jq yq
  libpam zoneinfo-all
  luci-compat luci-proto-ipv6 luci-lua-runtime
  ttyd luci-app-ttyd libwebsockets-full libuv libjson-c libcap
  kmod-nft-offload kmod-nft-fullcone kmod-tcp-bbr
  jsonfilter v2ray-geoip v2ray-geosite
  golang
)

for pkg in "${BASE_PACKAGES[@]}"; do
  install_pkg "$pkg" 2>/dev/null || echo "    skip optional feed package: $pkg"
done

echo "==> Installing PassWall feeds (required)"
./scripts/feeds install -p passwall_packages
./scripts/feeds install -p passwall_luci

bash "${SCRIPT_DIR}/patch-feeds.sh" "$(pwd)"
bash "${SCRIPT_DIR}/verify-setup.sh" "$(pwd)"

echo "==> Installing packages from builder config files"
CONFIG_FILES=(
  "$CONFIG_ROOT/lede/common.config"
  "$CONFIG_ROOT/immortalwrt/common.config"
  "$CONFIG_ROOT/custom-plugins.config"
)
for cfg in "${CONFIG_FILES[@]}"; do
  [ -f "$cfg" ] || continue
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    install_pkg "$pkg" 2>/dev/null || echo "    skip config package: $pkg"
  done < <(grep -E '^CONFIG_PACKAGE_[^=]+=y' "$cfg" | sed 's/^CONFIG_PACKAGE_//;s/=y$//')
done

echo "==> Cloning custom packages into package/"
mkdir -p package
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if [ ! -d package/luci-app-mosdns ]; then
  git clone --depth 1 -b v5 https://github.com/sbwml/luci-app-mosdns "$TMPDIR/mosdns-src"
  cp -a "$TMPDIR/mosdns-src/luci-app-mosdns" "$TMPDIR/mosdns-src/mosdns" "$TMPDIR/mosdns-src/v2dat" package/
  echo "    installed MosDNS"
fi

if [ ! -d package/luci-app-turboacc ]; then
  git clone --depth 1 -b luci https://github.com/chenmozhijin/turboacc "$TMPDIR/turboacc-luci"
  git clone --depth 1 -b package https://github.com/chenmozhijin/turboacc "$TMPDIR/turboacc-pkg"
  cp -a "$TMPDIR/turboacc-luci/luci-app-turboacc" package/
  cp -a "$TMPDIR/turboacc-pkg/nft-fullcone" package/ 2>/dev/null || true
  echo "    installed TurboACC"
fi

if [ ! -d package/luci-theme-aurora ]; then
  git clone --depth 1 https://github.com/eamonxg/luci-theme-aurora.git package/luci-theme-aurora
  echo "    installed Aurora theme"
fi

if [ ! -d package/luci-app-arpbind ]; then
  git clone --depth 1 --filter=blob:none --sparse https://github.com/immortalwrt/luci "$TMPDIR/immortal-luci"
  (
    cd "$TMPDIR/immortal-luci"
    git sparse-checkout set applications/luci-app-arpbind
  )
  cp -a "$TMPDIR/immortal-luci/applications/luci-app-arpbind" package/
  echo "    installed luci-app-arpbind"
fi

bash "${SCRIPT_DIR}/verify-setup.sh" "$(pwd)"
echo "==> Custom package setup finished"
