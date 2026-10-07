#!/usr/bin/env bash
# 30-build-m2381.sh —— m2381 rootfs 构建驱动（宿主跑；全程 sudo + loop）
#
# 串联：01-lay（Frame→ext4 铺盘）→ chroot 注入（10-graft-m2381 + work/layer）→
#       03-finalize（收缩+UUID）→ 04-verify-esp（ESP 内核 vs 模块目录闸）
#
# 用法: sudo bash scripts/host/30-build-m2381.sh
#
# 构建入参（现场 export，不进仓）：
#   WIFI_SSID / WIFI_PSK   可选，缺省 = 不预配 WiFi（开机 nmcli 手连）
#   ROOT_PW                可选，缺省 = 构建尾随机生成并打印
#   SSH_PUBKEY             可选，缺省 = 构建机 $HOME/.ssh/id_ed25519.pub
#   ROOTFS_SIZE            镜像上限（默认 14G；01-lay 会按源用量自适应放大）
#   BUILD_KDE_MONITOR      默认 0（qemu 下自编 KDE 组件太慢，P0 不需要）
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[[ "${EUID}" -eq 0 ]] || { echo "需要 root（sudo bash …）" >&2; exit 1; }
# shellcheck source=config.sh
source "$HERE/config.sh" || true   # 只取钉子给注释/一致性；构建不依赖其函数

WORK="$SM20_ROOT/work"
OUT="$WORK/out"
LAYER="$WORK/layer"
IMG="$WORK/rootfs.img"
MOUNT=/mnt/rootfs
PARTLABEL="${PARTLABEL:-$TARGET_PARTLABEL}"

log()  { printf '[%s] %s\n' "${0##*/}" "$*"; }
warn() { printf '[%s] 警告: %s\n' "${0##*/}" "$*" >&2; }
die()  { printf '[%s] 错误: %s\n' "${0##*/}" "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 前置
# 底包/层缺失自动补料（01-lay 会删 rootfs.frame，重跑构建是常态）
if [[ ! -f "$OUT/rootfs.frame" ]]; then
  log "缺 rootfs.frame → 自动跑 00-fetch（本地 bz2 优先）"
  BZ2="$(ls -1 "$SM20_DL_DIR"/*.img.bz2 2>/dev/null | head -1 || true)"
  FRAME_URL="${FRAME_IMAGE_URL:-${BZ2:+file://$BZ2}}"
  FRAME_URL="${FRAME_URL:-$PIN_FRAME_URL}"
  FRAME_BASE_SKIP=1 WORK="$WORK" OUT="$OUT" FRAME_IMAGE_URL="$FRAME_URL" \
    bash "$HERE/scripts/host/00-fetch-frame-rootfs.sh"
fi
[[ -f "$OUT/rootfs.frame" ]] || die "00-fetch 之后仍没有 $OUT/rootfs.frame"
if [[ ! -d "$LAYER/usr/lib/modules" ]]; then
  log "缺 layer → 自动跑 20-m2381-layer"
  bash "$HERE/scripts/host/20-m2381-layer.sh"
fi
[[ -d "$LAYER/usr/lib/modules" ]] || die "20-m2381-layer 之后仍没有 $LAYER"
KVER="$(cat "$LAYER/.kver")"
[[ -n "$KVER" ]] || die "layer/.kver 为空"
log "KVER=$KVER  PARTLABEL=$PARTLABEL  底包=$(cat "$OUT/frame-os-release" | grep -m1 BUILD_ID || echo '?')"

# 构建入参缺省（sudo 下 HOME 可能是 /root —— 依次找构建机用户的 key）
# ⚠ 随机密码别用 `tr </dev/urandom | head`：head 提前关管 = tr SIGPIPE，pipefail 会杀整脚本
[[ -n "${ROOT_PW:-}" ]] || { ROOT_PW="$(od -An -N8 -tx4 /dev/urandom | tr -d ' \n' | cut -c1-16)"; GEN_PW=1; }
if [[ -z "${SSH_PUBKEY:-}" ]]; then
  for h in "$HOME" "${SUDO_USER:+/home/$SUDO_USER}" /home/ri /home/ri/ubuntu; do
    if [[ -n "$h" && -s "$h/.ssh/id_ed25519.pub" ]]; then
      SSH_PUBKEY="$(cat "$h/.ssh/id_ed25519.pub")"; break
    fi
  done || true
fi
[[ -n "${SSH_PUBKEY:-}" ]] || warn "没有 SSH 公钥 —— 设备日只能靠 root 密码进"

cleanup() {
  for m in "$MOUNT/dev/pts" "$MOUNT/dev" "$MOUNT/proc" "$MOUNT/sys" "$MOUNT"; do
    mountpoint -q "$m" 2>/dev/null && umount -R "$m" 2>/dev/null || true
  done
}
trap cleanup EXIT

# ---------------------------------------------------------------- 1) 铺盘
log "[1/5] 01-lay-rootfs：Frame userspace → $IMG"
rm -f "$IMG"
bash "$HERE/scripts/host/01-lay-rootfs.sh" "$OUT/rootfs.frame" "$IMG" "${ROOTFS_SIZE:-14G}"

# ---------------------------------------------------------------- 2) 挂载 + 注入
log "[2/5] 挂载 chroot 并注入 m2381 层"
mkdir -p "$MOUNT"
mount -o loop "$IMG" "$MOUNT"
for d in dev dev/pts proc sys tmp; do mkdir -p "$MOUNT/$d"; done
mount --bind /dev "$MOUNT/dev"
mount --bind /dev/pts "$MOUNT/dev/pts"
mount -t proc proc "$MOUNT/proc"
mount -t sysfs sys "$MOUNT/sys"
# resolv.conf 可能是悬空软链（Frame 指向 /run/systemd/resolve/...），先删再写（上游注释的坑）
rm -f "$MOUNT/etc/resolv.conf"
cp /etc/resolv.conf "$MOUNT/etc/resolv.conf" 2>/dev/null \
  || printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$MOUNT/etc/resolv.conf"
mkdir -p "$MOUNT/root/graft"
cp -a "$LAYER" "$MOUNT/root/graft/layer"
cp "$HERE/scripts/in-chroot/10-graft-m2381.sh" "$MOUNT/root/graft/"
chmod +x "$MOUNT/root/graft/10-graft-m2381.sh"

log "[3/5] chroot 跑 10-graft-m2381（qemu-aarch64 + binfmt）"
chroot "$MOUNT" /bin/bash -c \
  "PARTLABEL='$PARTLABEL' KVER='$KVER' ROOT_PW='$ROOT_PW' SSH_PUBKEY='${SSH_PUBKEY:-}' \
   WIFI_SSID='${WIFI_SSID:-}' WIFI_PSK='${WIFI_PSK:-}' \
   BUILD_KDE_MONITOR='${BUILD_KDE_MONITOR:-0}' DOWNLOAD_STEAM_CLIENT='${DOWNLOAD_STEAM_CLIENT:-1}' \
   bash /root/graft/10-graft-m2381.sh"

rm -f "$MOUNT/root/graft/10-graft-m2381.sh"
rm -rf "$MOUNT/root/graft/layer"
sync
cleanup
log "[4/5] 03-finalize：e2fsck + 收缩 + 固定 UUID"
SHRINK_IMAGE="${SHRINK_IMAGE:-true}" bash "$HERE/scripts/host/03-finalize-image.sh" "$IMG" "$MOUNT"

# ---------------------------------------------------------------- 5) 终检
log "[5/5] 04-verify-esp：ESP 内核 vs 模块目录"
ESP_SRC="${ESP_IMG:-$REL_ESP_IMG}"
[[ -e "$ESP_SRC" ]] || die "ESP 镜像不存在: $ESP_SRC（config.sh REL_ESP_IMG）"
bash "$HERE/scripts/host/04-verify-esp-kernel-match.sh" "$ESP_SRC" "$IMG"

SHA="$(sha256sum "$IMG" | awk '{print $1}')"
SIZE="$(ls -lh "$IMG" | awk '{print $5}')"
BASE_VER="$(grep -m1 BUILD_ID "$OUT/frame-os-release" | cut -d= -f2 || true)"
{
  echo ""
  echo "================ 构建完成 ================"
  echo "  rootfs.img : $IMG"
  echo "  尺寸/SHA256: $SIZE  $SHA"
  echo "  KVER       : $KVER（ESP 腿 vmlinuz-efi 已比对一致）"
  echo "  底包       : SteamOS holo $BASE_VER"
  echo "  root 密码  : $ROOT_PW$([[ -n "${GEN_PW:-}" ]] && echo '  （本次随机生成，仅打印不落盘）')"
  echo "  WiFi 预配  : $([[ -n "${WIFI_SSID:-}" ]] && echo "已预配 $WIFI_SSID" || echo '未预配（开机 nmcli 手连）')"
  echo "  SSH 公钥   : $([[ -n "${SSH_PUBKEY:-}" ]] && echo 已注入 || echo 未注入)"
  echo "  刷写       : fastboot flash userdata <(本镜像)  —— 只动 userdata，boot_b/ESP/recovery 全不碰"
  echo "=========================================="
} | tee "$WORK/build-result.txt"
