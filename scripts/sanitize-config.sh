#!/usr/bin/env bash
# Final .config pass before base defconfig (dnsmasq / nftables-json only; TurboACC added later).
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
  -e '/^CONFIG_PACKAGE_nftables-json=y$/d' \
  -e '/^CONFIG_PACKAGE_nftables-nojson=y$/d' \
  -e '/^CONFIG_PACKAGE_luci-app-turboacc/d' \
  -e '/^CONFIG_PACKAGE_kmod-nft-fullcone=y$/d' \
  -e '/^CONFIG_PACKAGE_kmod-nft-offload=y$/d' \
  -e '/^CONFIG_PACKAGE_kmod-tcp-bbr=y$/d' \
  "$CFG"

sed -i \
  -e '/^# CONFIG_PACKAGE_dnsmasq-full is not set$/d' \
  -e '/^# CONFIG_PACKAGE_dnsmasq_full_/d' \
  -e '/^# CONFIG_PACKAGE_nftables-json is not set$/d' \
  -e '/^# CONFIG_PACKAGE_nftables-nojson is not set$/d' \
  "$CFG"

cat >>"$CFG" <<'EOF'

# --- Kconfig cycle guards (dnsmasq / duplicate nftables only) ---
# CONFIG_PACKAGE_dnsmasq-full is not set
# CONFIG_PACKAGE_dnsmasq_full_nftset is not set
# CONFIG_PACKAGE_dnsmasq_full_dhcp is not set
# CONFIG_PACKAGE_nftables-json is not set
# CONFIG_PACKAGE_nftables-nojson is not set
EOF

echo "==> sanitize-config: applied base Kconfig guards (TurboACC deferred)"
