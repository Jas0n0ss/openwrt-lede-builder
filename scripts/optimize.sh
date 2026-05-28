#!/bin/bash

DEVICE=$1

echo "正在优化设备: $DEVICE"

echo 'CONFIG_KERNEL_PRINTK=n' >> .config
echo 'CONFIG_KERNEL_DEBUG_KERNEL=n' >> .config

case $DEVICE in
  r2s)
    echo "优化 NanoPi R2S"
    ;;
  xiaomi-cr660x|cr660x)
    echo "优化 Xiaomi CR660x"
    ;;
  redmi-ax6000|xiaomi-ax6000|ax6000)
    echo "优化 Redmi / Xiaomi AX6000 (mt7986)"
    ;;
  xiaomi-wr30u)
    echo "优化 Xiaomi WR30U (mt7981)"
    ;;
  xiaomi-ax3600)
    echo "优化 Xiaomi AX3600 (ipq807x)"
    ;;
  xiaomi-ax9000)
    echo "优化 Xiaomi AX9000 (ipq807x)"
    ;;
  phicomm-k2p)
    echo "优化 Phicomm K2P"
    ;;
  xiaomi-3g)
    echo "优化 Xiaomi Mi Router 3G"
    ;;
  x86_64|x86)
    echo "优化 x86_64"
    ;;
  raspberrypi-4b)
    echo "优化 Raspberry Pi 4B"
    ;;
esac

echo "优化完成"
