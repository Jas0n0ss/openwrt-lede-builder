#!/usr/bin/env bash
# Setup feeds and clone custom packages for OpenWrt/LEDE builds.
# Usage: setup-custom-packages.sh <src_dir> [append] [config_root]

set -euo pipefail

SRC_DIR="${1:?source directory required}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="${3:-${SCRIPT_DIR}/../configs}"
EXTRACT_PKG="${SCRIPT_DIR}/lib/extract-kconfig-packages.sh"

cd "$SRC_DIR"

append_feed_line() {
  local line="$1"
  line="$(echo "$line" | xargs)"
  [ -n "$line" ] || return 0
  grep -qF "$line" feeds.conf.default 2>/dev/null || echo "$line" >> feeds.conf.default
}

install_pkg() {
  local pkg="$1"
  # Custom clones live under package/ — not in feeds index
  if [ -f "package/${pkg}/Makefile" ]; then
    return 0
  fi
  ./scripts/feeds install "$pkg" 2>/dev/null
}

clone_repo() {
  local dest="$1"
  shift
  rm -rf "$dest"
  git clone --depth 1 "$@" "$dest"
}

verify_makefile() {
  local path="$1"
  local name="$2"
  [ -f "$path" ] || {
    echo "ERROR: ${name} install failed (no ${path})" >&2
    exit 1
  }
}

echo "==> Appending PassWall feeds to feeds.conf.default"
if [ ! -f feeds.conf.default ]; then
  echo "ERROR: feeds.conf.default not found in $(pwd)" >&2
  exit 1
fi

PASSWALL_FEEDS='
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
'
while IFS= read -r line; do append_feed_line "$line"; done << EOF
${PASSWALL_FEEDS}
EOF

./scripts/feeds update -a

echo "==> Purging kenzo/small feeds (stale cache / Kconfig noise)"
sed -i '\|kenzok8/openwrt-packages|d; \|kenzok8/small|d' feeds.conf.default 2>/dev/null || true
rm -rf feeds/small feeds/kenzo package/feeds/small package/feeds/feeds/kenzo 2>/dev/null || true
rm -rf package/feeds/small package/feeds/kenzo 2>/dev/null || true
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  rm -rf "$dir"
  echo "==> Removed broken nftables feed dup: ${dir}"
done < <(find feeds package/feeds -maxdepth 5 -type d \( -name nftables-json -o -name nftables-nojson \) 2>/dev/null || true)

echo "==> Removing conflicting feed packages"
if [ -d feeds/kenzo ]; then
  rm -rf feeds/kenzo/luci-theme-alpha feeds/kenzo/luci-app-dockerman 2>/dev/null || true
fi
rm -rf feeds/luci/luci-app-dae feeds/luci/luci-app-daed 2>/dev/null || true
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  rm -rf "$dir"
done < <(find feeds -name '*fchomo*' -type d 2>/dev/null || true)

echo "==> Installing base feed packages (optional failures ignored)"
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
  install_pkg "$pkg" || echo "    skip optional feed package: ${pkg}"
done

echo "==> Installing PassWall feeds (required)"
./scripts/feeds install -p passwall_packages
./scripts/feeds install -p passwall_luci

bash "${SCRIPT_DIR}/patch-feeds.sh" "$(pwd)"
bash "${SCRIPT_DIR}/verify-setup.sh" "$(pwd)" feeds

echo "==> Cloning custom packages into package/"
mkdir -p package
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if [ ! -d package/luci-app-mosdns ]; then
  clone_repo "$TMPDIR/mosdns-src" -b v5 https://github.com/sbwml/luci-app-mosdns
  cp -a "$TMPDIR/mosdns-src/luci-app-mosdns" "$TMPDIR/mosdns-src/mosdns" "$TMPDIR/mosdns-src/v2dat" package/
  verify_makefile package/luci-app-mosdns/Makefile "MosDNS"
  verify_makefile package/mosdns/Makefile "mosdns"
  echo "    installed MosDNS"
fi

if [ ! -d package/luci-app-turboacc ]; then
  clone_repo "$TMPDIR/turboacc-luci" -b luci https://github.com/chenmozhijin/turboacc
  clone_repo "$TMPDIR/turboacc-pkg" -b package https://github.com/chenmozhijin/turboacc
  cp -a "$TMPDIR/turboacc-luci/luci-app-turboacc" package/
  cp -a "$TMPDIR/turboacc-pkg/nft-fullcone" package/ 2>/dev/null || true
  verify_makefile package/luci-app-turboacc/Makefile "TurboACC"
  echo "    installed TurboACC"
fi

if [ ! -d package/luci-theme-aurora ]; then
  clone_repo package/luci-theme-aurora https://github.com/eamonxg/luci-theme-aurora.git
  verify_makefile package/luci-theme-aurora/Makefile "Aurora"
  echo "    installed Aurora theme"
fi

if [ ! -d package/luci-app-arpbind ]; then
  clone_repo "$TMPDIR/immortal-luci" --filter=blob:none --sparse https://github.com/immortalwrt/luci
  (
    cd "$TMPDIR/immortal-luci"
    git sparse-checkout set applications/luci-app-arpbind
  )
  cp -a "$TMPDIR/immortal-luci/applications/luci-app-arpbind" package/
  verify_makefile package/luci-app-arpbind/Makefile "luci-app-arpbind"
  echo "    installed luci-app-arpbind"
fi

echo "==> Installing feed packages referenced in builder configs"
CONFIG_FILES=(
  "$CONFIG_ROOT/lede/common.config"
  "$CONFIG_ROOT/immortalwrt/common.config"
  "$CONFIG_ROOT/custom-plugins.config"
)
for cfg in "${CONFIG_FILES[@]}"; do
  [ -f "$cfg" ] || continue
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    install_pkg "$pkg" || echo "    skip config package: ${pkg}"
  done < <("$EXTRACT_PKG" "$cfg")
done

# feeds install may refresh passwall tree — re-apply Go version pins
bash "${SCRIPT_DIR}/patch-feeds.sh" "$(pwd)"
bash "${SCRIPT_DIR}/verify-setup.sh" "$(pwd)" full
echo "==> Custom package setup finished"
