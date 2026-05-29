# OpenWrt / LEDE 固件构建

[![Build OpenWrt](https://img.shields.io/github/actions/workflow/status/Jas0n0ss/openwrt-lede-builder/build.yml?branch=main)](https://github.com/Jas0n0ss/openwrt-lede-builder/actions/workflows/build.yml)
[![GitHub release](https://img.shields.io/github/v/release/Jas0n0ss/openwrt-lede-builder)](https://github.com/Jas0n0ss/openwrt-lede-builder/releases)
[![License](https://img.shields.io/github/license/Jas0n0ss/openwrt-lede-builder)](https://github.com/Jas0n0ss/openwrt-lede-builder/blob/main/LICENSE)

基于 [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) 与 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt)，通过 GitHub Actions 编译预配置固件。插件与 overlay 由本仓库统一管理。

## 设备

代号定义见 [`configs/devices.list`](configs/devices.list)，与 `configs/{lede,immortalwrt}/<代号>.config` 对应。Workflow 可选单设备或 `all`。

| 设备 | 代号 | 平台 |
|------|------|------|
| 小米 AX3600 | `xiaomi-ax3600` | qualcommax / ipq807x |
| 小米 AX9000 | `xiaomi-ax9000` | qualcommax / ipq807x |
| 小米 WR30U | `xiaomi-wr30u` | mediatek / filogic mt7981（ImmortalWrt 用 `*-stock` target） |
| 小米 AX6000 | `xiaomi-ax6000` | mediatek / filogic mt7986（ImmortalWrt 用 `*-stock` target） |
| 红米 AX6000 | `redmi-ax6000` | mediatek / filogic mt7986（ImmortalWrt 用 `*-stock` target） |
| 斐讯 K2P | `phicomm-k2p` | ramips / mt7621（LEDE=lean MT7615 DBDC；ImmortalWrt=mt76） |
| 小米路由 3G | `xiaomi-3g` | ramips / mt7621 |
| 小米 CR660x | `xiaomi-cr660x` | ramips / mt7621（ImmortalWrt 默认 **CR6606** 机型） |
| NanoPi R2S | `r2s` | rockchip / armv8 |
| x86_64 | `x86_64` | x86_64 / generic |
| 树莓派 4B | `raspberrypi-4b` | bcm27xx / bcm2711 |

## 产物

Release / Artifacts 仅包含可刷写镜像，由 [`scripts/pack-firmware.sh`](scripts/pack-firmware.sh) 从 `bin/targets` 筛选并重命名：

```text
Jas0n0ss-<lede|immortalwrt>-<代号>-<设备名>-<平台>-<类型>.<后缀>
```

示例：`Jas0n0ss-lede-r2s-nanopi-r2s-rockchip-armv8-sysupgrade.img.gz`

编译缓存见 [docs/build-speed.md](docs/build-speed.md)；CI 排错见 [docs/ci-notes.md](docs/ci-notes.md)。

## 预装内容

| 类别 | 内容 |
|------|------|
| 插件 | PassWall、MosDNS、TurboACC（BBR + nft-fullcone）、TTYD、ARP 绑定、Aurora 主题 |
| 语言 | LuCI 默认 **简体中文**（`luci-i18n-*-zh-cn` + 首次启动 `lang=zh_cn`） |
| 配置 | [`configs/custom-plugins.config`](configs/custom-plugins.config) + [`scripts/setup-custom-packages.sh`](scripts/setup-custom-packages.sh) |
| Overlay | LAN `10.10.10.1`、Aurora 主题、Dropbear banner、root `bash` + oh-my-bash |

SSH banner 按源码区分：LEDE 为六边形样式，ImmortalWrt 为 `BE FREE AND UNAFRAID`（模板：`scripts/banners/`）。LuCI 与 `/etc/openwrt_release` 标注 @Jas0n0ss。

## 默认凭据

| 项 | 值 |
|----|-----|
| 地址 | http://10.10.10.1 |
| 用户 | `root` |
| 密码 | `password` |
| DHCP | 10.10.10.100 – 10.10.10.250 |
| 时区 | Asia/Shanghai |

## CI

| Workflow | 说明 |
|----------|------|
| **Build OpenWrt Firmware** (`build.yml`) | 唯一编译入口；`source` 选 `lede` 或 `immortalwrt`，`device` 选代号或 `all` |
| **Check OpenWrt Upstream** | 上游更新时自动触发 `build.yml` |

**手动编译：** Actions → **Build OpenWrt Firmware** → Run workflow → 选择源码与设备。需 Workflow permissions 为 Read and write。产物在 Artifacts；手动运行会写入 Releases。定时任务默认仅 **ImmortalWrt + all**。

## 目录

```
configs/
  devices.list              # 设备代号
  lede/  immortalwrt/       # 每设备 target 配置
  custom-plugins.config     # 插件 Kconfig
scripts/
  setup-custom-packages.sh  # feeds 与第三方包
  patch-feeds.sh            # 固定 xray/sing-box Go 版本
  verify-setup.sh           # feeds 步骤后校验
  pack-firmware.sh          # 产物打包命名
  generate-banner.sh        # 按源码生成 banner
  install-files-overlay.sh  # 安装至 <src>/files/
  bundle-oh-my-bash.sh      # CI 打包 oh-my-bash
files/                      # 固件 overlay（由 CI 注入源码树）
```

## 本地编译

```bash
git clone https://github.com/coolsnowwolf/lede.git && cd lede
REPO=/path/to/openwrt-lede-builder
DEVICE=redmi-ax6000

bash "$REPO/scripts/setup-custom-packages.sh" "$(pwd)" append "$REPO/configs"
bash "$REPO/scripts/generate-banner.sh" lede "$REPO/files"
bash "$REPO/scripts/bundle-oh-my-bash.sh" "$REPO/files"
bash "$REPO/scripts/install-files-overlay.sh" "$(pwd)" "$REPO/files"

cat "$REPO/configs/lede/common.config" > .config
cat "$REPO/configs/lede/${DEVICE}.config" >> .config
cat "$REPO/configs/custom-plugins.config" >> .config
make defconfig && make download -j8 && make -j"$(nproc)" V=s
```

ImmortalWrt 将 `lede` 换为源码目录，banner 参数改为 `immortalwrt`，配置目录改为 `configs/immortalwrt/`。

## License

[LICENSE](LICENSE)
