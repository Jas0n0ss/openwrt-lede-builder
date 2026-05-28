# OpenWrt / LEDE 固件自动构建

[![Build LEDE](https://img.shields.io/github/actions/workflow/status/Jas0n0ss/openwrt-lede-builder/build-lede.yml?branch=main)](https://github.com/Jas0n0ss/openwrt-lede-builder/actions/workflows/build-lede.yml)
[![GitHub release](https://img.shields.io/github/v/release/Jas0n0ss/openwrt-lede-builder)](https://github.com/Jas0n0ss/openwrt-lede-builder/releases)
[![License](https://img.shields.io/github/license/Jas0n0ss/openwrt-lede-builder)](https://github.com/Jas0n0ss/openwrt-lede-builder/blob/main/LICENSE)

基于 [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) 与 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) 源码，通过 GitHub Actions 自动编译带常用插件的 OpenWrt/LEDE 固件。

---

## 支持的设备

| 设备 | 代号 | 架构 | 固件格式 |
|------|------|------|----------|
| FriendlyARM NanoPi R2S | `r2s` | Rockchip ARMv8 | `.img.gz` |
| 小米 CR660x (CR6606/6608/6609) | `cr660x` | MediaTek MT7621 | `.bin` |
| 红米 Redmi AX6000 | `ax6000` | MediaTek MT7986 | `.bin` |
| x86_64 软路由 | `x86_64` | x86_64 | `.img.gz` / `.vmdk` / `.qcow2` |
| 树莓派 4B | `raspberrypi-4b` | BCM2711 | `.img.gz` / `.img` |

编译时可选择 **单个设备** 或 **`all`**（全部设备并行构建）。

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
4. 选择 **device**（`all` 或 `r2s` / `cr660x` / `ax6000` / `x86_64` / `raspberrypi-4b`）。
5. 构建约 1–2 小时；在任务 **Artifacts** 或 **Releases**（仅手动触发）中下载固件。

### 目录结构

```
configs/
  lede/              # LEDE 通用 + 各设备配置
  immortalwrt/       # ImmortalWrt 风格设备配置
  custom-plugins.config  # 插件与依赖（所有工作流合并使用）
scripts/
  setup-custom-packages.sh  # feeds + 插件源码安装
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
cat /path/to/openwrt-builder/configs/lede/r2s.config >> .config   # 按需替换设备
cat /path/to/openwrt-builder/configs/custom-plugins.config >> .config
make defconfig

make download -j8
make -j$(nproc) V=s
```

---

## 许可证

见 [LICENSE](LICENSE)。
