#!/usr/bin/env bash
# Run make defconfig and fail on Kconfig recursive dependency errors.
# Usage: verify-defconfig.sh <src_dir>

set -euo pipefail

SRC_DIR="${1:?source directory required}"
cd "$SRC_DIR"

[ -f .config ] || { echo "ERROR: .config missing in $SRC_DIR" >&2; exit 1; }

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

set +e
make defconfig >"$log" 2>&1
rc=$?
set -e

cat "$log"

if [ "$rc" -ne 0 ]; then
  echo "ERROR: make defconfig failed (exit $rc)" >&2
  exit 1
fi

if grep -q 'recursive dependency detected' "$log"; then
  echo "ERROR: Kconfig recursive dependency — fix feeds/.config" >&2
  exit 1
fi

if grep -q '^CONFIG_PACKAGE_libselinux=y' .config; then
  echo "ERROR: libselinux is enabled — append configs/snippets/no-selinux.config" >&2
  exit 1
fi

echo "==> verify-defconfig: OK"
