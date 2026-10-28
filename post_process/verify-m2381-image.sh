#!/bin/bash
# 点验：挂载成品镜像跑全项检查（任一败项退出非零）。参数 = 成品镜像路径。
set -uo pipefail
IMG="${1:?usage: verify-m2381-image.sh <img>}"
# 模块树版本吃 BUILD.env 钉子（r91 起内核 release=7.3.0，模块目录随钉子走）
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
[ -f "${REPO}/kernel-m2381/BUILD.env" ] && source "${REPO}/kernel-m2381/BUILD.env"
KREL="${KERNEL_RELEASE:-7.3.0}"
MNT=$(mktemp -d /mnt/armada-verify.XXXX)
LOOP=""
cleanup() { sudo umount "${MNT}" 2>/dev/null || true; [ -n "${LOOP}" ] && sudo losetup -d "${LOOP}" 2>/dev/null || true; rm -rf "${MNT}"; }
trap cleanup EXIT

LOOP=$(sudo losetup -fP --show "${IMG}")
sudo mount "${LOOP}" "${MNT}"
FAIL=0
chk() { if sudo bash -c "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; FAIL=1; fi; }

chk "设备档案在位"          "test -f ${MNT}/usr/lib/armada/devices/meizu-meizu20.conf"
chk "device-env 匹配行"     "grep -q 'meizu-meizu20' ${MNT}/usr/libexec/armada/device-env"
chk "模块树（${KREL}）"      "d=\$(ls -d ${MNT}/usr/lib/modules/${KREL}* 2>/dev/null | head -1); test -d \${d}/kernel && ls \${d}/modules.dep"
chk "ianchb 旧树已清"       "! ls ${MNT}/usr/lib/modules/ 2>/dev/null | grep -vx \"${KREL}\" | grep -q ."
chk "modules-load uinput"   "grep -qh uinput ${MNT}/usr/lib/modules-load.d/*.conf ${MNT}/etc/modules-load.d/*.conf 2>/dev/null"
chk "modules-load uhid"     "grep -qh uhid ${MNT}/etc/modules-load.d/*.conf ${MNT}/usr/lib/modules-load.d/*.conf 2>/dev/null"
chk "PAS/geni 黑名单"       "grep -q qcom_q6v5_pas ${MNT}/etc/modprobe.d/50-meizu20-blacklist.conf"
chk "NCM gadget 件"         "test -x ${MNT}/usr/lib/steamos/m2381-ncm-gadget && test -f ${MNT}/etc/systemd/system/m2381-ncm-gadget.service"
chk "usb0-ip 172.16.42.1"   "grep -q 172.16.42.1 ${MNT}/etc/systemd/system/m2381-usb0-ip.service"
chk "root authorized_keys（可选：未注入=发布口径，注入时必非空）" "test -s ${MNT}/root/.ssh/authorized_keys || [ ! -d ${MNT}/root/.ssh ]"
chk "sshd root 密码放行 drop-in（r84 首发密码 SSH 必拒 bug 修复）" "grep -q '^PermitRootLogin yes' ${MNT}/etc/ssh/sshd_config.d/30-m2381-root-pw.conf && grep -q '^PasswordAuthentication yes' ${MNT}/etc/ssh/sshd_config.d/30-m2381-root-pw.conf"
chk "armada 用户在位"       "grep -q '^armada:' ${MNT}/etc/passwd"
chk "fake-suspend 单元"     "test -f ${MNT}/usr/libexec/armada/fake-suspend && test -f ${MNT}/usr/lib/systemd/system/systemd-suspend.service.d/10-armada-suspend.conf"
chk "SUSPEND_MODE=fake"     "grep -q 'ARMADA_SUSPEND_MODE=fake' ${MNT}/usr/lib/armada/devices/meizu-meizu20.conf"
chk "固件 ath12k"           "test -d ${MNT}/usr/lib/firmware/ath12k"
chk "固件 meizu ADSP（apk 落位）" "test -f ${MNT}/usr/lib/firmware/qcom/sm8550/meizu/adsp.b00"
chk "固件 a740_zap 裸名（apk 件）" "test -f ${MNT}/usr/lib/firmware/qcom/sm8550/a740_zap.mbn"
chk "固件 MEIZU20-tplg（layer 叠加，音频拓扑）" "test -f ${MNT}/usr/lib/firmware/qcom/sm8550/MEIZU20-tplg.bin"
chk "持久 journal 目录（v4 取证教训）" "test -d ${MNT}/var/log/journal"
chk "/lib 保持 usr-merge 软链" "[ -L ${MNT}/lib ]"
chk "UCM2 MEIZU20"          "test -f ${MNT}/usr/share/alsa/ucm2/Qualcomm/sm8550/MEIZU20.conf"
chk "inputplumber 在位"     "test -f ${MNT}/usr/lib/systemd/system/inputplumber.service"
chk "gamescope-session"     "test -f ${MNT}/usr/share/wayland-sessions/gamescope-session-steam.desktop || test -f ${MNT}/usr/share/wayland-sessions/gamescope-wayland.desktop"
chk "SDDM autologin armada" "grep -q 'User=armada' ${MNT}/etc/sddm.conf.d/armada.conf"
chk "bootimg 重写件已摘"    "! test -e ${MNT}/etc/systemd/system/multi-user.target.wants/armada-bootimg-sync.service"
chk "zz-autologin 已删"     "! test -e ${MNT}/etc/sddm.conf.d/zz-steamos-autologin.conf"
chk "growpart 真 mask"      "[ \"\$(readlink ${MNT}/etc/systemd/system/bootc-generic-growpart.service)\" = \"/dev/null\" ]"
chk "SELinux permissive"    "grep -q '^SELINUX=permissive' ${MNT}/etc/selinux/config 2>/dev/null"
chk "睡眠 mask 件未混入"    "! test -e ${MNT}/etc/systemd/system/sleep.target && ! test -e ${MNT}/usr/lib/tmpfiles.d/meizu-sleepmask.conf"
chk "qbootctl 件在位"       "test -x ${MNT}/usr/local/bin/qbootctl && test -f ${MNT}/etc/systemd/system/qbootctl-meizu.service && test -L ${MNT}/etc/systemd/system/multi-user.target.wants/qbootctl-meizu.service"
chk "gpu-idle-damp 件在位"  "test -x ${MNT}/usr/lib/meizu20/gpu-idle-damp && test -f ${MNT}/etc/systemd/system/gpu-idle-damp.service && test -L ${MNT}/etc/systemd/system/multi-user.target.wants/gpu-idle-damp.service"
chk "RTC 用户态三件已撤"    "! test -e ${MNT}/etc/systemd/system/sm20-rtc1-restore.service && ! test -e ${MNT}/etc/systemd/system/sm20-rtc1-save.timer"
# squashfs 超级块偏移 20 = 压缩算法 id（6=zstd）；r81+ 内核直挂，不许再回 gzip
chk "FEX sqsh 保持 zstd"    "[ \"\$(sudo od -A n -t u2 -j 20 -N 2 ${MNT}/usr/share/fex-emu/RootFS/ArchLinux.sqsh | tr -d ' ')\" = \"6\" ]"

# steam 客户端落点以上游包布局为准（缺位只记警告，不算败项）
if sudo bash -c "test -d ${MNT}/usr/lib/steam/arm-client || test -d ${MNT}/var/home/armada/.steam || test -d ${MNT}/opt/steam"; then
    echo "  ✓ steam 客户端预种"
else
    echo "  WARN: steam 客户端预种落点未识别（首启由 steam-bootstrap 自拉，不拦盘）"
fi
sudo umount "${MNT}"
[ "${FAIL}" -eq 0 ] && echo "VERIFY: 全绿" || echo "VERIFY: 有败项"
exit "${FAIL}"
