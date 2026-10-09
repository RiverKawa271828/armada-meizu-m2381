#!/usr/bin/env bash
# 50-steam-client-restore.sh —— 把 Steam ARM 客户端整包备份恢复到设备（免 CDN 下载）
#
# 背景：国内直连 Steam CDN 仅 ~100KB/s，镜像内种子（bins/ui zip）缺 .installed
# 清单，首启必触发 bootstrap 全量 651MB 下载。本脚本用整包备份
# （steam-client-full.tar.zst，含 .installed）直接铺装，秒级可用。
#
# 用法: bash scripts/host/50-steam-client-restore.sh [设备IP] [备份文件]
#   设备IP 默认 172.16.42.1（USB NCM 通道；WiFi 则传 192.168.10.x）
#   备份   默认 work/cache/steam-arm/steam-client-full.tar.zst
# 设备侧要求: root 可 ssh（密码 123456 或公钥）；zstd 在位（trixie 自带）
# 动作: 停 Steam 进程 → 备份铺进种子位 /usr/lib/steam/arm-client →
#       镜像一份到 steamos 家目录（等价首启拷种子）→ 数据链软链 → 校验
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IP="${1:-172.16.42.1}"
BAK="${2:-$HERE/work/cache/steam-arm/steam-client-full.tar.zst}"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=8)
log()  { printf '[%s] %s\n' "${0##*/}" "$*"; }
die()  { printf '[%s] 错误: %s\n' "${0##*/}" "$*" >&2; exit 1; }

[[ -s "$BAK" ]] || die "备份不存在: $BAK"
ssh "${SSH_OPTS[@]}" "root@$IP" true 2>/dev/null \
  || die "ssh root@$IP 不通（USB 未插就传 WiFi IP；确认设备在线）"

log "停设备上 Steam 进程"
ssh "${SSH_OPTS[@]}" "root@$IP" \
  'pkill -u steamos -f steamrtarm64 2>/dev/null; pkill -u steamos -f steamwebhelper 2>/dev/null; true'

log "备份铺进种子位 /usr/lib/steam/arm-client（$(du -h "$BAK" | cut -f1)）"
ssh "${SSH_OPTS[@]}" "root@$IP" \
  'mkdir -p /usr/lib/steam/arm-client && tar -xf - -C /usr/lib/steam/arm-client --strip-components=1' \
  < "$BAK"

log "镜像到 steamos 家目录 + 数据链软链"
ssh "${SSH_OPTS[@]}" "root@$IP" 'set -e
SEED=/usr/lib/steam/arm-client
DEST=/home/steamos/.local/share/Steam
test -x "$SEED/steamrtarm64/steam" || { echo "种子缺 steamrtarm64/steam"; exit 1; }
test -s "$SEED/package/steam_client_steamdeck_stable_linuxarm64.installed" \
  || echo "警告: 无 .installed 清单（首启可能仍触发更新下载）"
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
cp -a "$SEED" "$DEST"
chown -R steamos:steamos "$DEST"
sudo -u steamos mkdir -p /home/steamos/.steam
sudo -u steamos ln -sfn "$DEST" /home/steamos/.steam/steam
sudo -u steamos ln -sfn "$DEST" /home/steamos/.steam/root
du -sh "$DEST"'

log "完成 —— 桌面点 Steam (ARM) 图标即启，零下载"
