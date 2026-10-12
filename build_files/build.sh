#!/bin/bash
# =============================================================================
# build_files/build.sh — armada-sheng → m2381 (Meizu 20) 适配主构建
# （宿主 root 跑：systemd-run --user 或直接 sudo；产物对齐 03-finalize 惯例）
#
# 输入（相对仓根）:
#   work/armada-m2381/dl/rootfs.img        上游 rootfs（fetch-base.sh 产物，裸 ext4）
#   work/armada-m2381/apk/linux-meizu-meizu20-*-r*.apk  内核腿 apk（fetch.sh，版本钉 BUILD.env）
#   system_files/                          m2381 覆盖层（git 真身；固件缺省回退 work/layer）
#   work/cache/esp-recovery-v62.img        现役 boot 腿（腿配对对拍基准，只读）
# 输出:
#   work/meizu-meizu20-armada-r81.img (+ .sha256 / .MANIFEST.txt)
#
# 阶段:
#   A. 容器根验收（v1.2 = container-export 裸 ext4，无 ostree；清残迹）
#   B. 内核腿（弃 ianchb 树，解 apk；vermagic + 腿配对 sha256 门禁）
#   C. meizu 层注入（system_files/ rsync；固件回退 work/layer）
#   D. 调试件 enable + 手术（boot_b 重写件/bootupd/RNDIS/sheng THP/Decky 全关）
#   E. FEX Mesa xattr 守护 + os-release 归位（r81+ 内核 zstd sqsh 直挂，无重压）
#   F. post_process: 收缩 + 点验
# =============================================================================
set -euxo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "${REPO}/kernel-m2381/BUILD.env"

SRC_DIR="${REPO}/work/armada-m2381/dl"
APK_DIR="${REPO}/work/armada-m2381/apk"
SRC_IMG="${SRC_DIR}/rootfs.img"
ESP_REF="${REPO}/work/cache/esp-recovery-v65.img"
SF="${REPO}/system_files"
FW_FALLBACK="${REPO}/work/layer/usr/lib/firmware"
OUT_IMG="${REPO}/work/meizu-meizu20-armada-r84.img"
ROOT_PW="${ROOT_PW:-123456}"
PUBKEY="${PUBKEY:-/home/ri/ubuntu/.ssh/id_ed25519.pub}"

APK="$(ls -1t "${APK_DIR}"/linux-meizu-meizu20-*-${KERNEL_APK_VERSION}.apk 2>/dev/null | head -1 || true)"
[ -n "${APK}" ] || { echo "ERROR: 缺内核 apk（kernel-m2381/fetch.sh），期望 ${KERNEL_APK_VERSION}" >&2; exit 1; }

MNT=$(mktemp -d /mnt/armada-m2381.XXXX)
ESP_MNT=$(mktemp -d /mnt/armada-espref.XXXX)
LOOP=""; ESP_LOOP=""
cleanup() {
    sudo umount "${MNT}" 2>/dev/null || true
    sudo umount "${ESP_MNT}" 2>/dev/null || true
    [ -n "${LOOP}" ] && sudo losetup -d "${LOOP}" 2>/dev/null || true
    [ -n "${ESP_LOOP}" ] && sudo losetup -d "${ESP_LOOP}" 2>/dev/null || true
    rm -rf "${MNT}" "${ESP_MNT}"
}
trap cleanup EXIT

log() { echo "==> $*"; }

# ---------------------------------------------------------------- 0) 预检
for f in "${SRC_IMG}" "${APK}" "${SF}/etc" "${SF}/usr" "${ESP_REF}"; do
    [ -e "$f" ] || { echo "ERROR: 缺料 $f" >&2; exit 1; }
done
for t in losetup blkid rsync depmod modinfo openssl ssh-keygen e2fsck resize2fs dumpe2fs; do
    command -v "$t" >/dev/null || { echo "ERROR: 宿主缺 $t" >&2; exit 1; }
done
for t in setfattr; do
    command -v "$t" >/dev/null || { echo "WARN: 宿主缺 $t（FEX xattr/os-release 步骤将跳）" >&2; }
done
[ -f "${PUBKEY}" ] || { echo "ERROR: 缺 ${PUBKEY}" >&2; exit 1; }
ACTUAL_SHA=$(sha256sum "${APK}" | cut -d' ' -f1)
[ "${ACTUAL_SHA}" = "${KERNEL_APK_SHA256}" ] || { echo "ERROR: apk sha256 失配 ${ACTUAL_SHA}" >&2; exit 1; }

log "0) 铺工作盘（保留上游原盘不动）"
cp --sparse=always "${SRC_IMG}" "${OUT_IMG}.tmp"
LOOP=$(sudo losetup -fP --show "${OUT_IMG}.tmp")
sleep 1
sudo blkid "${LOOP}" | grep -q 'TYPE="ext4"' || { echo "ERROR: 上盘不是裸 ext4（分区布局变了？）" >&2; exit 1; }
sudo mount "${LOOP}" "${MNT}"

# ---------------------------------------------------------------- 1) 容器根验收
# v1.2 release = container-export（MANIFEST 自述，无 ostree 部署层）：
# usrmerge 软链 + /var 真目录 + /boot 空 + fstab 已写 PARTLABEL=userdata+growfs。
log "1) 容器根验收"
if [ -d "${MNT}/ostree/deploy" ]; then
    echo "ERROR: 该盘含 ostree 部署（非 container-export），脚本按 v1.2 布局写死" >&2
    exit 1
fi
sudo grep -q 'PARTLABEL=userdata' "${MNT}/etc/fstab" || { echo "ERROR: fstab 无 PARTLABEL=userdata 根行" >&2; exit 1; }
sudo test -x "${MNT}/usr/bin/systemctl" || { echo "ERROR: 非 Fedora 容器根？" >&2; exit 1; }
# ostree→sysroot/ostree 悬空软链 + /sysroot/ostree/repo 孤儿仓库（实测 2G，
# 无任何部署引用）：全清，防 ostree 工具链对空仓库做迷惑操作 + 省刷写
sudo rm -f "${MNT}/ostree"
sudo rm -rf "${MNT}/sysroot"
log "  布局 OK（container-export，fstab PARTLABEL=userdata + growfs，sysroot 孤儿仓库已清）"

# ---------------------------------------------------------------- 2) r80 内核腿
log "2) r80 内核腿（弃 ianchb 树）"
sudo find "${MNT}/usr/lib/modules" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
# pmOS apk = tar 包（可能 gzip 也可能裸 tar，-x 自动探测）；stderr 刷 checksum
# 告警属预期，绝不能接 head（SIGPIPE 静默截断定律）
sudo tar -xf "${APK}" -C "${MNT}/"
sudo find "${MNT}/usr/lib/modules" -mindepth 1 -maxdepth 1 -type d | sed 's/^/  modules: /'
KVER=$(ls "${MNT}/usr/lib/modules" | head -1)
[ "${KVER}" = "${KERNEL_RELEASE}" ] || { echo "ERROR: 模块树版本=${KVER}，期望 ${KERNEL_RELEASE}" >&2; exit 1; }

# 腿配对门禁（最强形式，nura 考据定律）：apk 解出的 boot/vmlinuz-efi 必须
# ≡ ESP 现役 BOOTAA64.EFI 逐字节（在录 sha8 = 12ee72b9）。EFI payload 压缩，
# strings 捞版本串不可靠——哈希对拍是唯一权威。
ESP_LINUX=$(sudo losetup -fP --show "${ESP_REF}"); ESP_LOOP="${ESP_LINUX}"
sudo mount -o ro "${ESP_LINUX}" "${ESP_MNT}"
ESP_EFI=""
for cand in EFI/BOOT/BOOTAA64.EFI BOOTAA64.EFI; do
    [ -f "${ESP_MNT}/${cand}" ] && { ESP_EFI="${ESP_MNT}/${cand}"; break; }
done
ESP_EFI_HASH=$([ -n "${ESP_EFI}" ] && sudo sha256sum "${ESP_EFI}" | cut -d' ' -f1 || true)
sudo umount "${ESP_MNT}"; ESP_LOOP=""
sudo losetup -d "${ESP_LINUX}"
APK_EFI_HASH=$(sudo sha256sum "${MNT}/boot/vmlinuz-efi" 2>/dev/null | cut -d' ' -f1 || true)
[ -n "${ESP_EFI_HASH}" ] || { echo "ERROR: ESP 读不出 BOOTAA64.EFI" >&2; exit 1; }
[ -n "${APK_EFI_HASH}" ] || { echo "ERROR: apk 无 boot/vmlinuz-efi" >&2; exit 1; }
if [ "${ESP_EFI_HASH}" != "${APK_EFI_HASH}" ]; then
    echo "ERROR: 腿配对失配 ESP=${ESP_EFI_HASH} apk=${APK_EFI_HASH}（ESP 腿换了？换配套 apk）" >&2
    exit 1
fi
echo "  腿配对 OK: BOOTAA64.EFI ≡ apk vmlinuz-efi (${APK_EFI_HASH:0:8})"

sudo depmod -b "${MNT}" "${KVER}"

# ---------------------------------------------------------------- 3) meizu 层注入
log "3) meizu 层注入（system_files/，睡眠 mask 件不在树中）"
# Debian 时代防睡死三件（sm20-nosleep / 两份 sleepmask tmpfiles）绝不在
# system_files 树中——它们 mask 掉 sleep/suspend.target 会废掉 fake-suspend
# （实机事故：电源键睡眠假死，docs/M2381-ARMADA-PORT-20261011.md §4.8）。
# 这里的 basename 排除是纵深防御，防上游/层侧将来污染。
sudo rsync -aHA --exclude='sm20-nosleep.conf' \
    --exclude='sm20-sleepmask.conf' --exclude='meizu-sleepmask.conf' \
    "${SF}/etc/" "${MNT}/etc/"
sudo rsync -aHA --exclude='modules' --exclude='firmware' \
    "${SF}/usr/" "${MNT}/usr/"
# 固件：底盘自带 Fedora linux-firmware（ath12k 等通用件）+ **无条件叠加** nura
# 固件 apk（meizu 专属：qcom/sm8550 a740_zap/ADSP/meizu 编排件——底盘不含；
# r84 首启实锤：「有 ath12k 就跳过」= zap/ADSP 全缺 → GPU init 重试风暴）。
# tar 覆盖语义，不删底盘件。回退 = work/layer（pmOS 时代 193M 树，本机便利）。
FAPK="$(ls -1t "${APK_DIR}"/firmware-meizu-meizu20-*.apk 2>/dev/null | head -1 || true)"
# 本地缺/失配且钉了 URL → 直接从 nura Release 拉（下载件 sha 门禁兜底）
if { [ -z "${FAPK}" ] || [ "$(sha256sum "${FAPK}" | cut -d' ' -f1)" != "${FIRMWARE_APK_SHA256}" ]; } \
   && [ -n "${FIRMWARE_APK_URL}" ]; then
    log "  固件 apk 本地缺/失配 → FIRMWARE_APK_URL 拉取"
    curl -fsSL --retry 3 -o "${APK_DIR}/firmware-meizu-meizu20-${FIRMWARE_APK_VERSION}.apk" \
        "${FIRMWARE_APK_URL}"
    FAPK="${APK_DIR}/firmware-meizu-meizu20-${FIRMWARE_APK_VERSION}.apk"
fi
if [ -n "${FAPK}" ] && [ "$(sha256sum "${FAPK}" | cut -d' ' -f1)" = "${FIRMWARE_APK_SHA256}" ]; then
    # ⚠ 本 rootfs /lib 是真目录（非 usr-merge 软链，r84 首建实锤）：apk 内
    # lib/firmware/ 路径若直接 -C ${MNT}/ 解包会落进平行 /lib/firmware 树，
    # /usr/lib/firmware 反而拿不到 meizu 件（内核靠兜底查找路径碰运气）。
    # 先解暂存再 rsync 进 /usr/lib/firmware，覆盖语义同源（不删底盘件）。
    FWSTAGE=$(mktemp -d /mnt/fwstage.XXXX)
    sudo tar -xzf "${FAPK}" -C "${FWSTAGE}"
    sudo rsync -aHA "${FWSTAGE}/lib/firmware/" "${MNT}/usr/lib/firmware/"
    sudo rm -rf "${FWSTAGE}"
    log "  固件叠加 nura apk（$(basename "${FAPK}")）→ /usr/lib/firmware：qcom/sm8550 zap/ADSP/meizu 件"
    # v4 热修实锤（2026-10-12）：apk 不带 MEIZU20-tplg.bin（音频拓扑）——内核
    # snd-sc8280xp probe 拿不到 tplg = card 永不出现 = audio-route 8 分钟重试后
    # failed。layer 回退树（r80 时代 proven 集）必叠，且最后叠 = meizu 专属件以
    # layer 为准。apk 缺失时走 elif 同款。
    if [ -d "${FW_FALLBACK}/qcom/sm8550" ]; then
        sudo rsync -aHA "${FW_FALLBACK}/" "${MNT}/usr/lib/firmware/"
        log "  固件再叠 layer 回退（$(du -sh "${FW_FALLBACK}" | cut -f1)，tplg/meizu 专属件补齐）"
    fi
elif [ -d "${FW_FALLBACK}/qcom/sm8550" ]; then
    sudo rsync -aHA "${FW_FALLBACK}/" "${MNT}/usr/lib/firmware/"
    log "  固件回退自 work/layer（$(du -sh "${FW_FALLBACK}" | cut -f1)）"
else
    echo "ERROR: 无固件可用——到 nura 线拿 firmware-meizu-meizu20 apk 放 ${APK_DIR}/（sha 见 kernel-m2381/BUILD.env）" >&2
    exit 1
fi

# ---------------------------------------------------------------- 4) enable 集 + 调试件
# 持久 journal（v4 热修实锤：boot#1 早期死亡无从取证——volatile journal 随断电
# 蒸发；journald Storage=auto 见目录即持久）。目录属 root 0755，tmpfiles 惯例。
sudo mkdir -p "${MNT}/var/log/journal"
sudo chmod 0755 "${MNT}/var/log/journal"
# 时区：默认不动（保持上游 UTC）。需要本地时区者构建时传 ROOT_TZ=Asia/Shanghai，
# 或刷后在系统里 timedatectl set-timezone <tz>——发布镜像不预设任何时区。
[ -n "${ROOT_TZ:-}" ] && sudo ln -sf "/usr/share/zoneinfo/${ROOT_TZ}" "${MNT}/etc/localtime" && log "  时区 → ${ROOT_TZ}"

log "4) enable：meizu 编排链 + 调试件（软链进 multi-user.target.wants，按落点选目标）"
for u in m2381-ncm-gadget m2381-usb0-ip gpu-idle-damp meizu-audio-wireplumber-kick \
         meizu-pas meizu-touch meizu-amps meizu-audio meizu-sndcard-bind \
         meizu-audio-route meizu-bind-nfc-haptics meizu-memsleep qbootctl-meizu; do
    TGT=""
    for base in /etc/systemd/system /usr/lib/systemd/system /lib/systemd/system; do
        [ -f "${MNT}${base}/${u}.service" ] && { TGT="${base}/${u}.service"; break; }
    done
    if [ -n "${TGT}" ]; then
        sudo ln -sfn "${TGT}" "${MNT}/etc/systemd/system/multi-user.target.wants/${u}.service"
        log "  + enable ${u}"
    else
        log "  WARN: unit 缺失 ${u}"
    fi
done
# RTC：r81+ 内核 HCTOSYS/SYSTOHC 已钉 rtc1（pm8xxx 走电正主），用户态持久化三件
# （sm20-rtc1-restore/save.timer/time-wait cap）自 r81 起撤出——勿再回加，r80 及
# 以前的老腿才需要（nura 2026-10-11 回信第三节）。
# sshd / sddm / inputplumber 上游已 enable，复核
for u in sshd sddm inputplumber; do
    if [ -e "${MNT}/etc/systemd/system/multi-user.target.wants/${u}.service" ] || \
       [ -e "${MNT}/etc/systemd/system/display-manager.service" ]; then
        log "  ✓ 上游已带 ${u}"
    else
        sudo ln -sfn "/usr/lib/systemd/system/${u}.service" \
            "${MNT}/etc/systemd/system/multi-user.target.wants/${u}.service"
        log "  + 补 enable ${u}"
    fi
done
# display-manager = sddm（graphical.target 走这里）
if [ ! -e "${MNT}/etc/systemd/system/display-manager.service" ]; then
    sudo ln -sfn /usr/lib/systemd/system/sddm.service "${MNT}/etc/systemd/system/display-manager.service"
fi
# ssh：host key（缺则宿主生成——host key 是 arch 无关数据件）+ root 密码 + pubkey
if ! ls "${MNT}"/etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
    sudo ssh-keygen -A -f "${MNT}"
    log "  ssh host key 已宿主生成"
fi
PW_HASH=$(openssl passwd -6 "${ROOT_PW}")
sudo sed -i "s|^root:[^:]*:|root:${PW_HASH//|/\\|}:|" "${MNT}/etc/shadow"
sudo install -d -m0700 "${MNT}/root/.ssh"
sudo install -m0600 "${PUBKEY}" "${MNT}/root/.ssh/authorized_keys"
echo meizu20 | sudo tee "${MNT}/etc/hostname" >/dev/null

# ---------------------------------------------------------------- 5) 手术
log "5) 手术：boot_b 重写件 / bootupd / RNDIS / sheng 专件 / Decky"
for u in armada-bootimg-sync armada-esp-rename armada-boot-hotkeys \
         armada-usbgadget xiaomi-sheng-thp armada-update-reserve bootloader-update \
         bootc-generic-growpart; do
    sudo rm -f "${MNT}/etc/systemd/system/multi-user.target.wants/${u}.service" 2>/dev/null || true
done
for u in armada-usbgadget ostree-remount ostree-finalize-staged \
         bootc-fetch-apply-updates.service bootc-fetch-apply-updates.timer; do
    sudo ln -sf /dev/null "${MNT}/etc/systemd/system/${u}.service" 2>/dev/null || true
    sudo ln -sf /dev/null "${MNT}/etc/systemd/system/${u}.timer" 2>/dev/null || true
done
# bootc-generic-growpart：static unit 被非 wants 路径拉起（10-armada-bare-metal
# drop-in），摘 wants 不够——真 mask（r84 首启 --failed=1 实锤；growfs 由 fstab
# x-systemd.growfs 负责）。
sudo ln -sf /dev/null "${MNT}/etc/systemd/system/bootc-generic-growpart.service"
# sddm 会话归位：底盘 zz-steamos-autologin 钉 armada-plasma（zz- 字母序压过
# armada.conf 的 gamescope 会话）→ 首启进 Plasma llvmpipe crash 黑屏（r84 首启
# 实锤）。删 zz 件 = gamescope-session-steam 接管（armada.conf 自带 Relogin）。
sudo rm -f "${MNT}/etc/sddm.conf.d/zz-steamos-autologin.conf"
# armada-controller-type：走 InputPlumber CompositeDevice D-Bus——m2381 无内置手柄
# ⇒ 开机必无 CompositeDevice，apply 必炸（首启实锤）。默认目标本来就是
# deck-uhid（defaults.conf 首位），接手柄后手动 `controller-type apply` 即可。
sudo ln -sf /dev/null "${MNT}/etc/systemd/system/armada-controller-type.service"
# plugin_loader（Decky）：首启 exit-code 连炸（首启实锤）；要插件时在设备上 unmask。
sudo ln -sf /dev/null "${MNT}/etc/systemd/system/plugin_loader.service"
sudo rm -f "${MNT}/etc/systemd/system/multi-user.target.wants/plugin_loader.service" 2>/dev/null || true

# os-release 归位：52-configure-os-release 的产物在容器导出路径上丢了（实测
# /usr/lib/os-release 还是 Fedora 44 内容）。按上游脚本同款格式重写。
ARMADA_VER=$(sudo cat "${MNT}/usr/lib/armada/version" 2>/dev/null || echo unknown)
if command -v setfattr >/dev/null; then
    sudo tee "${MNT}/usr/lib/os-release" >/dev/null <<EOF
NAME="Armada"
VERSION="${ARMADA_VER}"
ID=armada
ID_LIKE="fedora"
VERSION_ID="44"
BUILD_ID="${ARMADA_VER}"
PRETTY_NAME="Armada ${ARMADA_VER}"
DEFAULT_HOSTNAME=armada
IMAGE_ID=armada
IMAGE_VERSION="${ARMADA_VER}"
HOME_URL="https://armadaos.dev/"
DOCUMENTATION_URL="https://armadaos.dev/"
SUPPORT_URL="https://armadaos.dev/troubleshooting/frequently-asked-questions/"
BUG_REPORT_URL="https://github.com/armada-os/armada/issues"
EOF
    log "  os-release → Armada ${ARMADA_VER}（/etc 软链同源）"
fi

# FEX x86 腿：上游两个 zstd sqsh **保持原样直挂**——r81 内核已带
# CONFIG_SQUASHFS_ZSTD/XZ=y（2026-10-11 点火 PASS：#82 实机 loop 挂 zstd 原件成功）。
# 旧 r80 及以前腿无 zstd 支持，需要 gzip 重压——那种组合已废弃，勿回退。
# 唯一要守护的是 Mesa 件本体的 user.component=fex-mesa xattr（FEX 分类组件用）。
FEX_ROOT="${MNT}/usr/share/fex-emu/RootFS"
if command -v setfattr >/dev/null; then
    sudo setfattr -n user.component -v fex-mesa "${FEX_ROOT}/ArmadaMesa.sqsh" 2>/dev/null \
        && log "  FEX Mesa user.component xattr 已复打" || log "  WARN: Mesa xattr 复打失败"
else
    log "  WARN: 宿主无 setfattr，FEX Mesa xattr 未复核"
fi
for name in ArchLinux ArmadaMesa; do
    [ -f "${FEX_ROOT}/${name}.sqsh" ] && log "  FEX ${name}.sqsh 保持 zstd 原件（r81 直挂）"
done

# ---------------------------------------------------------------- 6) fstab 复核
log "6) fstab 复核"
sudo cat "${MNT}/etc/fstab"
sudo grep -q "x-systemd.growfs" "${MNT}/etc/fstab" || { echo "ERROR: fstab 无 growfs" >&2; exit 1; }

# ---------------------------------------------------------------- 7) 卸载 + 收缩 + 点验
log "7) 卸载"
sync
sudo umount "${MNT}"
sudo losetup -d "${LOOP}"; LOOP=""

"${REPO}/post_process/finalize-m2381-image.sh" "${OUT_IMG}.tmp"
sudo mv "${OUT_IMG}.tmp" "${OUT_IMG}"
"${REPO}/post_process/verify-m2381-image.sh" "${OUT_IMG}" || {
    echo "FATAL: 复核有败项，产物保留为 ${OUT_IMG}.reject" >&2
    sudo mv "${OUT_IMG}" "${OUT_IMG}.reject"
    exit 1
}

( cd "$(dirname "${OUT_IMG}")" && sha256sum "$(basename "${OUT_IMG}")" > "$(basename "${OUT_IMG}").sha256" )
{
    echo "meizu-meizu20 armada-sheng 镜像（上游 v1.2 sheng-flashable + ${KERNEL_APK_VERSION} 腿 + meizu 层）"
    echo "built: $(date -u '+%Y-%m-%d %H:%M:%SZ')"
    echo "base:  code002-2/armada-sheng sheng-flashable (2026-09-05)"
    echo "kernel: ${KERNEL_APK_VERSION} (${KERNEL_RELEASE}, apk sha8 ${KERNEL_APK_SHA256:0:8}, ESP 配对 ${ESP_PAIR_SHA8})"
    echo "boot:  recovery_a ESP 配对腿 ${ESP_PAIR_SHA8}（镜像不内嵌，盘只进 userdata /dev/sda22）"
    echo "debug: NCM 172.16.42.1 + sshd(root/${ROOT_PW}) + autologin armada(armada)"
    echo "sleep: fake-suspend（ARMADA_SUSPEND_MODE=fake）"
} > "${OUT_IMG}.MANIFEST.txt"
cat "${OUT_IMG}.MANIFEST.txt"
ls -lh "${OUT_IMG}" "${OUT_IMG}.sha256"
log "DONE: ${OUT_IMG}"
