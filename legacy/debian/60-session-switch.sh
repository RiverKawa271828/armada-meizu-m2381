#!/usr/bin/env bash
# 60-session-switch.sh —— 一键切换设备会话（掌机模式 / Plasma 桌面）
#
# 用法: bash scripts/host/60-session-switch.sh [desktop|handheld|status] [设备IP]
#   desktop  下次登录进 Plasma 桌面（一次性，注销/重启后回掌机模式）
#   handheld 回到掌机模式（黑屏自救也用它）
#   status   查看当前设定（默认）
set -euo pipefail
IP="${2:-172.16.42.1}"
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 "root@$IP" \
  /usr/local/bin/sm20-session "${1:-status}"
