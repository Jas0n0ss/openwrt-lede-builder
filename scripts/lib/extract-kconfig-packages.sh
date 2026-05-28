#!/usr/bin/env bash
# Print OpenWrt package names from CONFIG_PACKAGE_*=y lines (excludes INCLUDE/Including sub-options).
# Usage: extract-kconfig-packages.sh <config-file>...

set -euo pipefail

for cfg in "$@"; do
  [ -f "$cfg" ] || continue
  grep -E '^CONFIG_PACKAGE_[A-Za-z0-9][A-Za-z0-9._+-]*=y' "$cfg" \
    | sed 's/^CONFIG_PACKAGE_//;s/=y$//' \
    | grep -vE '_INCLUDE_|_Including_' || true
done
