# LEDE 固件自动构建

[![GitHub Actions](https://img.shields.io/github/actions/workflow/status/Jas0n0ss/openwrt-lede-builder/build-lede.yml?branch=main)](https://github.com/Jas0n0ss/openwrt-lede-builder/actions)
[![GitHub release](https://img.shields.io/github/v/release/Jas0n0ss/openwrt-lede-builder)](https://github.com/Jas0n0ss/openwrt-lede-builder/releases)
[![GitHub license](https://img.shields.io/github/license/Jas0n0ss/openwrt-lede-builder)](https://github.com/Jas0n0ss/openwrt-lede-builder/blob/main/LICENSE)

基于 [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) 源码，使用 GitHub Actions 自动编译 OpenWrt/LEDE 固件。

---

## 📱 支持的设备

| 设备 | 代号 | 架构 | 固件格式 |
|------|------|------|----------|
| **FriendlyARM NanoPi R2S** | `r2s` | Rockchip ARMv8 | `.img.gz` |
| **小米 CR660x** (CR6606/6608/6609) | `cr660x` | MediaTek MT7621 | `.bin` |
| **红米 Redmi AX6000** | `ax6000` | MediaTek MT7986 | `.bin` |
| **x86_64 软路由** | `x86_64` | x86_64 | `.img.gz` / `.vmdk` / `.qcow2` |
| **树莓派 4B** | `raspberrypi-4b` | BCM2711 | `.sdcard.img` |

> 支持选择编译单个设备或一次性编译所有设备

---

## 📦 包含插件

| 插件 | 说明 |
|------|------|
| **PassWall** | 科学上网代理平台（含 Hysteria 支持） |
| **MosDNS** | DNS 转发/分流器 |
| **TurboACC** | 网络加速引擎 |
| **TTYD** | 网页终端 |
| **ARP 绑定** | IP/MAC 绑定 |
| **Aurora 主题** | 现代化 LuCI 主题 |

---

## 🌐 默认设置

| 项目 | 值 |
|------|-----|
| **管理地址** | http://10.10.10.1 |
| **用户名** | `root` |
| **密码** | `password` |
| **DHCP 范围** | 10.10.10.100 - 10.10.10.250 |
| **时区** | Asia/Shanghai |
| **主题** | Aurora |

---

## 🚀 使用方法

### 方式一：GitHub Actions 自动编译（推荐）

1. **Fork 本项目** 到你的 GitHub 账号

2. **启用 Actions**
   - 进入 `Settings` → `Actions` → `General`
   - 选择 `Allow all actions`
   - 设置 `Workflow permissions` 为 `Read and write permissions`

3. **触发编译**
   - 进入 `Actions` 页面
   - 选择 `Build LEDE Firmware`
   - 点击 `Run workflow`
   - 选择设备（`all` 或单个设备）
   - 点击运行

4. **下载固件**
   - 编译完成后（约 1-2 小时）
   - 在 `Actions` 页面点击对应任务
   - 下载 `Artifacts` 中的固件包
   - 或从 `Releases` 页面下载

### 方式二：本地编译

```bash
# 克隆源码
git clone https://github.com/coolsnowwolf/lede.git
cd lede

# 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 配置固件
make menuconfig

# 下载源码
make download -j8

# 开始编译
make -j$(nproc) V=s