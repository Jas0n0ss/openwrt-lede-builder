#!/bin/bash

DEVICE=$1

echo "正在优化设备: $DEVICE"

# 通用优化
echo "启用 SFE 加速"
sed -i 's/CONFIG_PACKAGE_kmod-ppp=y/CONFIG_PACKAGE_kmod-ppp=y\nCONFIG_PACKAGE_kmod-fast-classifier=y/g' .config

# 关闭 IPv6 (可选，减小体积)
# sed -i 's/CONFIG_IPV6=y/CONFIG_IPV6=n/g' .config

# 优化编译参数
echo 'CONFIG_TARGET_OPTIMIZATION="-O2 -pipe -march=native"' >> .config
echo 'CONFIG_STRIP_KERNEL_EXPORTS=y' >> .config
echo 'CONFIG_USE_PREBUILT_INTL_TOOLS=y' >> .config

# 减少日志输出
echo 'CONFIG_KERNEL_PRINTK=n' >> .config
echo 'CONFIG_KERNEL_DEBUG_KERNEL=n' >> .config

# 设备特定优化
case $DEVICE in
  r2s)
    echo "优化 R2S 配置"
    echo 'CONFIG_KERNEL_PERF_EVENTS=n' >> .config
    echo 'CONFIG_KERNEL_PROFILING=n' >> .config
    ;;
  cr660x)
    echo "优化 CR660x 配置"
    echo 'CONFIG_PACKAGE_kmod-mt7615e=y' >> .config
    echo 'CONFIG_PACKAGE_luci-app-wireguard=y' >> .config
    ;;
  x86)
    echo "优化 X86 配置"
    echo 'CONFIG_CPU_TYPE="generic"' >> .config
    echo 'CONFIG_PACKAGE_kmod-drm-i915=y' >> .config
    echo 'CONFIG_PACKAGE_kmod-drm-amdgpu=y' >> .config
    ;;
esac

# 移除不必要的包以减小体积
echo "移除冗余组件"
cat >> .config << 'REMOVE'
CONFIG_PACKAGE_kmod-pppoe=n
CONFIG_PACKAGE_kmod-pppol2tp=n
CONFIG_PACKAGE_nlbwmon=n
CONFIG_PACKAGE_odhcpd=n
CONFIG_PACKAGE_odhcp6c=n
REMOVE

echo "优化完成"
