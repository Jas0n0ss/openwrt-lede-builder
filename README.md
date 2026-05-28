# OpenWrt / LEDE 固件自动构建

[![Build LEDE](https://img.shields.io/github/actions/workflow/status/Jas0n0ss/openwrt-lede-builder/build-lede.yml?branch=main)](https://github.com/Jas0n0ss/openwrt-lede-builder/actions/workflows/build-lede.yml)
[![GitHub release](https://img.shields.io/github/v/release/Jas0n0ss/openwrt-lede-builder)](https://github.com/Jas0n0ss/openwrt-lede-builder/releases)
[![License](https://img.shields.io/github/license/Jas0n0ss/openwrt-lede-builder)](https://github.com/Jas0n0ss/openwrt-lede-builder/blob/main/LICENSE)

基于 [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) 与 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) 源码，通过 GitHub Actions 自动编译带常用插件的 OpenWrt/LEDE 固件。

---

## 支持的设备

设备代号统一为 **小写 + 连字符**（见 [`configs/devices.list`](configs/devices.list)），与 `configs/lede/<代号>.config` 一一对应。

| 设备 | 标准代号 | OpenWrt 平台 / 机型 | 核心无线 / 驱动 |
|------|----------|---------------------|-----------------|
| 小米 AX3600 | `xiaomi-ax3600` | qualcommax / ipq807x | `ipq-wifi-xiaomi_ax3600`, ath10k/ath11k |
| 小米 AX9000 | `xiaomi-ax9000` | qualcommax / ipq807x | `ipq-wifi-xiaomi_ax9000`, ath11k QCN9074 |
| 小米 WR30U | `xiaomi-wr30u` | mediatek filogic / mt7981 | `kmod-mt7981-firmware`, `mt7981-wo-firmware` |
| 小米 AX6000 | `xiaomi-ax6000` | mediatek filogic / Redmi AX6000 | 同 `redmi-ax6000`（mt7986） |
| 红米 AX6000 | `redmi-ax6000` | mediatek filogic / mt7986 | `kmod-mt7986-firmware`, `mt7986-wo-firmware` |
| 斐讯 K2P | `phicomm-k2p` | ramips / mt7621 | `kmod-mt7615d_dbdc` |
| 小米路由 3G | `xiaomi-3g` | ramips / mt7621 | `kmod-mt7603`, `kmod-mt76x2` |
| 小米 CR660x | `xiaomi-cr660x` | ramips / mt7621 | `kmod-mt7915-firmware` |
| NanoPi R2S | `r2s` | rockchip / armv8 | `kmod-r8168`, USB 网卡 |
| x86_64 软路由 | `x86_64` | x86_64 / generic | igb / r8169 / virtio |
| 树莓派 4B | `raspberrypi-4b` | bcm27xx / bcm2711 | `kmod-brcmfmac` |

编译时可选择 **单个代号** 或 **`all`**（按 `devices.list` 全部并行）。

> 已移除旧代号 `ax6000`、`cr660x`，请改用 `redmi-ax6000`、`xiaomi-cr660x`。

### 固件文件命名

Release / Artifacts **仅包含最终可刷写的固件**（不含 `sha256sums`、manifest、内核碎片等）。

命名规则（由 `scripts/pack-firmware.sh` 根据设备 `.config` 自动生成）：

```text
Jas0n0ss-<源码>-<代号>-<OpenWrt设备名>-<平台>-<类型>.<后缀>
```

`<源码>` 为 `lede` 或 `immortalwrt`，对应该次构建使用的配置与源码树。

示例：

| 源码 | 代号 | 示例文件名 |
|------|------|------------|
| `lede` | `redmi-ax6000` | `Jas0n0ss-lede-redmi-ax6000-xiaomi-redmi-router-ax6000-mediatek-filogic-sysupgrade.bin` |
| `lede` | `xiaomi-cr660x` | `Jas0n0ss-lede-xiaomi-cr660x-xiaomi-mi-router-cr660x-ramips-mt7621-sysupgrade.bin` |
| `lede` | `xiaomi-ax3600` | `Jas0n0ss-lede-xiaomi-ax3600-xiaomi-ax3600-qualcommax-ipq807x-sysupgrade.bin` |
| `lede` | `r2s` | `Jas0n0ss-lede-r2s-nanopi-r2s-rockchip-armv8-sysupgrade.img.gz` |
| `lede` | `x86_64` | `Jas0n0ss-lede-x86_64-generic-x86-64-combined.img.gz` |

刷机后 LuCI 页脚与系统信息仅展示 **@Jas0n0ss** 与 [固件源码仓库](https://github.com/Jas0n0ss/openwrt-lede-builder)。

---

## 预装插件与依赖

所有插件的 feed 源、源码克隆与 `.config` 选项由 [`scripts/setup-custom-packages.sh`](scripts/setup-custom-packages.sh) 与 [`configs/custom-plugins.config`](configs/custom-plugins.config) 统一管理。

| 插件 | 说明 | 主要 OpenWrt 包 |
|------|------|-----------------|
| **PassWall** | 科学上网（含 Hysteria） | `luci-app-passwall`, `xray-core`, `sing-box`, `hysteria` |
| **MosDNS** | DNS 转发 / 分流 | `luci-app-mosdns`, `mosdns`, `v2dat`, `v2ray-geoip`, `v2ray-geosite` |
| **TurboACC** | 软、硬件加速 | `luci-app-turboacc`, `kmod-nft-offload`, `kmod-nft-fullcone`, `kmod-tcp-bbr` |
| **TTYD** | 网页终端 | `ttyd`, `luci-app-ttyd`（来自官方 packages / luci feeds） |
| **ARP 绑定** | 静态 IP/MAC 绑定 | `luci-app-arpbind` |
| **Aurora 主题** | 现代化 LuCI 主题 | `luci-theme-aurora` |

首次刷机后 LuCI 默认主题为 Aurora（见 `files/etc/uci-defaults/99-custom`）。

---

## 默认系统设置

| 项目 | 值 |
|------|-----|
| 管理地址 | http://10.10.10.1 |
| 用户名 | `root` |
| 密码 | `password` |
| DHCP 范围 | 10.10.10.100 – 10.10.10.250 |
| 时区 | Asia/Shanghai |
| 主题 | Aurora |

---

## GitHub Actions 工作流

| 工作流 | 用途 |
|--------|------|
| **Build LEDE Firmware** | LEDE 源码 + `configs/lede/` |
| **Build LEDE Firmware from GPT** | LEDE 源码 + `configs/immortalwrt/` |
| **Build OpenWrt (LEDE + ImmortalWrt)** | 可选 LEDE 或 ImmortalWrt 官方源码 |
| **Check OpenWrt Upstream** | 检测上游更新并自动触发构建 |

### 手动编译

1. Fork 本仓库到你的 GitHub 账号。
2. **Settings → Actions → General**：允许所有 Actions；**Workflow permissions** 设为 **Read and write**。
3. 打开 **Actions**，选择上述工作流之一，点击 **Run workflow**。
4. 选择 **device**（`all` 或 `configs/devices.list` 中的任一标准代号）。
5. 构建约 1–2 小时；在任务 **Artifacts** 或 **Releases**（仅手动触发）中下载固件。

### 目录结构

```
configs/
  devices.list       # 标准设备代号列表（CI matrix）
  lede/              # 每设备 target + 无线驱动（精简）
  immortalwrt/       # 与 lede 设备配置同步
  custom-plugins.config  # PassWall / MosDNS / TurboACC 等插件
scripts/
  device-matrix.sh   # 生成 GitHub Actions matrix
  pack-firmware.sh   # 仅打包并重命名最终固件
  setup-custom-packages.sh  # feeds + 插件源码
files/               # 刷机后 overlay（IP、主题、banner 等）
```

---

## 本地编译（简要）

```bash
git clone https://github.com/coolsnowwolf/lede.git
cd lede

# 使用本仓库脚本安装 feeds 与自定义插件
bash /path/to/openwrt-builder/scripts/setup-custom-packages.sh "$(pwd)" lede

# 合并配置
cat /path/to/openwrt-builder/configs/lede/common.config > .config
cat /path/to/openwrt-builder/configs/lede/redmi-ax6000.config >> .config   # 按需替换代号
cat /path/to/openwrt-builder/configs/custom-plugins.config >> .config
make defconfig

make download -j8
make -j$(nproc) V=s
```

---

## 许可证

见 [LICENSE](LICENSE)。
