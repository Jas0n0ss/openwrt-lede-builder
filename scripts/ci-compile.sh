#!/usr/bin/env bash
# Download sources and compile firmware; always exits non-zero on failure.
# Usage: ci-compile.sh <src_dir> [toolchain_first]

set -euo pipefail

SRC_DIR="${1:?source directory required}"
TOOLCHAIN_FIRST="${2:-}"

if [[ "$SRC_DIR" != /* ]]; then
  SRC_DIR="$(cd "$SRC_DIR" && pwd)"
fi

cd "$SRC_DIR"

[ -f .config ] || {
  echo "ERROR: .config missing — run ci-prepare-config.sh first" >&2
  exit 1
}

export PATH="/usr/lib/ccache:${PATH:-}"
ulimit -n 65535 || true

ccache -s 2>/dev/null || true

make download -j16 || make download -j8

if [ "$TOOLCHAIN_FIRST" = "1" ]; then
  make toolchain/compile -j"$(nproc)" || make toolchain/compile -j1 V=s
fi

if ! make -j"$(nproc)"; then
  echo "==> Parallel build failed, retrying -j1 V=s..."
  make -j1 V=s
fi

ccache -s 2>/dev/null || true
echo "==> ci-compile: OK"
