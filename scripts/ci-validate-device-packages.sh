#!/usr/bin/env bash
# Sanity-check device .config for target symbol and platform WiFi packages.
# Usage: ci-validate-device-packages.sh <repo>

set -uo pipefail

REPO="${1:?repo: lede|immortalwrt}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="${ROOT}/configs/devices.list"

case "$REPO" in
  lede|immortalwrt) ;;
  *) echo "ERROR: invalid repo '$REPO'" >&2; exit 1 ;;
esac

require_in() {
  local file="$1"
  shift
  local pat
  for pat in "$@"; do
    if ! grep -qE "$pat" "$file"; then
      echo "ERROR: ${file#$ROOT/} missing required pattern: $pat" >&2
      return 1
    fi
  done
  return 0
}

forbid_in() {
  local file="$1"
  shift
  local pat
  for pat in "$@"; do
    if grep -qE "$pat" "$file"; then
      echo "ERROR: ${file#$ROOT/} must not contain: $pat" >&2
      return 1
    fi
  done
  return 0
}

fail=0
while IFS= read -r dev || [ -n "$dev" ]; do
  dev="${dev%%#*}"
  dev="$(echo "$dev" | xargs)"
  [ -n "$dev" ] || continue

  cfg="${ROOT}/configs/${REPO}/${dev}.config"
  [ -f "$cfg" ] || { echo "ERROR: missing $cfg" >&2; fail=1; continue; }

  grep -q '^CONFIG_TARGET_.*_DEVICE_.*=y' "$cfg" || {
    echo "ERROR: $cfg has no CONFIG_TARGET_*_DEVICE_*=y" >&2
    fail=1
    continue
  }

  grep -q '^CONFIG_PACKAGE_wpad-openssl=y' "$cfg" || {
    echo "ERROR: $cfg missing CONFIG_PACKAGE_wpad-openssl=y" >&2
    fail=1
  }

  case "$dev" in
    phicomm-k2p)
      if [ "$REPO" = "lede" ]; then
        require_in "$cfg" \
          '^CONFIG_PACKAGE_kmod-mt7615d_dbdc=y' \
          '^CONFIG_PACKAGE_kmod-mt7615d=y' \
          '^CONFIG_PACKAGE_maccalc=y' \
          '^CONFIG_PACKAGE_wireless-tools=y' || fail=1
        forbid_in "$cfg" '^CONFIG_PACKAGE_kmod-mt7615e=y' || fail=1
      else
        require_in "$cfg" \
          '^CONFIG_PACKAGE_kmod-mt7615-firmware=y' \
          '^CONFIG_PACKAGE_kmod-mt7615e=y' || fail=1
        forbid_in "$cfg" \
          '^CONFIG_PACKAGE_kmod-mt7615d_dbdc=y' \
          '^CONFIG_PACKAGE_kmod-mt7615d=y' \
          '^CONFIG_PACKAGE_maccalc=y' || fail=1
      fi
      ;;
    xiaomi-wr30u|xiaomi-ax6000|redmi-ax6000)
      # turboacc enabled in ci-enable-turboacc.sh, not in device .config
      require_in "$cfg" \
        '^CONFIG_PACKAGE_kmod-mt7915e=y' \
        '^CONFIG_PACKAGE_.*-firmware=y' \
        '^CONFIG_PACKAGE_.*-wo-firmware=y' || fail=1
      if [ "$REPO" = "immortalwrt" ]; then
        grep -qE '^CONFIG_TARGET_.*_DEVICE_.*-stock=y' "$cfg" || {
          echo "ERROR: $cfg ImmortalWrt filogic devices must use *-stock target" >&2
          fail=1
        }
      fi
      ;;
    xiaomi-ax3600)
      require_in "$cfg" \
        '^CONFIG_PACKAGE_ipq-wifi-xiaomi_ax3600=y' \
        '^CONFIG_PACKAGE_kmod-ath11k' || fail=1
      ;;
    xiaomi-ax9000)
      require_in "$cfg" \
        '^CONFIG_PACKAGE_ipq-wifi-xiaomi_ax9000=y' \
        '^CONFIG_PACKAGE_kmod-ath11k-pci=y' \
        '^CONFIG_PACKAGE_ath11k-firmware-qcn9074=y' || fail=1
      ;;
    xiaomi-3g)
      require_in "$cfg" \
        '^CONFIG_PACKAGE_kmod-mt7603=y' \
        '^CONFIG_PACKAGE_kmod-mt76x2=y' || fail=1
      ;;
    xiaomi-cr660x)
      require_in "$cfg" \
        '^CONFIG_PACKAGE_kmod-mt7915e=y' \
        '^CONFIG_PACKAGE_kmod-mt7915-firmware=y' || fail=1
      if [ "$REPO" = "immortalwrt" ]; then
        grep -q 'DEVICE_xiaomi_mi-router-cr660[689]=y' "$cfg" || {
          echo "ERROR: $cfg ImmortalWrt CR660x must target cr6606/8/9 (not cr660x)" >&2
          fail=1
        }
      else
        grep -q 'DEVICE_xiaomi_mi-router-cr660x=y' "$cfg" || {
          echo "ERROR: ${cfg#$ROOT/} must use DEVICE_xiaomi_mi-router-cr660x=y (LEDE)" >&2
          fail=1
        }
      fi
      ;;
    raspberrypi-4b)
      require_in "$cfg" \
        '^CONFIG_PACKAGE_kmod-brcmfmac=y' \
        '^CONFIG_PACKAGE_kmod-brcmutil=y' || fail=1
      ;;
    r2s|x86_64)
      # AP optional on gateway boards — only wpad required (checked above)
      ;;
  esac
done < "$LIST"

if [ "$fail" -ne 0 ]; then
  echo "ERROR: device package validation failed for ${REPO}" >&2
  exit 1
fi
echo "==> ci-validate-device-packages: OK (${REPO})" >&2
