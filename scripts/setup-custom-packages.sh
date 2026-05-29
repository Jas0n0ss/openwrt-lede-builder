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

bash "${SCRIPT_DIR}/ci-fix-kconfig-tree.sh" "$(pwd)"

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

echo "==> Removing conflicting feed packages"
rm -rf feeds/luci/luci-app-dae feeds/luci/luci-app-daed 2>/dev/null || true
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  rm -rf "$dir"
done < <(find feeds -name '*fchomo*' -type d 2>/dev/null || true)

echo "==> Installing base feed packages (optional failures ignored)"
BASE_PACKAGES=(
  maccalc wireless-regdb iw luci-ssl
  luci-i18n-passwall-zh-cn luci-i18n-opkg-zh-cn luci-i18n-ttyd-zh-cn luci-i18n-arpbind-zh-cn
  kmod-mt7615-firmware kmod-mt7915-firmware
  kmod-tcp-bbr
  pcre2 libpcre2 libpcre2-8 libxml2 libunistring
  libev libsodium c-ares libcurl libudns
  boost boost-system boost-program_options boost-date_time
  coreutils coreutils-nohup unzip bc pciutils lm-sensors jq yq
  libpam zoneinfo-all
  luci-compat luci-proto-ipv6 luci-lua-runtime
  ttyd luci-app-ttyd libwebsockets-full libuv libjson-c libcap
  kmod-nft-core kmod-nf-conntrack
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

if [ ! -d package/luci-app-turboacc ] || [ ! -d package/nft-fullcone ]; then
  rm -rf package/luci-app-turboacc package/nft-fullcone 2>/dev/null || true
  clone_repo "$TMPDIR/turboacc-luci" -b luci https://github.com/chenmozhijin/turboacc
  clone_repo "$TMPDIR/turboacc-pkg" -b package https://github.com/chenmozhijin/turboacc
  cp -a "$TMPDIR/turboacc-luci/luci-app-turboacc" package/
  cp -a "$TMPDIR/turboacc-pkg/nft-fullcone" package/
  verify_makefile package/luci-app-turboacc/Makefile "TurboACC LuCI"
  verify_makefile package/nft-fullcone/Makefile "nft-fullcone kernel module"
  bash "${SCRIPT_DIR}/patch-turboacc-packages.sh" "$(pwd)"
  bash "${SCRIPT_DIR}/purge-turboacc-duplicates.sh" "$(pwd)"
  echo "    installed TurboACC (luci-app-turboacc + nft-fullcone)"
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
  "$CONFIG_ROOT/snippets/turboacc.config"
)
for cfg in "${CONFIG_FILES[@]}"; do
  [ -f "$cfg" ] || continue
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    case "$pkg" in
      nftables-json|nftables-nojson) continue ;;
      luci-app-turboacc|kmod-nft-fullcone|kmod-nft-offload) continue ;;
    esac
    install_pkg "$pkg" || echo "    skip config package: ${pkg}"
  done < <("$EXTRACT_PKG" "$cfg")
done

bash "${SCRIPT_DIR}/ci-fix-kconfig-tree.sh" "$(pwd)"
bash "${SCRIPT_DIR}/verify-setup.sh" "$(pwd)" full

# TurboACC tree must be complete before image build
for req in package/luci-app-turboacc/Makefile package/nft-fullcone/Makefile; do
  [ -f "$req" ] || {
    echo "ERROR: TurboACC incomplete: missing ${req}" >&2
    exit 1
  }
done

echo "==> Custom package setup finished"
