#!/usr/bin/env bash
# Merge device + common + custom-plugins into .config, then defconfig.
# Usage: ci-prepare-config.sh <repo> <device> <workspace> <src_dir>
#
# Order: device (TARGET) → common → custom-plugins → small snippets → sanitize → defconfig

set -euo pipefail

REPO="${1:?repo: lede|immortalwrt}"
DEVICE="${2:?device key}"
WORKSPACE="${3:?builder repo root}"
SRC_DIR="${4:?openwrt source dir}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$REPO" in
  lede|immortalwrt) ;;
  *) echo "ERROR: invalid repo '$REPO'" >&2; exit 1 ;;
esac

CONFIG_DIR="${WORKSPACE}/configs/${REPO}"
COMMON="${CONFIG_DIR}/common.config"
DEVICE_CFG="${CONFIG_DIR}/${DEVICE}.config"
CUSTOM="${WORKSPACE}/configs/custom-plugins.config"

for f in "$DEVICE_CFG" "$COMMON" "$CUSTOM"; do
  [ -f "$f" ] || {
    echo "ERROR: missing ${f}" >&2
    exit 1
  }
done

cd "$SRC_DIR"

# 1) Device target + per-device WiFi/drivers
cat "$DEVICE_CFG" > .config

# 2) Shared base (PassWall, LuCI, libs…) — same for all devices of this repo
cat "$COMMON" >> .config

# 3) Custom plugins (MosDNS, TurboACC, …)
cat "$CUSTOM" >> .config

# 4) Small policy snippets only (no dnsmasq-full, no turboacc INCLUDE)
for snip in \
  "${WORKSPACE}/configs/snippets/wireless-core.config" \
  "${WORKSPACE}/configs/snippets/luci-zh-cn.config" \
  "${WORKSPACE}/configs/snippets/no-rust-passwall.config" \
  "${WORKSPACE}/configs/snippets/no-selinux.config"; do
  [ -f "$snip" ] && cat "$snip" >> .config
done

echo "CONFIG_DEVEL=y" >> .config
echo "CONFIG_CCACHE=y" >> .config

bash "${SCRIPT_DIR}/sanitize-config.sh" "$(pwd)"

echo "==> .config merged and sanitized: ${REPO}/${DEVICE}"
