# CI 说明

## xray-core / Go 版本

PassWall 上游 `xray-core` 26.x 需要 Go ≥1.26，而 LEDE/OpenWrt 的 `golang/host` 一般为 1.21.x。构建前由 [`scripts/patch-feeds.sh`](../scripts/patch-feeds.sh) 将 `xray-core` 固定为 **24.12.31**（`go 1.21.4`）。

## Kconfig 循环依赖

勿对 `kenzo` / `small` 执行 `feeds install -p` 全量安装；会与官方 `luci-ssl` 等产生 `recursive dependency`。仅安装 PassWall feeds + 按需 `feeds install <pkg>`。

## Actions Node 警告

若日志出现 `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` 与 `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION` 同时启用，请在 GitHub **Settings → Secrets and variables → Actions → Variables** 中删除这两项（本仓库 workflow 未使用）。
