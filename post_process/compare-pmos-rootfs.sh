#!/bin/bash
# nura phosh rootfs ↔ 我方 armada 盘 静态对拍（卡Mu事故检查单①，2026-10-12）
# 用法（宿主 systemd-run）：post_process/compare-pmos-rootfs.sh <nura-phosh-rootfs.img>
# 只读 loop 挂载两盘，三轴输出：mkfs 头部 / 启动关键路径 / 「nura 有我方无」清单。
# 背景：我方镜像侧已被 docs/M2381-CARDMU-AUDIT-20261012.md 判无罪，本脚本定位 =
# 补档确认 + 收编彼侧基线；预期无实质差。
set -u
[ $# -eq 1 ] || { echo "用法: $0 <nura-phosh-rootfs.img>" >&2; exit 2; }
NURA_IMG=$(readlink -f "$1")
[ -f "$NURA_IMG" ] || { echo "ERROR: 找不到 $NURA_IMG" >&2; exit 1; }
REPO=$(cd "$(dirname "$0")/.." && pwd)
OURS_IMG="$REPO/work/meizu-meizu20-armada-r84.img"
OUT="/tmp/zcode/compare-pmos-$(date +%H%M%S).log"
exec > >(tee "$OUT") 2>&1

cleanup() { [ -n "${L1:-}" ] && sudo losetup -d "$L1" 2>/dev/null; [ -n "${L2:-}" ] && sudo losetup -d "$L2" 2>/dev/null; }
trap cleanup EXIT

say(){ echo "[cmp] $*"; }

# ---- 挂载（裸 ext4 直挂 loop 本体；带分区表则退 p1/p22）----
mount_img() { # $1=img $2=mntvar $3=loopvar
  local lp m
  lp=$(sudo losetup -fP --show -r "$1") || return 1
  sleep 1
  m=$(sudo mktemp -d /mnt/cmppmos.XXXX)
  if ! sudo mount -o ro "$lp" "$m" 2>/dev/null; then
    for p in p1 p22; do
      sudo mount -o ro "${lp}${p}" "$m" 2>/dev/null && break
    done
  fi
  if ! mountpoint -q "$m"; then sudo losetup -d "$lp"; sudo rmdir "$m"; return 1; fi
  eval "$2=$m"; eval "$3=$lp"
}
mount_img "$NURA_IMG" M_N L_N  || { say "nura 盘挂载失败"; exit 1; }
mount_img "$OURS_IMG" M_O L_O  || { say "我方盘挂载失败"; exit 1; }
say "nura = $NURA_IMG @ $M_N"
say "我方 = $OURS_IMG @ $M_O"

say "==== 轴1: dumpe2fs -h 头部对拍（mkfs 特性集/块/inode/创建时间）===="
D1=$(sudo dumpe2fs -h "$L_N" 2>/dev/null | grep -E "Filesystem features|Block size|Inode size|Inode count|Block count|Filesystem created|revision")
D2=$(sudo dumpe2fs -h "$L_O" 2>/dev/null | grep -E "Filesystem features|Block size|Inode size|Inode count|Block count|Filesystem created|revision")
diff <(echo "$D1") <(echo "$D2") && say "PASS 头部无差（revision/特性集/几何）" || say "↑ 头部差异如上（逐项判：特性集差 = 内核兼容风险点）"

say "==== 轴2: 启动关键路径 ===="
for p in etc/fstab etc/selinux/config usr/bin/kmod etc/systemd/system/qbootctl-meizu.service; do
  a=$([ -e "$M_N/$p" ] && echo 有 || echo 无); b=$([ -e "$M_O/$p" ] && echo 有 || echo 无)
  [ "$a" = "$b" ] || say "DIFF $p: nura=$a 我方=$b"
done
say "fstab 我方:"; sudo cat "$M_O/etc/fstab" 2>/dev/null | sed 's/^/  O: /'
say "fstab nura:"; sudo cat "$M_N/etc/fstab" 2>/dev/null | sed 's/^/  N: /'
K_N=$(sudo ls "$M_N/usr/lib/modules" 2>/dev/null | head -1)
K_O=$(sudo ls "$M_O/usr/lib/modules" 2>/dev/null | head -1)
say "modules 树版本: nura=$K_N 我方=$K_O"
if [ -n "$K_N" ] && [ -n "$K_O" ]; then
  say "vermagic 对拍（双方 modules.dep 首行）:"
  sudo head -2 "$M_N/usr/lib/modules/$K_N/modules.dep" 2>/dev/null | sed 's/^/  N: /'
  sudo head -2 "$M_O/usr/lib/modules/$K_O/modules.dep" 2>/dev/null | sed 's/^/  O: /'
  say "modules.builtin/dep/softdep 有无:"
  for f in modules.builtin modules.dep modules.softdep; do
    a=$([ -e "$M_N/usr/lib/modules/$K_N/$f" ] && echo 有 || echo 缺); b=$([ -e "$M_O/usr/lib/modules/$K_O/$f" ] && echo 有 || echo 缺)
    say "  $f: nura=$a 我方=$b"
  done
fi
say "qbootctl 链 nura:"; sudo ls -l "$M_N/usr/local/bin/qbootctl" "$M_N/etc/systemd/system/multi-user.target.wants/qbootctl-meizu.service" 2>&1 | sed 's/^/  N: /'
say "qbootctl 链 我方:"; sudo ls -l "$M_O/usr/local/bin/qbootctl" "$M_O/etc/systemd/system/multi-user.target.wants/qbootctl-meizu.service" 2>&1 | sed 's/^/  O: /'

say "==== 轴3: 「nura 有我方无」清单（启动相关目录）===="
for d in etc/systemd/system etc/modprobe.d etc/udev/rules.d etc/init.d usr/local/bin; do
  say "--- $d"
  sudo find "$M_N/$d" -mindepth 1 2>/dev/null | sed "s|^$M_N/||" | sort > /tmp/zcode/.cmp_n
  sudo find "$M_O/$d" -mindepth 1 2>/dev/null | sed "s|^$M_O/||" | sort > /tmp/zcode/.cmp_o
  comm -23 /tmp/zcode/.cmp_n /tmp/zcode/.cmp_o | head -40 | sed 's/^/  N-only: /'
  comm -13 /tmp/zcode/.cmp_n /tmp/zcode/.cmp_o | head -20 | sed 's/^/  O-only: /'
done
say "---- modules 树差（同名 .ko 比对 nura-only 顶层 30 条）"
sudo find "$M_N/usr/lib/modules/$K_N" -name "*.ko*" 2>/dev/null | sed "s|^$M_N/usr/lib/modules/$K_N/||" | sort > /tmp/zcode/.cmp_nk
sudo find "$M_O/usr/lib/modules/$K_O" -name "*.ko*" 2>/dev/null | sed "s|^$M_O/usr/lib/modules/$K_O/||" | sort > /tmp/zcode/.cmp_ok
comm -23 /tmp/zcode/.cmp_nk /tmp/zcode/.cmp_ok | head -30 | sed 's/^/  N-only: /'
say "modules .ko 计数: nura=$(wc -l < /tmp/zcode/.cmp_nk) 我方=$(wc -l < /tmp/zcode/.cmp_ok)"
rm -f /tmp/zcode/.cmp_n /tmp/zcode/.cmp_o /tmp/zcode/.cmp_nk /tmp/zcode/.cmp_ok

sudo umount "$M_N"; sudo rmdir "$M_N"; sudo umount "$M_O"; sudo rmdir "$M_O"
say "报告已存 $OUT"
say "COMPARE-DONE"
