#!/usr/bin/env bash
# 04-verify-esp-kernel-match.sh —— 校验 ESP 引导内核版本与 rootfs 模块目录一致（m2381 版）
#
# 为什么必须有这道闸：内核只从 /usr/lib/modules/$(uname -r)/ 找模块，且模块 vermagic 必须
# 与内核完全一致，否则「rootfs 有模块但内核一个都不加载」→ 黑屏且日志无构建期错误。
# 与上游 04 的差别：上游从 boot.img 抠内核；m2381 不刷 boot —— 内核在 ESP（recovery_a）
# 的 \EFI\BOOT\BOOTAA64.EFI（EFI-stub 直启内核本体）。它可能是：
#   · zstd zboot 包装（magic 'zimg' @4，payload @8 起）—— pmOS 7.3 内核实测是这个
#   · gzip 压缩 Image（1f8b）或裸 Image（版本串明文可 grep）
#
# 用法: 04-verify-esp-kernel-match.sh <esp.img 或 esp.img.gz> <rootfs.img>
set -euo pipefail
log()  { printf '[%s] %s\n' "${0##*/}" "$*"; }
warn() { printf '[%s] 警告: %s\n' "${0##*/}" "$*" >&2; }
die()  { printf '[%s] 错误: %s\n' "${0##*/}" "$*" >&2; exit 1; }

ESP="${1:?用法: 04-verify-esp-kernel-match.sh <esp.img(.gz)> <rootfs.img>}"
IMG="${2:?}"
[[ -s "$ESP" ]] || die "ESP 镜像不存在: $ESP"
[[ -s "$IMG"  ]] || die "rootfs.img 不存在: $IMG"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
# 0) 解 gz（nura 仓里的 ESP 以 .gz 入库）→ mcopy 抠 BOOTAA64.EFI
# ---------------------------------------------------------------------------
RAW="$ESP"
if [[ "${ESP##*.}" == "gz" ]]; then
  gunzip -c "$ESP" > "$TMP/esp.img"
  RAW="$TMP/esp.img"
fi
command -v mcopy >/dev/null || die "需要 mcopy（mtools）"
mcopy -i "$RAW" ::/EFI/BOOT/BOOTAA64.EFI "$TMP/k.efi" 2>/dev/null \
  || die "ESP 里没有 ::/EFI/BOOT/BOOTAA64.EFI（MsBootPolicy 只认这个路径）"
log "BOOTAA64.EFI: $(du -h "$TMP/k.efi" | cut -f1)"

# ---------------------------------------------------------------------------
# 1) 读内核版本串（zboot-zstd / gzip / 裸 Image 三态）
# ---------------------------------------------------------------------------
magic4="$(dd if="$TMP/k.efi" bs=1 skip=4 count=4 status=none)"
case "$magic4" in
  zimg)
    log "zstd zboot 包装，解 payload"
    off="$(od -An -tu4 -j8 -N4 "$TMP/k.efi" | tr -d ' ')"
    len="$(od -An -tu4 -j12 -N4 "$TMP/k.efi" | tr -d ' ')"
    [[ "$off" -gt 0 && "$len" -gt 0 ]] || die "zboot 头解析失败（offset=$off len=$len）"
    dd if="$TMP/k.efi" of="$TMP/k.zst" bs=1 skip="$off" count="$len" status=none
    zstd -dc "$TMP/k.zst" > "$TMP/k.raw" 2>/dev/null || die "zstd 解 payload 失败";;
  $'\x1f\x8b'*)
    log "gzip 包装，解压"
    gunzip -c "$TMP/k.efi" > "$TMP/k.raw" 2>/dev/null || die "gunzip 失败";;
  *)
    log "无包装（裸 EFI-stub Image），直接读"
    cp "$TMP/k.efi" "$TMP/k.raw";;
esac
[[ -s "$TMP/k.raw" ]] || die "解出的内核为空"
# NUL 分隔 → 按行匹配；grep -m1 命中后 tr 拿 SIGPIPE 属预期噪声，2>/dev/null 压掉
BOOT_VER="$(tr '\0' '\n' < "$TMP/k.raw" 2>/dev/null | grep -m1 -E '^Linux version [0-9]' | awk '{print $3}' || true)"
[[ -n "$BOOT_VER" ]] || die "没能在 ESP 内核里读到 'Linux version …'"
VM="$(tr '\0' '\n' < "$TMP/k.raw" 2>/dev/null | grep -m1 -E '^[0-9][^ ]* SMP (PREEMPT|preempt)' || true)"
log "ESP 内核版本: $BOOT_VER"
[[ -n "$VM" ]] && log "ESP vermagic: ${VM:0:60}…"
[[ -n "$VM" && "${VM%% *}" != "$BOOT_VER" ]] && warn "vermagic 首字段（${VM%% *}）与版本串不一致，以 vermagic 为准更稳"

# ---------------------------------------------------------------------------
# 2) 读 rootfs.img 里的模块目录名（debugfs 直读，不挂载）
# ---------------------------------------------------------------------------
command -v debugfs >/dev/null || die "需要 debugfs（e2fsprogs）"
MODS="$(debugfs -R 'ls -l /usr/lib/modules' "$IMG" 2>/dev/null \
  | awk 'NF>1{print $NF}' | grep -vE '^\.{1,2}$' | grep -E '[0-9]' || true)"
[[ -n "$MODS" ]] || die "rootfs.img 的 /usr/lib/modules 下没有任何版本目录（层没灌上？）"
log "rootfs 里的模块目录："
printf '%s\n' "$MODS" | sed 's/^/    /'

# ---------------------------------------------------------------------------
# 3) 比对
# ---------------------------------------------------------------------------
match=0
while IFS= read -r m; do
  [[ "$m" == "$BOOT_VER" ]] && match=1
done <<< "$MODS"
if [[ "$match" -ne 1 ]]; then
  die "内核与模块版本不一致：ESP 内核是 '$BOOT_VER'，rootfs 里只有 '$(printf '%s' "$MODS" | tr '\n' ' ')
      → 内核不会加载这些模块（找的是 /usr/lib/modules/$BOOT_VER），刷进去必然黑屏。
      → 修法：换模块腿（同 pkgrel 的 linux-meizu apk）或重刷 ESP（make-esp-recovery 腿），
        两腿铁律 = ESP 与 /usr/lib/modules 必须同轮同源。"
fi
log "版本一致 ✓（$BOOT_VER）"

if debugfs -R "stat /usr/lib/modules/$BOOT_VER/modules.dep" "$IMG" >/dev/null 2>&1; then
  log "depmod 产物存在 ✓ (/usr/lib/modules/$BOOT_VER/modules.dep)"
else
  warn "缺少 /usr/lib/modules/$BOOT_VER/modules.dep —— depmod 可能没跑，模块仍不会加载"
fi
log "校验通过：ESP 与 rootfs 内核一致"
