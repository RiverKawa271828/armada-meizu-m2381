#!/bin/bash
# 刷后首启健康采样（卡Mu事故 §6 协议第 2 步，2026-10-12）
# 用法：post_process/post-flash-health.sh [IP，默认 172.16.42.1]
# 只读采样：槽位态 / /lib 形态 / 模块探活 / ext4 健康 / failed 单元 / uname。
# 判读：任何 FAIL = 当场停手取证（docs/M2381-CARDMU-AUDIT-20261012.md §5/§6），
# 现场是唯一物证，禁止直接重刷覆盖。
set -u
IP="${1:-172.16.42.1}"
SSH="ssh -o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$IP"
say(){ echo "[postflash] $*"; }
FAIL=0

say "== 连通 =="
$SSH true 2>/dev/null || { say "FAIL SSH 不通（NCM 90s 内未枚举？）"; exit 1; }
say "PASS SSH 可达"

$SSH 'uname -r' | { read -r U; say "uname = $U"; }

say "== 槽位态（qbootctl -h，机制 B 主证据）=="
$SSH 'qbootctl -h 2>&1 || /usr/local/bin/qbootctl -h 2>&1' | sed 's/^/  /' || say "FAIL qbootctl 不可用"

say "== /lib 形态（usr-merge 守门；真目录 = 手修/tar 类污染）=="
$SSH 'ls -ld /lib' | sed 's/^/  /'
$SSH '[ -L /lib ]' && say "PASS /lib 软链" || { say "FAIL /lib 是真目录"; FAIL=1; }

say "== 模块探活（/lib/modules 与关键 ko）=="
$SSH 'ls /lib/modules/ 2>&1; find /lib/modules/$(uname -r) -name "ath12k.ko*" 2>/dev/null | head -1' | sed 's/^/  /'
$SSH 'modprobe -n ath12k 2>&1 && echo MODPROBE-OK' | sed 's/^/  /' | grep -q MODPROBE-OK && say "PASS modprobe ath12k" || { say "FAIL modprobe ath12k"; FAIL=1; }

say "== ext4 健康（机制 A 主证据）=="
$SSH 'dmesg | grep -iE "EXT4-fs error|EXT4-fs warning| journalsync|I/O error" | head -10' | sed 's/^/  /'
$SSH 'dmesg | grep -ciE "EXT4-fs error"' | { read -r N; [ "$N" = "0" ] && say "PASS 无 EXT4-fs error" || { say "FAIL EXT4-fs error ×$N"; FAIL=1; }; }
$SSH 'tune2fs -l $(findmnt -n -o SOURCE /) 2>/dev/null | grep -E "Mount count|Maximum mount|Last checked|Filesystem state"' | sed 's/^/  /'

say "== 会话态 =="
$SSH 'systemctl --failed --no-legend | head -10; systemctl --failed --no-legend | wc -l' | sed 's/^/  /'
$SSH 'systemctl is-active gamescope-session 2>/dev/null; loginctl list-sessions --no-legend 2>/dev/null | head -3' | sed 's/^/  /'

say "== Vulkan 栈（v4 写伤实证口：JSON 可读性 = 数据块健康代理）=="
$SSH 'timeout 25 su armada -c "vulkaninfo --summary 2>&1" | grep -c "Invalid JSON"' | { read -r N; [ "$N" = "0" ] && say "PASS Vulkan JSON 全可读" || { say "FAIL Invalid JSON ×$N（数据块撕裂，见审计档 §5-A）"; FAIL=1; }; }
$SSH 'timeout 25 su armada -c "vulkaninfo --summary 2>&1" | grep -m1 deviceName' | sed 's/^/  /'
say "== 会话归属（gamescope=PASS / plasma=会话回退）=="
$SSH 'ps -eo comm= | grep -q "^gamescope$" && echo gamescope || (ps -eo comm= | grep -q plasmashell && echo plasma || echo none)' | { read -r S; [ "$S" = "gamescope" ] && say "PASS gamescope 会话" || say "WARN 会话=$S（gamescope 未接管）"; }

say "== 供电（机制 C 辅证）=="
$SSH 'cat /sys/class/power_supply/battery/status /sys/class/power_supply/battery/capacity 2>/dev/null' | sed 's/^/  /'

[ "$FAIL" = "0" ] && say "=== ALL-PASS（可进三次重启回归）===" || say "=== 有 FAIL：停手取证，勿重刷 ==="
exit "$FAIL"
