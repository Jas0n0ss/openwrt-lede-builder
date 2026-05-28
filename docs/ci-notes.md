# CI 说明

## Feeds（LEDE）

**不要**覆盖 `feeds.conf.default`。LEDE 使用 `coolsnowwolf/packages`、`coolsnowwolf/luci` 等；`setup-custom-packages.sh` 仅 **追加** PassWall 两条 feed。

## Go 包版本（golang/host ~1.21）

| 包 | 上游默认 | 构建固定 |
|----|----------|----------|
| xray-core | 26.x (Go 1.26+) | 24.12.31 |
| sing-box | 1.13.x (Go 1.24+) | 1.11.0 |

由 [`scripts/patch-feeds.sh`](../scripts/patch-feeds.sh) 写入；[`scripts/verify-setup.sh`](../scripts/verify-setup.sh) 在 feeds 步骤末尾校验。

## Kconfig 循环依赖

禁止 `feeds install -p kenzo|small` 全量安装。`common.config` 已禁用 `luci-app-unblockneteasemusic` 等冲突包。

## 构建脚本链

1. `setup-custom-packages.sh` → `patch-feeds.sh` → `verify-setup.sh`
2. 生成 `.config` → `verify-defconfig.sh`
3. `ci-compile.sh`（失败会 `exit 1`，并行失败会 `-j1 V=s` 重试）
4. `pack-firmware.sh`（无镜像则失败）

## 不编译的包（避免 rust/gn）

`shadowsocks-rust`、`naiveproxy` 会拉取 `rust`/`gn` host 编译，已在 `common.config` 关闭，并由 `configs/snippets/no-rust-passwall.config` 兜底。

## TurboACC

已关闭 `INCLUDE_OFFLOADING`（`kmod-fast-classifier` / shortcut-fe 仅部分平台存在）。保留 BBR + nft-fullcone。

## 缓存

`feeds-*-v4-*` key 用于避开含 kenzo/small 的旧 feeds 缓存；setup 会删除 `package/feeds/small` 残留。

## Actions Node 警告

在 GitHub **Settings → Actions → Variables** 删除 `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` 与 `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION`（非本仓库 workflow 定义）。
