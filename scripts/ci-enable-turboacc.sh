#!/usr/bin/env bash
# Enable TurboACC + kernel deps after clean defconfig (breaks LEDE Kconfig cycle).
# Usage: ci-enable-turboacc.sh <src_dir> <workspace>

set -euo pipefail

SRC_DIR="${1:?source directory required}"
WORKSPACE="${2:?builder repo root}"
CFG_SNIP="${WORKSPACE}/configs/snippets/turboacc.config"
cd "$SRC_DIR"

[ -f "$CFG_SNIP" ] || {
  echo "ERROR: missing ${CFG_SNIP}" >&2
  exit 1
}

[ -f package/luci-app-turboacc/Makefile ] || {
  echo "ERROR: luci-app-turboacc not installed — run setup-custom-packages.sh" >&2
  exit 1
}

[ -f package/nft-fullcone/Makefile ] || {
  echo "ERROR: package/nft-fullcone missing — TurboACC kernel module not cloned" >&2
  exit 1
}

[ -x ./scripts/config ] || {
  echo "ERROR: ./scripts/config not found in $(pwd)" >&2
  exit 1
}

# Merge snippet into .config
cat "$CFG_SNIP" >> .config

# Order matters: kernel module first, then LuCI app + INCLUDE options
./scripts/config -e PACKAGE_kmod-nft-fullcone
./scripts/config -e PACKAGE_kmod-tcp-bbr
./scripts/config -d PACKAGE_kmod-nft-offload 2>/dev/null || true
./scripts/config -e PACKAGE_luci-app-turboacc
./scripts/config -e PACKAGE_luci-app-turboacc_INCLUDE_BBR_CCA
./scripts/config -e PACKAGE_luci-app-turboacc_INCLUDE_NFT_FULLCONE
./scripts/config -d PACKAGE_luci-app-turboacc_INCLUDE_OFFLOADING 2>/dev/null || true

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

set +e
make oldconfig >"$log" 2>&1
rc=$?
set -e

cat "$log"

if [ "$rc" -ne 0 ]; then
  echo "ERROR: make oldconfig after TurboACC enable failed (exit $rc)" >&2
  exit 1
fi

if grep -q 'recursive dependency detected' "$log"; then
  echo "ERROR: TurboACC oldconfig still has recursive dependency" >&2
  exit 1
fi

for sym in luci-app-turboacc kmod-nft-fullcone kmod-tcp-bbr; do
  grep -q "^CONFIG_PACKAGE_${sym}=y" .config || {
    echo "ERROR: CONFIG_PACKAGE_${sym}=y missing after TurboACC enable" >&2
    exit 1
  }
done

grep -q '^# CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_OFFLOADING is not set' .config \
  || grep -q '^CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_OFFLOADING is not set' .config \
  || {
    echo "ERROR: TurboACC OFFLOADING must stay disabled" >&2
    exit 1
  }

echo "==> ci-enable-turboacc: OK (luci-app-turboacc + kmod-nft-fullcone + kmod-tcp-bbr)"
