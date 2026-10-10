#!/bin/bash
# =============================================================================
# armada-sheng v1.2 → m2381 (Meizu 20) 适配器（宿主 root 跑，模式对齐 01-lay/graft）
#
# 输入（相对仓根）:
#   work/armada-m2381/dl/rootfs.img                              上游 v1.2 合并原盘（裸 ext4 单分区，/boot 已并入）
#   work/armada-m2381/apk/linux-meizu-meizu20-7.3.0_rc6-r80.apk  nura r80 内核腿（uname #81，ESP v61 配对腿）
#   work/layer/                                                  meizu 层（固件/音频编排/触屏/UCM/看门狗放宽）
#   work/cache/esp-recovery-v61.img                              现役 boot 腿（vermagic 对拍基准，只读）
# 输出:
#   work/meizu-meizu20-armada-r80.img (+ .sha256 / .MANIFEST.txt)
#
# 动作:
#   A. 容器根验收：v1.2 = container-export（无 ostree 部署层，/boot 空，
#      fstab 已是 PARTLABEL=userdata + growfs）——只验收 + 清 ostree 残迹
#      （boot 链 = m2381 现役 recovery_a ESP v61 EFI stub root=/dev/sda22）
#   B. 内核腿：弃 ianchb 7.2.2 模块树，解 r80 apk（vermagic 守门 + depmod）
#   C. meizu 层注入（睡眠 mask 件除外——fake-suspend 需要 CanSuspend=yes）
#   D. 设备档案 meizu-meizu20.conf + device-env 匹配行（"Meizu 20 (m2381)"）
#   E. 调试件：NCM gadget(18d1:4ee1)+usb0-ip 172.16.42.1 + ssh key/密码 + GPU 看护
#   F. 手术：boot_b 重写件/bootupd/RNDIS/sheng THP 全关（见手术清单）
#   G. 收缩出盘（resize2fs -M + 4096 对齐），首启 x-systemd.growfs 自长满
# =============================================================================
set -euxo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_IMG="${REPO}/work/armada-m2381/dl/rootfs.img"
APK="${REPO}/work/armada-m2381/apk/linux-meizu-meizu20-7.3.0_rc6-r80.apk"
LAYER="${REPO}/work/layer"
ESP_REF="${REPO}/work/cache/esp-recovery-v61.img"
OUT_IMG="${REPO}/work/meizu-meizu20-armada-r80.img"
ROOT_PW="${ROOT_PW:-123456}"
PUBKEY="${PUBKEY:-/home/ri/ubuntu/.ssh/id_ed25519.pub}"

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
for f in "${SRC_IMG}" "${APK}" "${LAYER}/etc" "${LAYER}/usr" "${ESP_REF}"; do
    [ -e "$f" ] || { echo "ERROR: 缺料 $f" >&2; exit 1; }
done
for t in losetup blkid rsync depmod modinfo openssl ssh-keygen e2fsck resize2fs dumpe2fs; do
    command -v "$t" >/dev/null || { echo "ERROR: 宿主缺 $t" >&2; exit 1; }
done
for t in unsquashfs mksquashfs setfattr; do
    command -v "$t" >/dev/null || { echo "WARN: 宿主缺 $t（FEX 重压/os-release 步骤将跳）" >&2; }
done
[ -f "${PUBKEY}" ] || { echo "ERROR: 缺 ${PUBKEY}" >&2; exit 1; }

log "0) 铺工作盘（保留上游原盘不动）"
cp --sparse=always "${SRC_IMG}" "${OUT_IMG}.tmp"
LOOP=$(sudo losetup -fP --show "${OUT_IMG}.tmp")
sleep 1
sudo blkid "${LOOP}" | grep -q 'TYPE="ext4"' || { echo "ERROR: 上盘不是裸 ext4（分区布局变了？）" >&2; exit 1; }
sudo mount "${LOOP}" "${MNT}"

# ---------------------------------------------------------------- 1) 容器根验收
# v1.2 release = container-exported（MANIFEST 自述，无 ostree 部署层）：
# usrmerge 软链 + /var 真目录 + /boot 空 + fstab 已写 PARTLABEL=userdata+growfs。
# 这里只验收布局 + 清 ostree 残迹，不做任何摊平。
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
[ "${KVER}" = "7.3.0-rc6" ] || { echo "ERROR: 模块树版本=${KVER}，期望 7.3.0-rc6" >&2; exit 1; }
# 腿配对门禁（最强形式，nura 考据定律）：apk 解出的 boot/vmlinuz-efi 必须
# ≡ ESP v61 的 BOOTAA64.EFI 逐字节（在录 sha8 = 12ee72b9）。EFI payload 压缩，
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
[ -n "${ESP_EFI_HASH}" ] || { echo "ERROR: ESP v61 读不出 BOOTAA64.EFI" >&2; exit 1; }
[ -n "${APK_EFI_HASH}" ] || { echo "ERROR: r80 apk 无 boot/vmlinuz-efi" >&2; exit 1; }
if [ "${ESP_EFI_HASH}" != "${APK_EFI_HASH}" ]; then
    echo "ERROR: 腿配对失配 ESP=${ESP_EFI_HASH} apk=${APK_EFI_HASH}（ESP 腿换了？换配套 apk）" >&2
    exit 1
fi
echo "  腿配对 OK: BOOTAA64.EFI ≡ apk vmlinuz-efi (${APK_EFI_HASH:0:8})"

sudo depmod -b "${MNT}" "${KVER}"

# ---------------------------------------------------------------- 3) meizu 层注入
log "3) meizu 层注入（睡眠 mask 件除外）"
# 硬定律随层走：PAS/geni 黑名单 + 编排三件 + 触屏 + UCM + 看门狗放宽。
# 排除件 = sm20-nosleep.conf（AllowSuspend=no 会砍掉 fake-suspend 的 logind 入口）
#          + 两份 sleepmask tmpfiles + 层内旧模块树（apk 现解的为准）。
sudo rsync -aHA --exclude='systemd/sleep.conf.d/sm20-nosleep.conf' \
    --exclude='tmpfiles.d/sm20-sleepmask.conf' --exclude='tmpfiles.d/meizu-sleepmask.conf' \
    "${LAYER}/etc/" "${MNT}/etc/"
sudo rsync -aHA --exclude='modules' \
    "${LAYER}/usr/" "${MNT}/usr/"

# ---------------------------------------------------------------- 4) 设备档案 + device-env
log "4) 设备档案 meizu-meizu20 + device-env 匹配行"
sudo install -Dm0644 /dev/null "${MNT}/usr/lib/armada/devices/meizu-meizu20.conf"
sudo tee "${MNT}/usr/lib/armada/devices/meizu-meizu20.conf" >/dev/null <<'EOF'
ARMADA_DEVICE_ID=meizu-meizu20
ARMADA_DEVICE_NAME='Meizu 20'
ARMADA_SOC_CLASS=SM8550

# 6.55" 竖屏面板（2400x1080），gamescope 自动 ORIENTATION_270 →
# 旋转走合成兜底（msm plane 只支持 rotate-0/180，与 Debian 线同款 workaround）
ARMADA_PANEL_TYPE=internal
ARMADA_PANEL_ORIENTATION=right
ARMADA_GAMESCOPE_USE_ROTATION_SHADER=1

# 真睡眠 s2idle 入睡后闹钟到点不能 resume（rtc-efi EIO 废件，~2-3min 冷复位，
# 与上游 "Real suspend hangs this SoC" 互证）→ fake suspend
ARMADA_SUSPEND_MODE=fake

ARMADA_GAMEPAD_QUIRK=none
ARMADA_HDR_NITS=0

ARMADA_PRIMARY_CONNECTOR=DSI-1
ARMADA_PRIMARY_BACKLIGHT=ae94000.dsi.0

# m2381 不走 ABL boot.img 链：boot = 现役 recovery_a ESP（EFI stub，cmdline 烤死
# root=/dev/sda22）。bootimg 重写件在适配层统一禁用，这里把路径置空兜底。
ARMADA_BOOTIMG_OUT=
ARMADA_DTB_LIST=
ARMADA_BOOTIMG_ARGS_FILE=
EOF

sudo python3 - "${MNT}/usr/libexec/armada/device-env" <<'PYEOF'
import sys
p = sys.argv[1]
src = open(p).read()
line = '    "Meizu 20 (m2381)") profile=meizu-meizu20 ;;\n'
if 'meizu-meizu20' not in src:
    anchor = '    *) profile= ;;'
    assert anchor in src, 'device-env case 表锚点变了，人工接'
    src = src.replace(anchor, line + anchor, 1)
    open(p, 'w').write(src)
    print('  device-env: meizu-meizu20 case 已插')
else:
    print('  device-env: 已有 meizu-meizu20，跳过')
PYEOF

# InputPlumber deck-uhid 的前置：/dev/uhid 开机自载（r80 = CONFIG_UHID=m，
# misc 无 open-time autoload；BLE HID 回归实锤 bluetoothd 缺 uhid 拒收）
sudo tee "${MNT}/etc/modules-load.d/meizu20-uhid.conf" >/dev/null <<'EOF'
# Meizu 20 (r80 CONFIG_UHID=m): InputPlumber deck-uhid / BLE HOG 前置
uhid
EOF

# InputPlumber 设备档案（通用模式接管 BT 手柄即可；m2381 内置手柄无）
# 预留：若后续要给 m2381 内置 HID 配 capability map，加 /usr/share/inputplumber/devices/meizu-meizu20.yaml

# ---------------------------------------------------------------- 5) 调试件
log "5) 调试件：NCM gadget + usb0-ip + ssh + root 密码 + GPU 看护"
sudo install -d -m0755 "${MNT}/usr/lib/steamos" "${MNT}/etc/systemd/system" "${MNT}/etc/NetworkManager/conf.d"

# NCM gadget（graft 原方，VID 18d1:4ee1；替换上游 RNDIS）
sudo tee "${MNT}/usr/lib/steamos/m2381-ncm-gadget" >/dev/null <<'EOF'
#!/bin/bash
set -u
CFG=/sys/kernel/config/usb_gadget/m2381
UDC="$(ls /sys/class/udc 2>/dev/null | head -1)"
[[ -n "$UDC" ]] || exit 0
if [[ -d "$CFG" ]]; then
  [[ "$(cat "$CFG/UDC" 2>/dev/null)" == "$UDC" ]] && exit 0
else
  modprobe libcomposite 2>/dev/null || true
  mkdir -p "$CFG" 2>/dev/null || exit 0
  echo 0x18d1 > "$CFG/idVendor" 2>/dev/null || exit 0
  echo 0x4ee1 > "$CFG/idProduct" 2>/dev/null
  echo 0x0100 > "$CFG/bcdDevice" 2>/dev/null
  mkdir -p "$CFG/strings/0x409" "$CFG/configs/c.1"
  echo "m2381 NCM gadget" > "$CFG/strings/0x409/product" 2>/dev/null
  mkdir -p "$CFG/functions/ncm.usb0"
  ln -sf "$CFG/functions/ncm.usb0" "$CFG/configs/c.1/fncm" || exit 0
fi
echo "$UDC" > "$CFG/UDC" 2>/dev/null || exit 0
ip link set usb0 up 2>/dev/null || true
exit 0
EOF
sudo chmod 0755 "${MNT}/usr/lib/steamos/m2381-ncm-gadget"
sudo tee "${MNT}/etc/systemd/system/m2381-ncm-gadget.service" >/dev/null <<'EOF'
[Unit]
Description=m2381: USB NCM gadget 调试通道（172.16.42.1）
After=systemd-modules-load.service sys-kernel-config.mount
Wants=sys-kernel-config.mount
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/lib/steamos/m2381-ncm-gadget
[Install]
WantedBy=multi-user.target
EOF

sudo tee "${MNT}/etc/NetworkManager/conf.d/89-m2381-usb0.conf" >/dev/null <<'EOF'
[keyfile]
unmanaged-devices=interface-name:usb0
EOF

sudo tee "${MNT}/etc/systemd/system/m2381-usb0-ip.service" >/dev/null <<'EOF'
[Unit]
Description=m2381: usb0 gadget 静态 IP（纯调试通道，上行走设备自身 WiFi）
After=m2381-ncm-gadget.service
Wants=m2381-ncm-gadget.service
[Service]
Type=oneshot
ExecStart=/bin/sh -c "ip a a 172.16.42.1/24 dev usb0 2>/dev/null; ip link set usb0 up; ip route del default via 172.16.42.2 dev usb0 2>/dev/null || true"
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF

# GPU devfreq 看护（simple_ondemand 重载冲击卡死定律；根治=pmOS devfreq 补丁）
sudo tee "${MNT}/usr/lib/meizu20/gpu-ondemand-watch" >/dev/null <<'EOF'
#!/bin/bash
D=/sys/class/devfreq/3d00000.gpu
last_trans=""
stuck=0
while true; do
  cur=$(cat $D/cur_freq 2>/dev/null)
  min=$(cat $D/min_freq 2>/dev/null)
  trans=$(awk "/^Total transition/{print \$3}" $D/trans_stat 2>/dev/null)
  if [ "$cur" = "$min" ] && [ -n "$trans" ] && [ "$trans" = "$last_trans" ]; then
    stuck=$((stuck+1))
  else
    stuck=0
  fi
  last_trans=$trans
  if [ "$stuck" -ge 6 ]; then
    echo simple_ondemand > $D/governor 2>/dev/null
    stuck=0
  fi
  sleep 5
done
EOF
sudo chmod 0755 "${MNT}/usr/lib/meizu20/gpu-ondemand-watch"
sudo tee "${MNT}/etc/systemd/system/gpu-ondemand-watch.service" >/dev/null <<'EOF'
[Unit]
Description=Watch devfreq simple_ondemand blindness and re-kick governor (m2381)
After=multi-user.target
[Service]
ExecStart=/usr/lib/meizu20/gpu-ondemand-watch
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# wireplumber 踢卡（首启实锤：ADSP 声卡 boot+75s 才到，wireplumber 起早了只报
# Dummy Output，重启 pipewire/wireplumber 即见 Built-in Audio Stereo）
sudo tee "${MNT}/etc/systemd/system/meizu-audio-wireplumber-kick.service" >/dev/null <<'EOF'
[Unit]
Description=Meizu 20: kick wireplumber after late ADSP card (boot+75s)
After=meizu-audio-route.service
Wants=meizu-audio-route.service
[Service]
Type=oneshot
ExecStart=/bin/sh -c "sleep 5; runuser -u armada -- env XDG_RUNTIME_DIR=/run/user/1000 systemctl --user try-restart pipewire wireplumber"
[Install]
WantedBy=multi-user.target
EOF

# ssh：host key（缺则宿主生成——host key 是 arch 无关数据件）+ root 密码 + pubkey
if ! ls "${MNT}"/etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
    sudo ssh-keygen -A -f "${MNT}"
    log "  ssh host key 已宿主生成"
fi
PW_HASH=$(openssl passwd -6 "${ROOT_PW}")
sudo sed -i "s|^root:[^:]*:|root:${PW_HASH//|/\\|}:|" "${MNT}/etc/shadow"
sudo install -d -m0700 "${MNT}/root/.ssh"
sudo install -m0600 "${PUBKEY}" "${MNT}/root/.ssh/authorized_keys"

# hostname 对齐本线惯例
echo meizu20 | sudo tee "${MNT}/etc/hostname" >/dev/null

# ---------------------------------------------------------------- 6) 手术：boot 链残余/sheng 专件
log "6) 手术：boot_b 重写件 / bootupd / sheng 专件（按实测 wants 摘链 + mask）"
# disable：实测 multi-user.target.wants 在役的 = bootimg-sync / usbgadget(RNDIS) /
# sheng-thp / update-reserve；esp-rename/boot-hotkeys 该容器导出盘无（rm -f 兜底）。
# bootloader-update = bootupd —— m2381 ESP 权威在我方 recovery_a，绝不许它碰。
for u in armada-bootimg-sync armada-esp-rename armada-boot-hotkeys \
         armada-usbgadget xiaomi-sheng-thp armada-update-reserve bootloader-update; do
    sudo rm -f "${MNT}/etc/systemd/system/multi-user.target.wants/${u}.service" 2>/dev/null || true
done
# mask（防路径拉起：上游 RNDIS + sheng THP + 残余 ostree/bootc 件）
for u in armada-usbgadget ostree-remount ostree-finalize-staged \
         bootc-fetch-apply-updates.service bootc-fetch-apply-updates.timer; do
    sudo ln -sf /dev/null "${MNT}/etc/systemd/system/${u}.service" 2>/dev/null || true
    sudo ln -sf /dev/null "${MNT}/etc/systemd/system/${u}.timer" 2>/dev/null || true
done
# armada-controller-type：走 InputPlumber CompositeDevice D-Bus——m2381 无内置手柄
# ⇒ 开机必无 CompositeDevice，apply 必炸（首启实锤）。默认目标本来就是
# deck-uhid（defaults.conf 首位），接手柄后手动 `controller-type apply` 即可。
sudo ln -sf /dev/null "${MNT}/etc/systemd/system/armada-controller-type.service"
# plugin_loader（Decky）：首启 exit-code 连炸（首启实锤），m2381 不预装插件；要
# 插件时在设备上 unmask + 装配。
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

# FEX x86 腿压缩改型：r80 内核 CONFIG_SQUASHFS_ZSTD 未开（只有 zlib），上游两个
# zstd sqsh 内核挂载必败（首启实锤）。宿主侧解包 → gzip 重压 → 原位替换。
# Mesa 件本体 user.component=fex-mesa xattr 必须保留（FEX 用它分类组件）。
FEX_ROOT="${MNT}/usr/share/fex-emu/RootFS"
if command -v unsquashfs >/dev/null && command -v mksquashfs >/dev/null; then
    WORKFEX=$(mktemp -d /mnt/armada-fex.XXXX)
    for name in ArchLinux ArmadaMesa; do
        src="${FEX_ROOT}/${name}.sqsh"
        [ -f "${src}" ] || { log "  WARN: 缺 ${src}，FEX 跳过"; continue; }
        sudo unsquashfs -d "${WORKFEX}/${name}" -no-progress "${src}" >/dev/null
        sudo mksquashfs "${WORKFEX}/${name}" "${WORKFEX}/${name}.gzip.sqsh" \
            -comp gzip -noappend -all-root -no-progress >/dev/null
        sudo mv "${src}" "${src}.zstd.bak"
        sudo mv "${WORKFEX}/${name}.gzip.sqsh" "${src}"
        sudo rm -rf "${WORKFEX}/${name}"
        log "  FEX ${name}.sqsh → gzip（zstd 原件留 .zstd.bak）"
    done
    # Mesa 件 xattr 打在 sqsh 文件本体（40-vendor 同源操作）
    sudo setfattr -n user.component -v fex-mesa "${FEX_ROOT}/ArmadaMesa.sqsh" 2>/dev/null \
        && log "  FEX Mesa user.component xattr 已复打" || log "  WARN: Mesa xattr 复打失败"
    sudo rm -rf "${WORKFEX}"
else
    log "  WARN: 宿主无 squashfs-tools，FEX sqsh 保持 zstd（x86 游戏腿在 r80 内核上不可用）"
fi
# ModemManager：m2381 主线无可用 modem；黑名单已封 PAS，MM 本体直接关死
sudo rm -f "${MNT}/etc/systemd/system/dbus-org.freedesktop.ModemManager1.service" 2>/dev/null || true
sudo rm -f "${MNT}/etc/systemd/system/multi-user.target.wants/ModemManager.service" 2>/dev/null || true

# enable 集：meizu 编排链 + 调试件（软链进 multi-user.target.wants，目标按实际落点选）
for u in m2381-ncm-gadget m2381-usb0-ip gpu-ondemand-watch meizu-audio-wireplumber-kick \
         meizu-pas meizu-touch meizu-amps meizu-audio meizu-sndcard-bind \
         meizu-audio-route meizu-bind-nfc-haptics meizu-memsleep; do
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

# ---------------------------------------------------------------- 7) fstab/首启 复核
log "7) fstab 复核"
sudo cat "${MNT}/etc/fstab"
sudo grep -q "x-systemd.growfs" "${MNT}/etc/fstab" || { echo "ERROR: fstab 无 growfs" >&2; exit 1; }

# ---------------------------------------------------------------- 8) 收尾出盘
log "8) 卸载 + 收缩"
sync
sudo umount "${MNT}"
sudo losetup -d "${LOOP}"; LOOP=""
sudo e2fsck -f -y "${OUT_IMG}.tmp" >/dev/null 2>&1 || true
sudo resize2fs -M "${OUT_IMG}.tmp" | tail -1 || true
BLOCKS=$(sudo dumpe2fs -h "${OUT_IMG}.tmp" 2>/dev/null | sed -n 's/^Block count:[[:space:]]*//p')
BSIZE=$(sudo dumpe2fs -h "${OUT_IMG}.tmp" 2>/dev/null | sed -n 's/^Block size:[[:space:]]*//p')
[ -n "${BLOCKS}" ] && [ -n "${BSIZE}" ] && sudo truncate -s "$(( (BLOCKS * BSIZE + 4095) / 4096 * 4096 ))" "${OUT_IMG}.tmp"
mv "${OUT_IMG}.tmp" "${OUT_IMG}"

# ---------------------------------------------------------------- 9) 复核（04 同款：缩后重挂点验）
log "9) 复核"
LOOP=$(sudo losetup -fP --show "${OUT_IMG}")
sudo mount "${LOOP}" "${MNT}"
FAIL=0
chk() { # chk <说明> <路径存在性命令>
    if sudo bash -c "$2"; then log "  ✓ $1"; else log "  ✗ $1"; FAIL=1; fi
}
chk "设备档案在位"          "test -f ${MNT}/usr/lib/armada/devices/meizu-meizu20.conf"
chk "device-env 匹配行"     "grep -q 'meizu-meizu20' ${MNT}/usr/libexec/armada/device-env"
chk "r80 模块树"            "test -d ${MNT}/usr/lib/modules/7.3.0-rc6/kernel && ls ${MNT}/usr/lib/modules/7.3.0-rc6/modules.dep"
chk "ianchb 旧树已清"       "! ls -d ${MNT}/usr/lib/modules/* 2>/dev/null | grep -v '7.3.0-rc6' | grep -q ."
chk "modules-load uinput"   "grep -q uinput ${MNT}/usr/lib/modules-load.d/meizu20-uinput.conf 2>/dev/null || grep -qr uinput ${MNT}/usr/lib/modules-load.d/ ${MNT}/etc/modules-load.d/"
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
chk "bootimg 重写件已摘"    "! grep -q armada-bootimg-sync ${MNT}/etc/systemd/system/multi-user.target.wants/armada-bootimg-sync.service 2>/dev/null"
chk "SELinux permissive"    "grep -q '^SELINUX=permissive' ${MNT}/etc/selinux/config 2>/dev/null"
# steam 客户端落点以上游包布局为准（缺位只记警告，不算败项）
if sudo bash -c "test -d ${MNT}/usr/lib/steam/arm-client || test -d ${MNT}/usr/lib/armada/steam || test -d ${MNT}/opt/steam"; then
    log "  ✓ steam 客户端预种"
else
    log "  WARN: steam 客户端预种落点未识别（首启由 steam-bootstrap 自拉，不拦盘）"
fi
if [ "${FAIL}" -ne 0 ]; then
    sudo umount "${MNT}"; LOOP=""
    echo "FATAL: 复核有败项，产物保留为 ${OUT_IMG}.reject" >&2
    sudo mv "${OUT_IMG}" "${OUT_IMG}.reject"
    exit 1
fi
sudo umount "${MNT}"; LOOP=""

( cd "$(dirname "${OUT_IMG}")" && sha256sum "$(basename "${OUT_IMG}")" > "$(basename "${OUT_IMG}").sha256" )
{
    echo "meizu-meizu20 armada-sheng 镜像（上游 v1.2 sheng-flashable + r80 腿 + meizu 层）"
    echo "built: $(date -u '+%Y-%m-%d %H:%M:%SZ')"
    echo "base:  code002-2/armada-sheng sheng-flashable (2026-09-05)"
    echo "kernel: r80 (7.3.0-rc6 #81, apk sha8 b0c865b7, ESP v61 配对)"
    echo "boot:  recovery_a ESP v61（不刷，本图只进 userdata /dev/sda22）"
    echo "debug: NCM 172.16.42.1 + sshd(root/${ROOT_PW}) + autologin armada(armada)"
    echo "sleep: fake-suspend（ARMADA_SUSPEND_MODE=fake）"
} > "${OUT_IMG}.MANIFEST.txt"
cat "${OUT_IMG}.MANIFEST.txt"
ls -lh "${OUT_IMG}" "${OUT_IMG}.sha256"
log "DONE: ${OUT_IMG}"
