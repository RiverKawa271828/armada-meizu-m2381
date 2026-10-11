#!/bin/bash
# 点验：挂载成品镜像跑 21 项检查（任一败项退出非零）。参数 = 成品镜像路径。
set -uo pipefail
IMG="${1:?usage: verify-m2381-image.sh <img>}"
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
chk "r80 模块树"            "test -d ${MNT}/usr/lib/modules/7.3.0-rc6/kernel && ls ${MNT}/usr/lib/modules/7.3.0-rc6/modules.dep"
chk "ianchb 旧树已清"       "! ls -d ${MNT}/usr/lib/modules/* 2>/dev/null | grep -v '7.3.0-rc6' | grep -q ."
chk "modules-load uinput"   "grep -qh uinput ${MNT}/usr/lib/modules-load.d/*.conf ${MNT}/etc/modules-load.d/*.conf 2>/dev/null"
chk "modules-load uhid"     "grep -qh uhid ${MNT}/etc/modules-load.d/*.conf ${MNT}/usr/lib/modules-load.d/*.conf 2>/dev/null"
chk "PAS/geni 黑名单"       "grep -q qcom_q6v5_pas ${MNT}/etc/modprobe.d/50-meizu20-blacklist.conf"
chk "NCM gadget 件"         "test -x ${MNT}/usr/lib/steamos/m2381-ncm-gadget && test -f ${MNT}/etc/systemd/system/m2381-ncm-gadget.service"
chk "usb0-ip 172.16.42.1"   "grep -q 172.16.42.1 ${MNT}/etc/systemd/system/m2381-usb0-ip.service"
chk "root authorized_keys"  "test -s ${MNT}/root/.ssh/authorized_keys"
chk "armada 用户在位"       "grep -q '^armada:' ${MNT}/etc/passwd"
chk "fake-suspend 单元"     "test -f ${MNT}/usr/libexec/armada/fake-suspend && test -f ${MNT}/usr/lib/systemd/system/systemd-suspend.service.d/10-armada-suspend.conf"
chk "SUSPEND_MODE=fake"     "grep -q 'ARMADA_SUSPEND_MODE=fake' ${MNT}/usr/lib/armada/devices/meizu-meizu20.conf"
chk "固件 ath12k"           "test -d ${MNT}/usr/lib/firmware/ath12k"
chk "UCM2 MEIZU20"          "test -f ${MNT}/usr/share/alsa/ucm2/Qualcomm/sm8550/MEIZU20.conf"
chk "inputplumber 在位"     "test -f ${MNT}/usr/lib/systemd/system/inputplumber.service"
chk "gamescope-session"     "test -f ${MNT}/usr/share/wayland-sessions/gamescope-session-steam.desktop || test -f ${MNT}/usr/share/wayland-sessions/gamescope-wayland.desktop"
chk "SDDM autologin armada" "grep -q 'User=armada' ${MNT}/etc/sddm.conf.d/armada.conf"
chk "bootimg 重写件已摘"    "! test -e ${MNT}/etc/systemd/system/multi-user.target.wants/armada-bootimg-sync.service"
chk "SELinux permissive"    "grep -q '^SELINUX=permissive' ${MNT}/etc/selinux/config 2>/dev/null"
chk "睡眠 mask 件未混入"    "! test -e ${MNT}/etc/systemd/system/sleep.target && ! test -e ${MNT}/usr/lib/tmpfiles.d/meizu-sleepmask.conf"

# steam 客户端落点以上游包布局为准（缺位只记警告，不算败项）
if sudo bash -c "test -d ${MNT}/usr/lib/steam/arm-client || test -d ${MNT}/var/home/armada/.steam || test -d ${MNT}/opt/steam"; then
    echo "  ✓ steam 客户端预种"
else
    echo "  WARN: steam 客户端预种落点未识别（首启由 steam-bootstrap 自拉，不拦盘）"
fi
sudo umount "${MNT}"
[ "${FAIL}" -eq 0 ] && echo "VERIFY: 21/21 全绿" || echo "VERIFY: 有败项"
exit "${FAIL}"
