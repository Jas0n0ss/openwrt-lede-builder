# CI 说明

唯一工作流：`.github/workflows/build.yml`（`build-lede.yml` / `build-immortalwrt.yml` 已移除）。

脚本：`ci-resolve-build.sh`、`ci-prepare-config.sh` 与 feeds/compile 脚本配合使用。

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

## libselinux / pcre2

已禁用 `libselinux`/`libsepol`（路由器不需要 SELinux，且易在 `pcre2.h` 未进 staging 时编译失败）。`common.config` 中保留 `pcre2` + `libpcre2` 供 PassWall 等使用。

## 不编译的包（避免 rust/gn）

`shadowsocks-rust`、`naiveproxy` 会拉取 `rust`/`gn` host 编译，已在 `common.config` 关闭，并由 `configs/snippets/no-rust-passwall.config` 兜底。

## TurboACC

已关闭 `INCLUDE_OFFLOADING`（`kmod-fast-classifier` / shortcut-fe 仅部分平台存在）。保留 BBR + nft-fullcone。

## 缓存

`feeds-*-v6-*` / `dl-*-v6-*`：setup 逻辑或 `extract-kconfig-packages` 变更时递增版本，避免旧 feeds 树（含 kenzo/small）被复用。setup 会删除 `package/feeds/small` 残留。

## CONFIG_PACKAGE 解析

`setup-custom-packages.sh` 用 [`scripts/lib/extract-kconfig-packages.sh`](../scripts/lib/extract-kconfig-packages.sh) 从 config 提取包名，**排除** `*_INCLUDE_*` / `*_Including_*`（如 TurboACC 子选项、PassWall 组件开关），避免误执行 `feeds install`。config 驱动安装后仍会再跑 `patch-feeds.sh`。

## setup 校验

- `verify-setup.sh feeds`：PassWall + xray/sing-box 版本
- `verify-setup.sh full`：MosDNS / TurboACC / Aurora / arpbind 的 `package/*/Makefile`
- 克隆失败立即 `exit 1`（不再静默继续）

## matrix / GITHUB_OUTPUT

`ci-resolve-build.sh` 仅向 stdout 写 `repo=`、`upstream=`、`matrix=`；`ci-validate-configs.sh` 日志走 stderr，避免污染 `GITHUB_OUTPUT`。

## Actions Node 警告

在 GitHub **Settings → Actions → Variables** 删除 `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` 与 `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION`（非本仓库 workflow 定义）。
