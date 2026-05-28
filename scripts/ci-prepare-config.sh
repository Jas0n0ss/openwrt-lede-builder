#!/usr/bin/env bash
# Assemble .config and run verify-defconfig.
# Usage: ci-prepare-config.sh <repo> <device> <workspace> <src_dir>

set -euo pipefail

REPO="${1:?repo: lede|immortalwrt}"
DEVICE="${2:?device key}"
WORKSPACE="${3:?builder repo root}"
SRC_DIR="${4:?openwrt source dir}"

case "$REPO" in
  lede|immortalwrt) ;;
  *) echo "ERROR: invalid repo '$REPO'" >&2; exit 1 ;;
esac

CONFIG_DIR="${WORKSPACE}/configs/${REPO}"
COMMON="${CONFIG_DIR}/common.config"
DEVICE_CFG="${CONFIG_DIR}/${DEVICE}.config"

[ -f "$DEVICE_CFG" ] || {
  echo "ERROR: missing ${DEVICE_CFG}" >&2
  exit 1
}

cd "$SRC_DIR"

if [ -f "$COMMON" ]; then
  cat "$COMMON" > .config
  cat "$DEVICE_CFG" >> .config
else
  cat "$DEVICE_CFG" > .config
fi

cat "${WORKSPACE}/configs/custom-plugins.config" >> .config
cat "${WORKSPACE}/configs/snippets/dnsmasq-full.config" >> .config
cat "${WORKSPACE}/configs/snippets/no-rust-passwall.config" >> .config
cat "${WORKSPACE}/configs/snippets/no-selinux.config" >> .config
cat "${WORKSPACE}/configs/snippets/no-nftables-json-dup.config" >> .config

# Strip lines that force Kconfig cycles when merged with defconfig
sed -i \
  -e '/^CONFIG_PACKAGE_kmod-nft-fullcone=y$/d' \
  -e '/^CONFIG_PACKAGE_kmod-nft-offload=y$/d' \
  -e '/^CONFIG_PACKAGE_kmod-tcp-bbr=y$/d' \
  -e '/^CONFIG_PACKAGE_dnsmasq_full_nftset=y$/d' \
  .config

echo "CONFIG_DEVEL=y" >> .config
echo "CONFIG_CCACHE=y" >> .config

bash "${WORKSPACE}/scripts/verify-defconfig.sh" "$(pwd)"
echo "==> .config ready for ${REPO}/${DEVICE}"
