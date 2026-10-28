#!/bin/bash
# fastboot 刷写守门（2026-10-12 互踩事故律②）：fastboot 单通道独占设备，
# 双线并行下发会互相污染分区且无任何报错。任何刷写必须先过本守门。
#
# 用法:
#   post_process/flash-meizu.sh [--set-active] [--reboot] 分区=镜像 [分区=镜像 ...]
# 例:
#   post_process/flash-meizu.sh \
#     userdata=work/meizu-meizu20-armada-r84.img \
#     recovery_a=work/cache/esp-recovery-v65.img --set-active --reboot
set -euo pipefail
LOCK=/tmp/sm20-fastboot.lock
LOG=/tmp/zcode/flash-meizu.log

SET_ACTIVE=0; REBOOT=0; PARTS=()
for a in "$@"; do
    case "$a" in
        --set-active) SET_ACTIVE=1 ;;
        --reboot)     REBOOT=1 ;;
        *=*)          PARTS+=("$a") ;;
        *)            echo "FATAL: 无法解析参数 $a" >&2; exit 64 ;;
    esac
done
[ ${#PARTS[@]} -gt 0 ] || { echo "usage: $0 [--set-active] [--reboot] part=img [part=img ...]" >&2; exit 64; }
mkdir -p /tmp/zcode

exec 9>"$LOCK"
if ! flock -n 9; then
    echo "FATAL: 本机已有刷写持锁（$LOCK）——串行，禁止并行（2026-10-12 互踩事故律）" >&2
    exit 65
fi

# 他线/残留 fastboot 进程 = 单通道可能被占（互踩事故的直接死法）
if pgrep -x fastboot >/dev/null 2>&1; then
    echo "FATAL: 检测到 fastboot 进程已在跑，先等它结束或与另一线协调窗口：" >&2
    pgrep -a -x fastboot >&2
    exit 66
fi

if ! fastboot devices 2>/dev/null | grep -q .; then
    echo "FATAL: 无 fastboot 设备（进 fastboot：关机后 音量下+电源）" >&2
    exit 67
fi

echo "== 刷写开始 $(date -Is) =="
for spec in "${PARTS[@]}"; do
    part="${spec%%=*}"; img="${spec#*=}"
    [ -f "$img" ] || { echo "FATAL: 镜像不存在 $img" >&2; exit 68; }
    echo "-- $part ← $img"
    fastboot flash "$part" "$img" 2>&1 | tee -a "$LOG" | tail -3
done
if [ "$SET_ACTIVE" = 1 ]; then
    echo "-- set_active b"
    fastboot set_active b 2>&1 | tee -a "$LOG" | tail -1
fi
if [ "$REBOOT" = 1 ]; then
    echo "-- reboot"
    fastboot reboot 2>&1 | tee -a "$LOG" | tail -1
else
    echo "== 完成 $(date -Is)（未 reboot；确认无误后手动 fastboot reboot）=="
fi
