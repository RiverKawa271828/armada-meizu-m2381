#!/usr/bin/env bash
# 20-m2381-layer.sh —— 组装 m2381 设备层（替代上游 archlinux-sheng pacman 包）
#
# 用法: bash scripts/host/20-m2381-layer.sh
# 产物: work/layer/          （graft 时以 cp -a 整树灌进 rootfs）
#       work/layer/.kver     （内核版本目录名，graft/verify 都对它）
#
# 四件（P0 最小集，详见 docs/M2381-PLAN.md §2）：
#   ① 内核模块   ← 在机同源 apk linux-meizu-meizu20-*-r66（usr/lib/modules/<KVER>）
#   ② 固件       ← firmware-meizu-meizu20 apk（qcom/qca/cirrus/ath12k 收割件）
#   ③ 设备 units ← pmaports device-meizu-meizu20（r53）：触控 bind、PAS(ADSP/CDSP，
#                  充电判据前置)、mem_sleep 钉 s2idle、aw8697 震动 SE bind + udev 规则、
#                  modprobe 黑名单（i2c_qcom_geni 冷插拔 = 秒级硬复位，必带）
#   ④ 睡眠 mask  ← pmOS meizu-sleepmask(tmpfiles) + 自造补齐（hybrid-sleep/
#                  suspend-then-hibernate + sleep.conf.d 全关）
# P0 故意不含：音频链（PipeWire 翻译 = P2）、hexagonrpcd 传感器链（glibc 重建 = P2）、
#              蜂窝/GNSS（RF init 硬卡死，同 pmOS）。
#              uinput 原因同上曾排除；r78 起内核已编 CONFIG_INPUT_UINPUT=m，
#              见 ⑤ Steam Input 件（2026-10-10 nura 带话闭环）。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=config.sh
source "$HERE/config.sh"

PMOS_PKGS="$SM20_WORK/pmos_linux/pmos/.pmbootstrap/packages/edge/aarch64"
DEV="$PIN_PMAPORTS/device/downstream/device-meizu-meizu20"
LAYER="$SM20_ROOT/work/layer"

log() { printf '[%s] %s\n' "${0##*/}" "$*"; }
die() { printf '[%s] 错误: %s\n' "${0##*/}" "$*" >&2; exit 1; }

need() { [[ -e "$1" ]] || die "缺 $1（$2）"; }

# ① 内核模块
need "$PMOS_PKGS" "pmbootstrap 包仓（.pmbootstrap/packages）不在预期位置"
KAPK="$(ls -1t "$PMOS_PKGS"/linux-meizu-meizu20-*"-r${REL_LINUX_PKGREL}.apk" 2>/dev/null | head -1 || true)"
[[ -n "$KAPK" ]] || die "找不到 r${REL_LINUX_PKGREL} 内核 apk（$PMOS_PKGS/linux-meizu-meizu20-*-r${REL_LINUX_PKGREL}.apk）"
need "$DEV" "pmaports device-meizu-meizu20 不在（phoenix 分支）"

rm -rf "$LAYER"
mkdir -p "$LAYER"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
log "解内核 apk: $(basename "$KAPK")"
tar xzf "$KAPK" -C "$TMP"
KVER="$(ls -1 "$TMP/usr/lib/modules" | head -1)"
[[ -n "$KVER" ]] || die "apk 里没有 /usr/lib/modules/*"
mkdir -p "$LAYER/usr/lib/modules"
cp -a "$TMP/usr/lib/modules/$KVER" "$LAYER/usr/lib/modules/"
printf '%s\n' "$KVER" > "$LAYER/.kver"
log "KVER=$KVER（模块 $(du -sh "$LAYER/usr/lib/modules/$KVER" | cut -f1)）"

# ② 固件
FAPK="$(ls -1t "$PMOS_PKGS"/firmware-meizu-meizu20-*-r*.apk 2>/dev/null | head -1 || true)"
[[ -n "$FAPK" ]] || die "找不到 firmware-meizu-meizu20 apk"
log "解固件 apk: $(basename "$FAPK")"
tar xzf "$FAPK" -C "$TMP"
[[ -d "$TMP/lib/firmware" ]] || die "固件 apk 里没有 lib/firmware"
mkdir -p "$LAYER/usr/lib"
cp -a "$TMP/lib/firmware" "$LAYER/usr/lib/firmware"
log "固件: $(du -sh "$LAYER/usr/lib/firmware" | cut -f1)（$(ls "$LAYER/usr/lib/firmware" | tr '\n' ' ')）"

# ③ 设备 units（P0 最小集；enable 放 graft 里做）
log "拷设备 units ← $DEV"
install -Dm644 "$DEV/meizu-touch.service"          "$LAYER/usr/lib/systemd/system/meizu-touch.service"
install -Dm644 "$DEV/meizu-pas.service"            "$LAYER/usr/lib/systemd/system/meizu-pas.service"
install -Dm644 "$DEV/meizu-memsleep.service"       "$LAYER/usr/lib/systemd/system/meizu-memsleep.service"
install -Dm644 "$DEV/meizu-bind-nfc-haptics.service" "$LAYER/usr/lib/systemd/system/meizu-bind-nfc-haptics.service"
install -Dm755 "$DEV/meizu-touch-load.sh"          "$LAYER/usr/lib/meizu20/meizu-touch-load.sh"
install -Dm755 "$DEV/meizu-bind-nfc-haptics.sh"    "$LAYER/usr/lib/meizu20/meizu-bind-nfc-haptics.sh"
install -Dm644 "$DEV/modprobe.conf"                "$LAYER/etc/modprobe.d/50-meizu20-blacklist.conf"
install -Dm644 "$DEV/70-meizu20-vibra.rules"       "$LAYER/usr/lib/udev/rules.d/70-meizu20-vibra.rules"

# ③b 音频编排件（r77 内核本就有 sndcard——nura 2026-10-09 反转判词实锤；
#  v3 Debian 实机平移此串后即出声。enable 放 graft；meizu-audio 仅入仓不 enable，
#  SWR CLASH 链只许手动起，见 preset 注）
install -Dm755 "$DEV/meizu-amps-load.sh"           "$LAYER/usr/lib/meizu20/meizu-amps-load.sh"
install -Dm755 "$DEV/meizu-sndcard-bind.sh"        "$LAYER/usr/lib/meizu20/meizu-sndcard-bind.sh"
install -Dm755 "$DEV/meizu-audio-route.sh"         "$LAYER/usr/lib/meizu20/meizu-audio-route.sh"
install -Dm755 "$DEV/meizu-audio-load.sh"          "$LAYER/usr/lib/meizu20/meizu-audio-load.sh"
install -Dm644 "$DEV/meizu-amps.service"           "$LAYER/usr/lib/systemd/system/meizu-amps.service"
install -Dm644 "$DEV/meizu-sndcard-bind.service"   "$LAYER/usr/lib/systemd/system/meizu-sndcard-bind.service"
install -Dm644 "$DEV/meizu-audio-route.service"    "$LAYER/usr/lib/systemd/system/meizu-audio-route.service"
install -Dm644 "$DEV/meizu-audio.service"          "$LAYER/usr/lib/systemd/system/meizu-audio.service"
install -Dm644 "$DEV/MEIZU20.conf"                 "$LAYER/usr/share/alsa/ucm2/Qualcomm/sm8550/MEIZU20.conf"
install -Dm644 "$DEV/HiFi.conf"                    "$LAYER/usr/share/alsa/ucm2/Qualcomm/sm8550/HiFi.conf"
install -Dm644 "$DEV/MEIZU20-tplg.bin"             "$LAYER/usr/lib/firmware/qcom/sm8550/MEIZU20-tplg.bin"
mkdir -p "$LAYER/usr/share/alsa/ucm2/conf.d/sm8550"
ln -sfn ../../Qualcomm/sm8550/MEIZU20.conf "$LAYER/usr/share/alsa/ucm2/conf.d/sm8550/MEIZU20.conf"

# ④ 睡眠 mask（pmOS 结构件 + m2381 补齐）
#  pmOS r54 起已从设备包撤掉 sleepmask tmpfiles（内核侧治本后那边不再需要）；
#  我们仍要 mask —— SteamOS 线没带 pmOS 的睡眠用户态栈（WoWLAN/看门狗放宽等），
#  裸挂起照旧危险。pmOS sleepmask 文件在就用，不在（r58+）就靠自家两件顶上。
if [[ -f "$DEV/meizu-sleepmask.conf" ]]; then
  install -Dm644 "$DEV/meizu-sleepmask.conf" "$LAYER/usr/lib/tmpfiles.d/meizu-sleepmask.conf"
else
  log "pmOS 设备包已撤 sleepmask（r54+）—— 用自家 sm20-sleepmask 全量顶上"
  install -d "$LAYER/usr/lib/tmpfiles.d"
  cat > "$LAYER/usr/lib/tmpfiles.d/meizu-sleepmask.conf" <<'EOF'
# m2381(SteamOS): sleep 家族全 mask（pmOS r54 起撤件，我们无其睡眠栈，保留全套）
L /etc/systemd/system/sleep.target - - - - /dev/null
L /etc/systemd/system/suspend.target - - - - /dev/null
L /etc/systemd/system/hibernate.target - - - - /dev/null
EOF
fi
cat > "$LAYER/usr/lib/tmpfiles.d/sm20-sleepmask.conf" <<'EOF'
# m2381: pmOS sleepmask 之外补齐其余 sleep 目标（suspend 在本移植上必睡死）
L /etc/systemd/system/hybrid-sleep.target - - - - /dev/null
L /etc/systemd/system/suspend-then-hibernate.target - - - - /dev/null
EOF
install -d "$LAYER/etc/systemd/sleep.conf.d"
cat > "$LAYER/etc/systemd/sleep.conf.d/sm20-nosleep.conf" <<'EOF'
# m2381: 全部睡眠路径关死（deep 必死、s2idle 睡入无 resume——见 pmos AGENTS suspend 节）
# AllowSuspend=no 让 logind CanSuspend=no：powerdevil/SDDM 直接收「不可用」，不再尝试
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
EOF

# ⑤ Steam Input 件（2026-10-10 nura 带话闭环：内核 r78 起 CONFIG_INPUT_UINPUT=m）
#  uinput.ko ← 最新内核 apk（r78 config-only 轮新增；主模块树仍钉 r${REL_LINUX_PKGREL}，
#  两者同 KVER 同 vermagic、无 MODVERSIONS，单补 ko 兼容，nura 实证）
UAPK="$(ls -1t "$PMOS_PKGS"/linux-meizu-meizu20-*"-r"*.apk 2>/dev/null | head -1 || true)"
[[ -n "$UAPK" ]] || die "找不到内核 apk（uinput.ko 来源，$PMOS_PKGS）"
UKO_PATH="usr/lib/modules/$KVER/kernel/drivers/input/misc/uinput.ko"
mkdir -p "$TMP/uinput"
tar xzf "$UAPK" -C "$TMP/uinput" "$UKO_PATH" 2>/dev/null
[[ -f "$TMP/uinput/$UKO_PATH" ]] || die "$(basename "$UAPK") 里没有 $UKO_PATH（需 r78+ 内核包）"
install -Dm644 "$TMP/uinput/$UKO_PATH" "$LAYER/$UKO_PATH"
log "uinput.ko ← $(basename "$UAPK")"
#  用户态胶水三件 + s2idle 看门狗 drop-in，照抄 pmaports 设备包 r58/r59（文件名即挂点）
install -Dm644 "$DEV/60-meizu20-uinput.rules" "$LAYER/usr/lib/udev/rules.d/60-meizu20-uinput.rules"
install -Dm644 "$DEV/meizu20-uinput.conf"     "$LAYER/usr/lib/modules-load.d/meizu20-uinput.conf"
#  r58: s2idle 跳过 syscore ⇒ 睡眠时长计入 monotonic ⇒ 3min 看门狗在唤醒瞬间误杀服务。
#  会话关键（udevd/logind）关狗；内部服务放宽 30min。睡眠 mask 未解锁前 inert，解锁前置件。
for u in systemd-udevd systemd-logind; do
  install -Dm644 "$DEV/10-meizu-no-watchdog.conf" \
    "$LAYER/usr/lib/systemd/system/$u.service.d/10-meizu-no-watchdog.conf"
done
for u in systemd-journald systemd-resolved systemd-timesyncd systemd-coredumpd \
  systemd-hostnamed systemd-importd systemd-localed systemd-machined \
  systemd-portabled systemd-sysupdated systemd-timedated systemd-oomd \
  systemd-mountfsd systemd-nsresourced; do
  install -Dm644 "$DEV/10-meizu-watchdog-relax.conf" \
    "$LAYER/usr/lib/systemd/system/$u.service.d/10-meizu-watchdog-relax.conf"
done
install -Dm644 "$DEV/10-meizu-journald-sync.conf" \
  "$LAYER/usr/lib/systemd/journald.conf.d/10-meizu-journald-sync.conf"

# 自检：层内关键文件点名
log "层自检："
for f in "usr/lib/modules/$KVER/kernel" \
         "usr/lib/modules/$KVER/modules.dep" \
         "usr/lib/modules/$KVER/kernel/drivers/input/misc/uinput.ko" \
         usr/lib/firmware/qcom/sm8550 \
         usr/lib/firmware/ath12k/WCN7850 \
         usr/lib/systemd/system/meizu-touch.service \
         usr/lib/systemd/system/meizu-pas.service \
         usr/lib/meizu20/meizu-touch-load.sh \
         etc/modprobe.d/50-meizu20-blacklist.conf \
         usr/lib/udev/rules.d/70-meizu20-vibra.rules \
         usr/lib/udev/rules.d/60-meizu20-uinput.rules \
         usr/lib/modules-load.d/meizu20-uinput.conf \
         usr/lib/systemd/system/systemd-logind.service.d/10-meizu-no-watchdog.conf \
         usr/lib/systemd/journald.conf.d/10-meizu-journald-sync.conf \
         usr/lib/tmpfiles.d/meizu-sleepmask.conf \
         etc/systemd/sleep.conf.d/sm20-nosleep.conf; do
  if [[ -e "$LAYER/$f" ]]; then log "  ✓ $f"; else log "  ✗ 缺 $f"; FAIL=1; fi
done
[[ -z "${FAIL:-}" ]] || die "层自检有缺件"
if [[ ! -s "$LAYER/usr/lib/modules/$KVER/modules.dep" ]]; then
  log "  ⚠ apk 未带 modules.dep（graft 会跑 depmod -a $KVER 补）"
fi
log "层就绪: $LAYER（KVER=$KVER，总计 $(du -sh "$LAYER" | cut -f1)）"
