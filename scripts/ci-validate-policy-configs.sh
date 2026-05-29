#!/usr/bin/env bash
# Forbid Kconfig symbols that break LEDE defconfig or duplicate TurboACC enable path.
# Usage: ci-validate-policy-configs.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

forbid_in() {
  local file="$1"
  shift
  local pat
  for pat in "$@"; do
    if grep -qE "$pat" "$file"; then
      echo "ERROR: ${file#$ROOT/} must not contain: $pat" >&2
      fail=1
    fi
  done
}

POLICY_PATTERNS=(
  '^CONFIG_PACKAGE_dnsmasq-full=y'
  '^CONFIG_PACKAGE_dnsmasq_full_.*=y'
  '^CONFIG_PACKAGE_nftables-json=y'
  '^CONFIG_PACKAGE_nftables-nojson=y'
  '^CONFIG_PACKAGE_luci-app-turboacc=y'
  '^CONFIG_PACKAGE_kmod-nft-fullcone=y'
  '^CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_OFFLOADING=y'
)

check_file() {
  local f="$1"
  [ -f "$f" ] || return 0
  forbid_in "$f" "${POLICY_PATTERNS[@]}"
}

for repo in lede immortalwrt; do
  check_file "${ROOT}/configs/${repo}/common.config"
  while IFS= read -r dev || [ -n "$dev" ]; do
    dev="${dev%%#*}"
    dev="$(echo "$dev" | xargs)"
    [ -n "$dev" ] || continue
    check_file "${ROOT}/configs/${repo}/${dev}.config"
  done < "${ROOT}/configs/devices.list"
done

check_file "${ROOT}/configs/custom-plugins.config"

# turboacc.config is the only place that may enable TurboACC symbols
[ -f "${ROOT}/configs/snippets/turboacc.config" ] || {
  echo "ERROR: missing configs/snippets/turboacc.config" >&2
  exit 1
}

if [ "$fail" -ne 0 ]; then
  echo "ERROR: policy config validation failed" >&2
  exit 1
fi

echo "==> ci-validate-policy-configs: OK" >&2
