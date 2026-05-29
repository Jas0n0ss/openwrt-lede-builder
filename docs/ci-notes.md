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

**不要**在 `.config` 里写 `CONFIG_PACKAGE_kmod-nft-fullcone=y`：会与 `luci-app-turboacc` 的 `DEPENDS`/`select` 形成 Kconfig 环；只开 `luci-app-turboacc` + `INCLUDE_NFT_FULLCONE` 即可。

## 生成 .config（ci-prepare-config.sh）

合并顺序（与用户预期一致）：

1. `configs/<repo>/<device>.config` — TARGET + 机型 WiFi/驱动  
2. `configs/<repo>/common.config` — PassWall、LuCI、公共库  
3. `configs/custom-plugins.config` — MosDNS、TurboACC 等  

然后 `sanitize-config.sh` 删除会触发 **Kconfig 环** 的行，再 `make defconfig`。

**禁止写入合并 .config 的项：**

| 禁止 | 原因 |
|------|------|
| `CONFIG_PACKAGE_dnsmasq-full=y` / `dnsmasq_full_*` | 与 `dnsmasq_full_nftset` 递归依赖 |
| `CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_*=y` | 与 `kmod-nft-fullcone` 递归依赖 |
| `CONFIG_PACKAGE_kmod-nft-fullcone=y` 等 | 应由 TurboACC 的 DEPENDS 拉取 |

dnsmasq 使用 target 自带的 **DEFAULT_PACKAGES**（`dnsmasq`），不强行选 `dnsmasq-full`。

**一次性 Kconfig 修复（`scripts/ci-fix-kconfig-tree.sh`）：**

1. 从 `feeds.conf*` 删除 kenzo/small，并 `rm -rf feeds/{kenzo,small}`
2. 按 `PKG_NAME:=nftables-json` 删除重复包（修复自引用环）
3. `patch-src-kconfig.sh` — dnsmasq 去掉 nftset→nftables-json；TurboACC 去掉 `kmod-nft-fullcone` 依赖行
4. TurboACC：**clone `luci-app-turboacc` + `nft-fullcone`**，删除 feeds 里重复的 `kmod-nft-fullcone`；`ci-enable-turboacc.sh` 在 base defconfig 后启用 `luci-app-turboacc` + `kmod-nft-fullcone` + `kmod-tcp-bbr`（含 BBR / nft-fullcone，不含 OFFLOADING）
5. `sanitize-config.sh` — `.config` 守卫项
6. Actions cache key：`feeds-*-kconfig-fix-v1-*`（旧 v8 缓存作废）
7. workflow：cache 恢复后、setup 前后、`defconfig` 前各跑一次 `ci-fix-kconfig-tree.sh`

`verify-defconfig`：日志里出现任意 `recursive dependency detected` 即失败（不再 WARN 放过）。

## LuCI 简体中文

| 包 | 说明 |
|----|------|
| `luci-i18n-base-zh-cn` / `firewall` | `common.config` |
| `luci-i18n-passwall-zh-cn` | PassWall 界面 |
| `luci-i18n-mosdns-zh-cn` | `custom-plugins.config` |
| `luci-i18n-ttyd-zh-cn` / `arpbind` / `opkg` | `snippets/luci-zh-cn.config` |

首次启动 `files/etc/uci-defaults/96-luci-zh-cn` 设置 `luci.main.lang=zh_cn`。TurboACC 无独立 i18n 包，菜单文案随 base 中文。

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

## 设备 WiFi / 核心包

- 全设备合并 `configs/snippets/wireless-core.config`（`iw`、`wireless-regdb`、`cfg80211`、`mac80211`）。
- **LEDE K2P**：`kmod-mt7615d` + `kmod-mt7615d_dbdc` + `maccalc` + `wireless-tools`（lean 闭源驱动）。
- **ImmortalWrt K2P**：`kmod-mt7615e` + `kmod-mt7615-firmware`（主线 mt76，**不要** `mt7615d_dbdc`）。
- **ImmortalWrt filogic**（WR30U / AX6000）：target 须为 `*-stock`；驱动包含 `kmod-mt7915e` + 对应 `*-firmware` / `*-wo-firmware`。
- **ImmortalWrt CR660x**：target 为 `cr6606`（非 `cr660x` 聚合名）。
- setup 预装 feeds：`maccalc`、`wireless-regdb`、`iw`、`kmod-mt7615-firmware`、`kmod-mt7915-firmware`。
- `scripts/ci-validate-device-packages.sh` 在 CI setup 阶段按平台校验上述规则。

## 常见 Makefile WARNING（多数可忽略）

| 包 | 用途 | 是否要管 |
|----|------|----------|
| `lldpd` → `libnetsnmp` | 二层邻居发现（LLDP），可选 SNMP 扩展 | **否**，与 WiFi 无关；未选 `lldpd` 时仅 metadata 扫描告警 |
| `mt7615d` → `maccalc` | 斐讯 K2P 等 **MT7615 DBDC** 闭源 WiFi 驱动的 MAC 计算工具 | **是**（仅 `phicomm-k2p` 等启用 `kmod-mt7615d_dbdc` 时） |

`maccalc` 在官方 `packages` feed 的 `net/maccalc`，setup 会 `feeds install maccalc`；设备 config 里 `CONFIG_PACKAGE_maccalc=y` 保证进固件。

## Actions Node 警告

在 GitHub **Settings → Actions → Variables** 删除 `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` 与 `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION`（非本仓库 workflow 定义）。
