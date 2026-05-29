#!/usr/bin/env bash
# Remove duplicate luci-app-turboacc / nft-fullcone trees (feeds vs package/ clone).
# Keeps only package/luci-app-turboacc and package/nft-fullcone when present.
# Usage: purge-turboacc-duplicates.sh <src_dir>

set -euo pipefail

SRC_DIR="${1:?source directory required}"
cd "$SRC_DIR"

KEEP_LUCI=""
KEEP_KMOD=""
[ -f package/luci-app-turboacc/Makefile ] && KEEP_LUCI="$(cd package/luci-app-turboacc && pwd)"
[ -f package/nft-fullcone/Makefile ] && KEEP_KMOD="$(cd package/nft-fullcone && pwd)"

remove_dir() {
  local dir="$1" keep="$2"
  [ -n "$dir" ] || return 0
  [ -d "$dir" ] || return 0
  case "$dir" in
    package/luci-app-turboacc|./package/luci-app-turboacc|package/nft-fullcone|./package/nft-fullcone)
      # Never delete canonical custom package dirs.
      return 0
      ;;
  esac
  local abs
  abs="$(cd "$dir" && pwd)"
  if [ -n "$keep" ] && [ "$abs" = "$keep" ]; then
    return 0
  fi
  rm -rf "$dir"
  echo "==> purge-turboacc: removed ${dir}"
}

purge_makefiles() {
  local pattern="$1"
  local keep="$2"
  local mk dir
  while IFS= read -r mk; do
    [ -n "$mk" ] || continue
    case "$mk" in
      ./dl/*|./build_dir/*|./staging_dir/*|./.ci-stash-turboacc/*) continue ;;
    esac
    dir="$(dirname "$mk")"
    remove_dir "$dir" "$keep"
  done < <(grep -Rl --include='Makefile' "$pattern" feeds package/feeds package/lean 2>/dev/null || true)
}

purge_makefiles 'PKG_NAME:=luci-app-turboacc' "$KEEP_LUCI"
purge_makefiles 'PKG_NAME:=nft-fullcone' "$KEEP_KMOD"
purge_makefiles 'PKG_NAME:=kmod-nft-fullcone' "$KEEP_KMOD"

# KernelPackage/nft-fullcone outside our clone (feeds dupes)
while IFS= read -r mk; do
  [ -n "$mk" ] || continue
  case "$mk" in
    ./package/nft-fullcone/Makefile) continue ;;
    ./dl/*|./build_dir/*|./staging_dir/*|./.ci-stash-turboacc/*) continue ;;
  esac
  remove_dir "$(dirname "$mk")" "$KEEP_KMOD"
done < <(grep -Rl 'KernelPackage/nft-fullcone' feeds package/feeds package/lean 2>/dev/null || true)

# Feed source trees (prevent feeds install from re-linking lean/chenmozhijin dupes)
rm -rf \
  feeds/luci/applications/luci-app-turboacc \
  feeds/luci/applications/luci-app-turboacc-chenmozhijin 2>/dev/null || true

for base in feeds package/feeds package/lean; do
  [ -d "$base" ] || continue
  while IFS= read -r dir; do
    remove_dir "$dir" "$KEEP_LUCI"
  done < <(find "$base" -type d -name luci-app-turboacc 2>/dev/null || true)
  while IFS= read -r dir; do
    remove_dir "$dir" "$KEEP_KMOD"
  done < <(find "$base" -type d \( -name nft-fullcone -o -name kmod-nft-fullcone \) 2>/dev/null || true)
done

echo "==> purge-turboacc-duplicates: done (keep luci=${KEEP_LUCI:-none} kmod=${KEEP_KMOD:-none})"
