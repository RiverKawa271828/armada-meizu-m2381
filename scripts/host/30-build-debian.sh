#!/usr/bin/env bash
# 30-build-debian.sh —— m2381 Debian rootfs 构建驱动（宿主跑；全程 sudo + loop）
#
# 串联：00-fetch-debian（USTC 国内源 qcow2）→ 01-lay-debian（铺盘）→
#       chroot 注入（10-graft-debian + work/layer）→ 03-finalize → 04-verify-esp
#
# 用法: sudo bash scripts/host/30-build-debian.sh
#
# 构建入参（现场 export，不进仓）：
#   ROOT_PW                可选，缺省 = 123456（兴趣线固定密码，用户拍板）
#   SSH_PUBKEY             可选，缺省 = 构建机用户 id_ed25519.pub
#   ROOTFS_SIZE            镜像上限（默认 10G；01-lay 按源用量自适应放大）
#   IMG_NAME               产物文件名（默认 meizu-meizu20-debian-r77.img）
#   DOWNLOAD_STEAM_CLIENT  默认 1（播种 Valve ARM64 客户端）
#   Steam zip 缓存 = work/cache/steam-arm（按版本件名缓存，命中免下载，损坏自愈）
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[[ "${EUID}" -eq 0 ]] || { echo "需要 root（sudo bash …）" >&2; exit 1; }
# shellcheck source=config.sh
source "$HERE/config.sh" || true   # REL_ESP_IMG 等钉子

WORK="$HERE/work"
OUT="$WORK/out"
LAYER="$WORK/layer"
STEAM_CACHE="$WORK/cache/steam-arm"
IMG="$WORK/${IMG_NAME:-meizu-meizu20-debian-r77.img}"
MOUNT=/mnt/rootfs
PARTLABEL="${PARTLABEL:-$TARGET_PARTLABEL}"
QCOW2="$OUT/debian-13-genericcloud-arm64.qcow2"

log()  { printf '[%s] %s\n' "${0##*/}" "$*"; }
warn() { printf '[%s] 警告: %s\n' "${0##*/}" "$*" >&2; }
die()  { printf '[%s] 错误: %s\n' "${0##*/}" "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 前置
if [[ ! -f "$QCOW2" ]]; then
  log "缺底包 → 00-fetch-debian（USTC 国内源优先）"
  bash "$HERE/scripts/host/00-fetch-debian.sh"
fi
[[ -f "$QCOW2" ]] || die "底包仍缺失: $QCOW2"
if [[ ! -d "$LAYER/usr/lib/modules" ]]; then
  log "缺 layer → 自动跑 20-m2381-layer"
  bash "$HERE/scripts/host/20-m2381-layer.sh"
fi
[[ -d "$LAYER/usr/lib/modules" ]] || die "20-m2381-layer 之后仍没有 $LAYER"
KVER="$(cat "$LAYER/.kver")"
[[ -n "$KVER" ]] || die "layer/.kver 为空"
[[ -e "$REL_ESP_IMG" ]] || die "ESP 产物不存在: $REL_ESP_IMG（config.sh）"
log "KVER=$KVER  PARTLABEL=$PARTLABEL  底包=$(grep -o 'mirror=[^ ]*' "$OUT/debian-base-info.txt" 2>/dev/null || echo '?')"

[[ -n "${ROOT_PW:-}" ]] || ROOT_PW=123456
if [[ -z "${SSH_PUBKEY:-}" ]]; then
  for h in "$HOME" "${SUDO_USER:+/home/$SUDO_USER}" /home/ri /home/ri/ubuntu; do
    if [[ -n "$h" && -s "$h/.ssh/id_ed25519.pub" ]]; then
      SSH_PUBKEY="$(cat "$h/.ssh/id_ed25519.pub")"; break
    fi
  done || true
fi
[[ -n "${SSH_PUBKEY:-}" ]] || warn "没有 SSH 公钥 —— 设备日只能密码进"

cleanup() {
  for m in "$MOUNT/dev/pts" "$MOUNT/dev" "$MOUNT/proc" "$MOUNT/sys" "$MOUNT/mnt/steam-cache" "$MOUNT"; do
    mountpoint -q "$m" 2>/dev/null && umount -R "$m" 2>/dev/null || true
  done
}
trap cleanup EXIT

# ---------------------------------------------------------------- 1) 铺盘
log "[1/5] 01-lay-debian：Debian base → $IMG"
rm -f "$IMG"
bash "$HERE/scripts/host/01-lay-debian.sh" "$QCOW2" "$IMG" "${ROOTFS_SIZE:-10G}"

# ---------------------------------------------------------------- 2) 挂载 + 注入
log "[2/5] 挂载 chroot 并注入 m2381 层"
mkdir -p "$MOUNT"
mount -o loop "$IMG" "$MOUNT"
for d in dev dev/pts proc sys tmp; do mkdir -p "$MOUNT/$d"; done
mount --bind /dev "$MOUNT/dev"
mount --bind /dev/pts "$MOUNT/dev/pts"
mount -t proc proc "$MOUNT/proc"
mount -t sysfs sys "$MOUNT/sys"
mkdir -p "$MOUNT/mnt/steam-cache" "$STEAM_CACHE"
mount --bind "$STEAM_CACHE" "$MOUNT/mnt/steam-cache"
rm -f "$MOUNT/etc/resolv.conf"
cp /etc/resolv.conf "$MOUNT/etc/resolv.conf" 2>/dev/null \
  || printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$MOUNT/etc/resolv.conf"
mkdir -p "$MOUNT/root/graft"
cp -a "$LAYER" "$MOUNT/root/graft/layer"
install -m 0755 "$HERE/scripts/in-chroot/10-graft-debian.sh" "$MOUNT/root/graft/"

log "[3/5] chroot 跑 10-graft-debian（qemu-aarch64 + binfmt）"
chroot "$MOUNT" /bin/bash -c \
  "PARTLABEL='$PARTLABEL' KVER='$KVER' ROOT_PW='$ROOT_PW' SSH_PUBKEY='${SSH_PUBKEY:-}' \
   DOWNLOAD_STEAM_CLIENT='${DOWNLOAD_STEAM_CLIENT:-1}' STEAM_CACHE=/mnt/steam-cache \
   bash /root/graft/10-graft-debian.sh"

rm -rf "$MOUNT/root/graft"
sync
cleanup
log "[4/5] 03-finalize：e2fsck + 收缩 + 固定 UUID"
SHRINK_IMAGE="${SHRINK_IMAGE:-true}" bash "$HERE/scripts/host/03-finalize-image.sh" "$IMG" "$MOUNT"

# ---------------------------------------------------------------- 5) 终检
log "[5/5] 04-verify-esp：ESP 内核 vs 模块目录"
bash "$HERE/scripts/host/04-verify-esp-kernel-match.sh" "$REL_ESP_IMG" "$IMG"

SHA="$(sha256sum "$IMG" | awk '{print $1}')"
SIZE="$(ls -lh "$IMG" | awk '{print $5}')"
{
  echo ""
  echo "================ 构建完成（Debian 线） ================"
  echo "  rootfs.img : $IMG"
  echo "  尺寸/SHA256: $SIZE  $SHA"
  echo "  KVER       : $KVER（ESP 腿 vmlinuz-efi 已比对一致）"
  echo "  底包       : Debian 13 trixie genericcloud（$(grep -o 'mirror=.*' "$OUT/debian-base-info.txt" 2>/dev/null | cut -d= -f2)）"
  echo "  root 密码  : $ROOT_PW（steamos 用户同密码）"
  echo "  刷写       : fastboot flash userdata <(本镜像) —— 只动 userdata"
  echo "=========================================="
} | tee "$WORK/build-result.txt"
