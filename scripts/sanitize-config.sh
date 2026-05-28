#!/usr/bin/env bash
# Remove .config lines known to trigger Kconfig recursive dependencies on LEDE.
# Usage: sanitize-config.sh <src_dir>

set -euo pipefail

SRC_DIR="${1:?source directory required}"
CFG="${SRC_DIR}/.config"

[ -f "$CFG" ] || {
  echo "ERROR: missing ${CFG}" >&2
  exit 1
}

sed -i \
  -e '/^CONFIG_PACKAGE_dnsmasq-full=y$/d' \
  -e '/^CONFIG_PACKAGE_dnsmasq_full_/d' \
  -e '/^# CONFIG_PACKAGE_dnsmasq is not set$/d' \
  -e '/^CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_/d' \
  -e '/^CONFIG_PACKAGE_kmod-nft-fullcone=y$/d' \
  -e '/^CONFIG_PACKAGE_kmod-nft-offload=y$/d' \
  -e '/^CONFIG_PACKAGE_kmod-tcp-bbr=y$/d' \
  "$CFG"

# Explicit disables (safe with merged .config)
{
  echo '# CONFIG_PACKAGE_nftables-json is not set'
  echo '# CONFIG_PACKAGE_nftables-nojson is not set'
} >> "$CFG"

echo "==> sanitize-config: stripped cycle-prone symbols"
