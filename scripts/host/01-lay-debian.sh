#!/usr/bin/env bash
# 01-lay-debian.sh —— Debian genericcloud qcow2 → 我们的 ext4 镜像
# 用法: sudo 01-lay-debian.sh <base.qcow2> <rootfs.img> <大小,如 10G>
#
# 与 holo 版 01-lay 的差异：源是单分区 ext4 的 qcow2（无 btrfs 子卷/无 xattr 坑），
# qemu-img 转 raw 后 losetup -P 直接挂 p1，rsync 进空白目标镜像。
# 顺手清掉：自带内核/模块/initramfs（我们走 ESP 内核腿 + m2381 层）、
# machine-id / ssh host key / resolv.conf / fstab / hostname（graft 重造）。
set -euo pipefail
log()  { printf '[%s] %s\n' "${0##*/}" "$*"; }
warn() { printf '[%s] 警告: %s\n' "${0##*/}" "$*" >&2; }
die()  { printf '[%s] 错误: %s\n' "${0##*/}" "$*" >&2; exit 1; }
[[ "${EUID}" -eq 0 ]] || die "需要 root"
SRC="${1:?用法: 01-lay-debian.sh <base.qcow2> <rootfs.img> <size>}"
IMG="${2:?}"
SIZE="${3:-10G}"
MOUNT_SRC=/mnt/debian-src
MOUNT_DST=/mnt/rootfs
RAW="$(dirname "$SRC")/debian-base.raw"

command -v qemu-img >/dev/null || die "缺 qemu-img（dnf install qemu-img）"
mkdir -p "$MOUNT_SRC" "$MOUNT_DST"
umount "$MOUNT_SRC" 2>/dev/null || true
umount "$MOUNT_DST" 2>/dev/null || true
losetup -D 2>/dev/null || true

# 1) qcow2 → raw → loop 带分区
log "qcow2 → raw（$(du -h "$SRC" | cut -f1)）"
rm -f "$RAW"
qemu-img convert -O raw "$SRC" "$RAW"
LOOP="$(losetup -f --show -P "$RAW")"
PART="${LOOP}p1"
sleep 1
[[ -b "$PART" ]] || PART="$LOOP"
log "loop=$LOOP root分区=$PART"

cleanup() {
  umount "$MOUNT_DST" 2>/dev/null || true
  umount "$MOUNT_SRC" 2>/dev/null || true
  losetup -d "$LOOP" 2>/dev/null || true
}
trap cleanup EXIT

mount -o ro "$PART" "$MOUNT_SRC" || die "挂底包 root 分区失败"

# 2) 量用量 → 目标尺寸自适应（源 + 1.5G 余量，不小于请求下限）
need_mb="$(du -sm --exclude=proc --exclude=sys --exclude=dev --exclude=run --exclude=tmp "$MOUNT_SRC" 2>/dev/null | cut -f1)"
need_mb=$(( need_mb + 1536 ))
_sz="${SIZE^^}"; _unit="${_sz: -1}"; _num="${_sz%?}"
case "$_unit" in
  G) want_mb=$(( ${_num%.*} * 1024 ));;
  M) want_mb=$(( ${_num%.*} ));;
  *) warn "无法解析尺寸 $SIZE，按源用量决定"; want_mb=0;;
esac
use_mb=$(( need_mb > want_mb ? need_mb : want_mb ))
log "源用量 ${need_mb} MiB（含余量），请求 ${want_mb} MiB → 创建 ${use_mb} MiB"
avail_mb="$(df -Pm "$(dirname "$SRC")" | awk 'NR==2{print $4}')"
raw_mb=$(( $(stat -c %s "$RAW") / 1048576 ))
max_mb=$(( avail_mb + raw_mb - 1024 ))
if [[ "$use_mb" -gt "$max_mb" ]]; then
  warn "请求 ${use_mb} MiB 超过磁盘上限 ${max_mb} MiB，压缩（可能 ENOSPC）"
  use_mb="$max_mb"
fi

# 3) 建目标 ext4（label rootfs）
log "创建 ext4 $IMG ($(( use_mb / 1024 )) GiB)"
rm -f "$IMG"; truncate -s "${use_mb}M" "$IMG"
mkfs.ext4 -q -F -L rootfs "$IMG" || die "mkfs.ext4 失败"
mount -o loop "$IMG" "$MOUNT_DST" || die "挂新镜像失败"

# 4) rsync（SELinux 宿主：不带 -X；POSIX ACL 保留）
log "rsync Debian userspace → 我们的镜像"
RSYNC_LOG="$(dirname "$SRC")/lay-rsync.log"
set +e
rsync -aHA --numeric-ids --info=progress2 \
  --exclude='/proc/*' --exclude='/sys/*' --exclude='/dev/*' --exclude='/run/*' \
  --exclude='/tmp/*' --exclude='/boot/*' --exclude='/usr/lib/modules/*' \
  --exclude='/var/cache/apt/archives/*' \
  "$MOUNT_SRC/" "$MOUNT_DST/" 2>"$RSYNC_LOG"
rc="$?"
set -e
if [[ "$rc" -ne 0 ]]; then
  tail -20 "$RSYNC_LOG" | sed 's/^/    /' >&2
  die "rsync 失败（rc=$rc）"
fi

# 5) 清身份/引导残留（graft 重造）
rm -f "$MOUNT_DST/etc/machine-id" "$MOUNT_DST/var/lib/dbus/machine-id"
rm -f "$MOUNT_DST"/etc/ssh/ssh_host_*
rm -f "$MOUNT_DST/etc/resolv.conf" "$MOUNT_DST/etc/fstab" "$MOUNT_DST/etc/hostname"
rm -rf "$MOUNT_DST/etc/sudoers.d/90-cloud-init-users" 2>/dev/null || true

log "目标用量：$(du -sh "$MOUNT_DST" 2>/dev/null | cut -f1)"
sync
umount "$MOUNT_DST"; umount "$MOUNT_SRC"; trap - EXIT
losetup -d "$LOOP" 2>/dev/null || true
rm -f "$RAW" && log "已删除 raw 中间件（释放 $(( raw_mb / 1024 )) GiB）"
log "已铺好: $IMG"
