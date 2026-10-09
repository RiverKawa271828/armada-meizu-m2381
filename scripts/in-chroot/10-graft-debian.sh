#!/bin/bash
# 10-graft-debian.sh —— m2381 设备层 → Debian 13 rootfs（chroot 内跑，qemu-aarch64）
#
# 移植自 10-graft-m2381.sh 的实机验证段：NCM gadget / usb0-ip / 横屏 autostart /
# Steam ARM 客户端播种 / meizu 设备服务 / 睡眠 mask。底包从 Frame holo 换成 Debian 13。
# 构建入参（30-build-debian 传入）：PARTLABEL KVER ROOT_PW SSH_PUBKEY DOWNLOAD_STEAM_CLIENT
#   STEAM_CACHE（可选）= 宿主 Steam zip 缓存目录（30-build bind 到 /mnt/steam-cache），命中免下载
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
log()  { printf '[%s] %s\n' "${0##*/}" "$*"; }
warn() { printf '[%s] 警告: %s\n' "${0##*/}" "$*" >&2; }
die()  { printf '[%s] 错误: %s\n' "${0##*/}" "$*" >&2; exit 1; }

# chroot 内 apt 触发服务启动毫无意义且会报错 —— policy 拦掉，收尾再删
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod 0755 /usr/sbin/policy-rc.d
cleanup_pol() { rm -f /usr/sbin/policy-rc.d; }
trap cleanup_pol EXIT

# ---------------------------------------------------------------- 1) 国内源 + 基础
cat > /etc/apt/sources.list <<'EOF'
deb http://mirrors.ustc.edu.cn/debian/ trixie main contrib non-free non-free-firmware
deb http://mirrors.ustc.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://mirrors.ustc.edu.cn/debian-security/ trixie-security main contrib non-free non-free-firmware
deb http://mirrors.ustc.edu.cn/debian/ trixie-backports main contrib non-free non-free-firmware
EOF
log "1) apt update（USTC 国内源）"
apt-get update || die "apt update 失败"

log "2) 卸自带内核/cloud-init（我们走 ESP 内核腿）"
apt-get purge -y -q 'linux-image-*' 'linux-headers-*' initramfs-tools cloud-init \
  'cloud-guest-utils' 2>/dev/null || warn "purge 部分跳过（本来就没有）"
apt-get autoremove -y -q >/dev/null 2>&1 || true

log "3) 安装桌面/会话/音频/图形栈（qemu 下 dpkg 较慢，耐心）"
PKGS="locales sudo openssh-server network-manager wireless-regdb ca-certificates curl xz-utils
  sddm plasma-desktop plasma-workspace konsole systemsettings kinfocenter kscreen
  plasma-nm bluedevil bluez powerdevil xdg-desktop-portal-kde plasma-pa maliit-keyboard
  pipewire pipewire-pulse wireplumber pipewire-alsa
  libgl1-mesa-dri mesa-vulkan-drivers libegl-mesa0 mesa-utils vulkan-tools
  fonts-noto-cjk iio-sensor-proxy dbus-user-session
  alsa-utils alsa-ucm-conf zstd lsof
  libgtk2.0-0t64 libopenal1
  libsdl2-2.0-0 libsdl2-mixer-2.0-0 libvpx9"
if ! apt-get install -y -q $PKGS; then
  warn "整批安装失败 → 逐包重试（坏包跳过，其余照装）"
  for p in $PKGS; do apt-get install -y -q "$p" >/dev/null 2>&1 || warn "    装不上: $p"; done
fi
# 可选件：缺了不影响出图。gamescope 只在 trixie-backports（trixie 主仓没有，
# v3 实机验证 3.16.22+ds-1~bpo13+1 可装可跑，二进制在 /usr/games/gamescope）
apt-get install -y -q -t trixie-backports gamescope >/dev/null 2>&1 \
  || warn "gamescope 装不上（继续，只影响嵌套模式）"
# Debian 把 gamescopereaper 放 /usr/games，gamescope 按自身路径/PATH 找不到（2026-10-10 实测）
if [[ -x /usr/games/gamescopereaper ]]; then
  mkdir -p /usr/lib/gamescope
  ln -sf /usr/games/gamescopereaper /usr/lib/gamescope/gamescopereaper
  ln -sf /usr/games/gamescopereaper /usr/local/bin/gamescopereaper
fi
apt-get install -y -q glmark2 >/dev/null 2>&1 || warn "可选包装不上（继续）: glmark2"
# libpam-kwallet5 = 登录 PAM 钩子，会在掌机会话里白白拉起 kwalletd（2026-10-10 清理；
# kwallet6 本体不能删——连坐 plasma-pa/kscreenlocker/plasma-integration 等桌面内脏）
apt-get purge -y -q libpam-kwallet5 libpam-kwallet-common 2>/dev/null || true

# ---------------------------------------------------------------- 4) m2381 层注入
log "4) 注入 m2381 层（模块/固件/设备单元）"
[[ -d /root/graft/layer ]] || die "层不在 /root/graft/layer（30-build 没拷？）"
cp -a /root/graft/layer/. /
depmod "$KVER" || die "depmod 失败"
# 音频编排三件 enable（preset 同款；meizu-audio 手动链绝不 enable——SWR CLASH）
for s in meizu-touch meizu-pas meizu-memsleep meizu-bind-nfc-haptics \
         meizu-amps meizu-sndcard-bind meizu-audio-route; do
  systemctl enable "$s.service" 2>/dev/null && log "  ✓ enable $s" || warn "  ✗ enable $s"
done

# 关键文件自检（msm 内建不查 —— CONFIG_DRM_MSM=y，查了必虚报）
missing=0
for f in /usr/lib/meizu20/meizu-touch-load.sh \
         /usr/lib/systemd/system/meizu-touch.service \
         /usr/lib/systemd/system/meizu-pas.service \
         /usr/lib/systemd/system/meizu-memsleep.service \
         /usr/lib/systemd/system/meizu-bind-nfc-haptics.service \
         /usr/lib/meizu20/meizu-audio-route.sh \
         /usr/lib/systemd/system/meizu-audio-route.service \
         /usr/share/alsa/ucm2/Qualcomm/sm8550/MEIZU20.conf \
         /usr/share/alsa/ucm2/conf.d/sm8550/MEIZU20.conf \
         /usr/lib/firmware/qcom/sm8550/MEIZU20-tplg.bin \
         /etc/modprobe.d/50-meizu20-blacklist.conf \
         /usr/lib/udev/rules.d/70-meizu20-vibra.rules \
         /usr/lib/tmpfiles.d/meizu-sleepmask.conf \
         "/usr/lib/modules/$KVER/modules.dep"; do
  [[ -e "$f" ]] && log "  ✓ $f" || { warn "  ✗ 缺 $f"; missing=$((missing+1)); }
done
[[ "$missing" -eq 0 ]] || warn "层组装缺 $missing 个关键文件"

# ---------------------------------------------------------------- 5) 睡眠全 mask
mkdir -p /etc/systemd/sleep.conf.d
cat > /etc/systemd/sleep.conf.d/sm20-nosleep.conf <<'EOF'
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
EOF
for t in sleep suspend hibernate hybrid-sleep suspend-then-hibernate; do
  ln -sfn /dev/null "/etc/systemd/system/$t.target"
done
log "5) 睡眠 mask 落死（s2idle 睡死定律）"

# ---------------------------------------------------------------- 6) NCM gadget + usb0 IP
install -d -m 0755 /usr/lib/steamos /etc/systemd/system
cat > /usr/lib/steamos/m2381-ncm-gadget <<'EOF'
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
chmod 0755 /usr/lib/steamos/m2381-ncm-gadget
cat > /etc/systemd/system/m2381-ncm-gadget.service <<'EOF'
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
systemctl enable m2381-ncm-gadget.service 2>/dev/null \
  && log "6) 已启用 m2381-ncm-gadget" || warn "启用 m2381-ncm-gadget 失败"

# NM 不许碰 usb0（holo 实机教训的 Debian 版预防针）
install -d -m 0755 /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/89-m2381-usb0.conf <<'EOF'
[keyfile]
unmanaged-devices=interface-name:usb0
EOF

# 静态 IP 调试通道。用户拍板（2026-10-09 设备日）：出网走设备自身 WiFi，
# usb0 不配默认路由/不接管 DNS —— v3 实测宿主 firewalld 会 reject 转发包，
# metric 500 抢默认路由只会把出网截死。
cat > /etc/systemd/system/m2381-usb0-ip.service <<'EOF'
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
systemctl enable m2381-usb0-ip.service 2>/dev/null \
  && log "已启用 m2381-usb0-ip（172.16.42.1/24，无默认路由）" || warn "启用 m2381-usb0-ip 失败"

# ---------------------------------------------------------------- 7) 横屏 autostart
echo right > /etc/default/m2381-rotation
cat > /usr/lib/steamos/m2381-landscape <<'EOF'
#!/bin/bash
# m2381: 会话起来后把内屏转成横屏（方向见 /etc/default/m2381-rotation）
set -u
DIR="$(cat /etc/default/m2381-rotation 2>/dev/null || echo right)"
case "$DIR" in right|left|inverted|none) ;; *) DIR=right ;; esac
[[ "$DIR" == "none" ]] && exit 0
for i in $(seq 1 60); do
  OUT="$(kscreen-doctor -o 2>/dev/null | awk '/^Output:/{print $3; exit}')"
  if [[ -n "$OUT" ]]; then
    if kscreen-doctor "output.$OUT.rotation.$DIR" >/dev/null 2>&1; then
      logger "m2381-landscape: $OUT -> $DIR"
      exit 0
    fi
  fi
  sleep 2
done
logger "m2381-landscape: 60 轮没等到可用输出，放弃（方向 $DIR 未生效）"
exit 0
EOF
chmod 0755 /usr/lib/steamos/m2381-landscape
install -d /etc/xdg/autostart
cat > /etc/xdg/autostart/m2381-landscape.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=m2381 landscape
Exec=/usr/lib/steamos/m2381-landscape
X-KDE-autostart-phase=0
Terminal=false
NoDisplay=true
EOF
log "7) 已放入 m2381-landscape（autostart 会话内跑，kscreen-doctor 转 right）"

# ---------------------------------------------------------------- 8) 用户 / SSH / 会话
log "8) 用户与 SSH"
userdel -r debian 2>/dev/null || true
id steamos >/dev/null 2>&1 || useradd -m -u 1000 -s /bin/bash \
  -G video,input,render,bluetooth,netdev,plugdev,audio,sudo,users steamos
echo "root:${ROOT_PW:-123456}" | chpasswd
echo "steamos:${ROOT_PW:-123456}" | chpasswd
if [[ -n "${SSH_PUBKEY:-}" ]]; then
  for h in /root /home/steamos; do
    install -d -m 0700 "$h/.ssh"
    echo "$SSH_PUBKEY" > "$h/.ssh/authorized_keys"
    chmod 0600 "$h/.ssh/authorized_keys"
    chown -R 0:0 /root/.ssh
    chown -R 1000:1000 /home/steamos/.ssh
  done
  log "  ✓ SSH 公钥已注入（root + steamos）"
else
  warn "  没有 SSH 公钥（设备日只能密码进）"
fi
# 自动登录掌机模式（最小 kwin + steam -gamepadui；Plasma 保留为 SDDM 第二会话项）
install -d /etc/sddm.conf.d
cat > /etc/sddm.conf.d/zz-m2381.conf <<'EOF'
[General]
DisplayServer=wayland
# 会话退出后自动重登（SDDM 默认 autologin 只在服务启动时生效一次，
# steam 更新/退出会掉到登录界面——掌机形态必须 Relogin）
Relogin=true
[Autologin]
User=steamos
Session=steamos-session
EOF
systemctl enable sddm 2>/dev/null && log "  ✓ sddm 自启（自动登录 steamos → 掌机模式）" || warn "  sddm 启用失败"
# 掌机会话件（2026-10-10 实机验证）：最小 kwin(DRM, 120Hz) + steam -gamepadui。
# gamescope standalone 在本内核不可用：msm DPU 平面不声明 IN_FORMATS（只吃线性），
# turnip 平铺输出每次 atomic flip 被 EINVAL 拒 → 永久黑屏；llvmpipe 合成缺
# VK_EXT_physical_device_drm。kwin 走 GBM 线性分配 = 本面板已证 120Hz 路径。
install -d /usr/share/wayland-sessions
cat > /usr/local/bin/steamos-session <<'GRAFT_EOF'
#!/bin/bash
# steamos-session —— SDDM 直进 Steam 掌机界面（最小 kwin + steam -gamepadui）
# 横屏/120Hz 沿 ~/.config/kwinoutputconfig.json 的持久化输出配置
set -u
exec >/tmp/steamos-session.log 2>&1
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/games
export XDG_CURRENT_DESKTOP=steam
export QT_QPA_PLATFORM=wayland

# 一次性桌面会话旗标：sm20-session desktop 置位后，本次登录进 Plasma（下轮回掌机）
if [ -e /var/lib/sm20/want-desktop ]; then
  rm -f /var/lib/sm20/want-desktop
  exec /usr/lib/aarch64-linux-gnu/libexec/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland
fi

# kwin 最小化偏好（幂等）
mkdir -p "$HOME/.config"
KRC="$HOME/.config/kwinrc"
[ -f "$KRC" ] || : > "$KRC"
grep -q "AnimationDurationFactor" "$KRC" || cat >> "$KRC" <<'X'
[KDE]
AnimationDurationFactor=0

[Compositing]
OpenGLIsUnsafe=false
X

rm -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/wayland-0* 2>/dev/null
# 本镜像 tmpfiles 不建 /tmp/.X11-unix（x11-common 缺归置），kwin Xwayland 必需
mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
# GPU 调频：不做手动管理。游戏重载后 simple_ondemand 会休眠（钉死最低档+零换档），
# gpu-ondemand-watch.service 检测病理特征后重绑 governor 唤醒内核自主调度；
# 根治 = pmOS 内核线修 devfreq/msm（补丁落地后删除看护服务）
# 游戏前拉满频开关（恢复 = gpu-quiet）
printf '#!/bin/bash\necho 680000000 > /sys/class/devfreq/3d00000.gpu/min_freq\n' > /usr/local/bin/gpu-perf
printf '#!/bin/bash\necho 401000000 > /sys/class/devfreq/3d00000.gpu/min_freq\n' > /usr/local/bin/gpu-quiet
chmod 755 /usr/local/bin/gpu-perf /usr/local/bin/gpu-quiet
# --xwayland 必显式：Plasma 6.3 kwin 默认不起 Xwayland，steam 需要 X11
/usr/bin/kwin_wayland --xwayland >/tmp/kwin-session.log 2>&1 &

for _ in $(seq 1 50); do
  [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wayland-0" ] && break
  sleep 0.2
done
export WAYLAND_DISPLAY=wayland-0
for _ in $(seq 1 50); do
  xa=$(ls "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/xauth_* 2>/dev/null | head -1)
  [ -n "$xa" ] && break
  sleep 0.2
done
[ -n "${xa:-}" ] && export XAUTHORITY="$xa"
export DISPLAY=:0
for _ in $(seq 1 75); do
  [ -e /tmp/.X11-unix/X0 ] && break
  sleep 0.2
done

# steam 退出 = 会话结束，SDDM 重拉（重启即回掌机模式）
# -steamos3：点亮 Deck 式快速设置（WiFi/蓝牙面板；Bazzite/HoloISO 同款启动对）
exec /usr/local/bin/steam-arm -gamepadui -steamos3
GRAFT_EOF
chmod 755 /usr/local/bin/steamos-session
cat > /usr/share/wayland-sessions/steamos-session.desktop <<'EOF'
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=Steam 掌机模式 (kwin)
Name[en]=Steam Game Mode
Comment=开机直进 Steam 大屏幕界面（最小 kwin）
Exec=/usr/local/bin/steamos-session
DesktopNames=Steam
EOF
# /tmp/.X11-unix 归置（x11-common 的 tmpfiles conf 在本镜像缺失）
echo 'd /tmp/.X11-unix 1777 root root -' > /etc/tmpfiles.d/x11-unix.conf
# 会话切换命令（掌机/桌面）：sm20-session desktop|handheld|status
cat > /usr/local/bin/sm20-session <<'GRAFT_EOF'
#!/bin/bash
# sm20-session desktop|handheld|status —— 切换下次 SDDM autologin 的会话
FLAG=/var/lib/sm20/want-desktop
case "${1:-status}" in
  desktop)  mkdir -p /var/lib/sm20 && touch "$FLAG"; systemctl restart sddm; echo "下次会话 = Plasma 桌面" ;;
  handheld) rm -f "$FLAG"; systemctl restart sddm; echo "下次会话 = 掌机模式" ;;
  *) [ -e "$FLAG" ] && echo "下次会话 = Plasma 桌面" || echo "下次会话 = 掌机模式" ;;
esac
GRAFT_EOF
chmod 755 /usr/local/bin/sm20-session
# GPU 调频失明看护（临时，内核补丁落地后删）：检测"钉死最低档+零换档"→ 重绑 governor
cat > /usr/local/bin/gpu-ondemand-watch <<'GRAFT_EOF'
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
GRAFT_EOF
chmod 755 /usr/local/bin/gpu-ondemand-watch
cat > /etc/systemd/system/gpu-ondemand-watch.service <<'EOF'
[Unit]
Description=Watch devfreq simple_ondemand blindness and re-kick governor
After=multi-user.target
[Service]
Type=simple
ExecStart=/usr/local/bin/gpu-ondemand-watch
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
systemctl enable gpu-ondemand-watch.service 2>/dev/null \
  && log "  ✓ gpu-ondemand-watch 已启用（调频失明看护）" || warn "  gpu-ondemand-watch 启用失败"
log "  ✓ 掌机会话已装（steamos-session + autologin；sm20-session 切换掌机/桌面）"
# 01-lay 删过底包 host key，openssh-server 预装时 apt 不会重跑 postinst —— 必须显式重建
ssh-keygen -A 2>/dev/null || true
systemctl enable ssh 2>/dev/null && log "  ✓ ssh 自启（host key 已重建）" || warn "  ssh 启用失败"
systemctl enable NetworkManager 2>/dev/null && log "  ✓ NetworkManager 自启" || warn "  NM 启用失败"
systemctl disable systemd-networkd.service 2>/dev/null || true
# 时区/语言
ln -sfn /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
sed -i 's/^# *\(en_US.UTF-8\)/\1/; s/^# *\(zh_CN.UTF-8\)/\1/' /etc/locale.gen 2>/dev/null || true
locale-gen >/dev/null 2>&1 || true
echo "meizu20" > /etc/hostname
: > /etc/machine-id
# fstab：根 = userdata 分区（与 ESP cmdline root=/dev/sda22 同分区）
printf 'PARTLABEL=%s  /  ext4  defaults,noatime  0 1\n' "${PARTLABEL:-userdata}" > /etc/fstab

# ---------------------------------------------------------------- 9) Steam ARM 客户端
if [[ "${DOWNLOAD_STEAM_CLIENT:-1}" == "1" ]]; then
  (
    set +e
    set +u
    STEAM_CHANNEL="${STEAM_CHANNEL:-steamdeck_stable}"
    SEED=/usr/lib/steam/arm-client
    MANIFEST="steam_client_${STEAM_CHANNEL}_linuxarm64"
    BASE="https://client-update.steamstatic.com"
    log "9) 下载 Steam ARM 客户端（channel=$STEAM_CHANNEL）→ $SEED"
    mkdir -p "$SEED" /tmp/steamdl && cd /tmp/steamdl || exit 0
    # 整包缓存最高优先：work/cache/steam-arm/steam-client-full.tar.zst = 设备上
    # bootstrap 拉全的完整客户端备份（含 .installed 清单 ⇒ 首启零下载，v3 实机
    # 2026-10-10 打包）。命中即播种收工；损坏/缺失回退下方 CDN zip 流程。
    if [[ -n "${STEAM_CACHE:-}" && -s "$STEAM_CACHE/steam-client-full.tar.zst" ]]; then
      log "    整包缓存命中 steam-client-full.tar.zst —— 免 CDN 直接播种"
      rm -rf "$SEED"; mkdir -p "$SEED"
      if tar -xf "$STEAM_CACHE/steam-client-full.tar.zst" -C "$SEED" --strip-components=1 2>/dev/null \
         && [[ -x "$SEED/steamrtarm64/steam" \
            && -s "$SEED/package/steam_client_${STEAM_CHANNEL}_linuxarm64.installed" ]]; then
        printf '%s\n' "$STEAM_CHANNEL" > "$SEED/.m2381-arm-client"
        for f in steamrtarm64/steam steamui/index.html \
                 "package/steam_client_${STEAM_CHANNEL}_linuxarm64.installed"; do
          [[ -e "$SEED/$f" ]] && log "    ✓ $f" || warn "    ✗ 缺 $f"
        done
        log "    客户端体积: $(du -sh "$SEED" 2>/dev/null | cut -f1)（整包，首启零下载）"
        cd / && exit 0
      fi
      warn "    整包缓存解包/校验异常，回退 CDN zip 流程"
      rm -rf "$SEED"; mkdir -p "$SEED"
    fi
    if ! curl -fsSL --retry 2 --max-time 120 -o "$MANIFEST" "$BASE/$MANIFEST"; then
      warn "    清单下载失败 —— 网络或通道名变了"; exit 0
    fi
    BINS="$(grep -aoE 'bins_linuxarm64_linuxarm64\.zip\.[0-9a-f]+' "$MANIFEST" | head -1)"
    UI="$(grep -aoE 'steamui_websrc_all\.zip\.[0-9a-f]+' "$MANIFEST" | head -1)"
    CLIENTVER="$(grep -aoE '"version"[^0-9]*[0-9]{9,}' "$MANIFEST" | grep -aoE '[0-9]{9,}' | head -1)"
    [[ -n "$BINS" ]] || { warn "    清单解析不出 bins —— 格式变了"; exit 0; }
    log "    bins: $BINS  ui: ${UI:-无}  版本: ${CLIENTVER:-未知}"
    extract_zip() {
      python3 - "$1" "$SEED" <<'PY'
import sys, zipfile, pathlib
src, dest = sys.argv[1], pathlib.Path(sys.argv[2])
n = 0
with zipfile.ZipFile(src) as z:
    for info in z.infolist():
        name = info.filename.replace("\\", "/")
        if name.endswith("/") or name.startswith("/") or ".." in name.split("/"):
            continue
        out = dest / name
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(z.read(info))
        if name.endswith(("/steam", "/steamwebhelper", "/steamwebhelper.sh",
                          "/steam-runtime-check-requirements", "/.sh")):
            try: out.chmod(0o755)
            except Exception: pass
        n += 1
print(f"extracted {n} entries")
PY
    }
    # 缓存（STEAM_CACHE = 宿主 work/cache/steam-arm，bind 进 chroot）：zip 名含版本 hex，
    # 命中免下载；命中件校验不过自动回退重下；只有完整校验过的下载件才入缓存（.part 原子落位）。
    zip_ok() {
      python3 -c 'import sys,zipfile; sys.exit(0 if zipfile.ZipFile(sys.argv[1]).testzip() is None else 1)' "$1" 2>/dev/null
    }
    STEAM_CACHE="${STEAM_CACHE:-}"
    if [[ -n "$STEAM_CACHE" && -d "$STEAM_CACHE" && -w "$STEAM_CACHE" ]]; then
      log "    缓存: $STEAM_CACHE（$(du -sh "$STEAM_CACHE" 2>/dev/null | cut -f1)）"
    else
      STEAM_CACHE=""
    fi
    for z in "$BINS" "$UI"; do
      [[ -n "$z" ]] || continue
      SRC=""
      if [[ -n "$STEAM_CACHE" && -s "$STEAM_CACHE/$z" ]] && zip_ok "$STEAM_CACHE/$z"; then
        SRC="$STEAM_CACHE/$z"
        log "    $z ← 缓存命中"
      else
        log "    下载 $z …"
        curl -fsSL --retry 2 --max-time 1200 -o "$z" "$BASE/$z" || { warn "    $z 失败"; continue; }
        if ! zip_ok "$z"; then
          warn "    $z 下载件损坏，弃用"; rm -f "$z"; continue
        fi
        if [[ -n "$STEAM_CACHE" ]]; then
          cp -f "$z" "$STEAM_CACHE/$z.part" && mv -f "$STEAM_CACHE/$z.part" "$STEAM_CACHE/$z" \
            && log "    已入缓存: $z" || warn "    缓存写入失败（不影响本次构建）"
        fi
        SRC="$PWD/$z"
      fi
      log "    解包 $(basename "$SRC")（$(du -h "$SRC" | cut -f1)）"
      extract_zip "$SRC" 2>&1 | sed 's/^/        /'
      rm -f "$z"
    done
    mkdir -p "$SEED/package"
    echo "$STEAM_CHANNEL" > "$SEED/package/beta"
    cp -f "$MANIFEST" "$SEED/package/${MANIFEST}.manifest" 2>/dev/null || true
    printf 'ClientVersion=%s\n' "${CLIENTVER:-1788652215}" > "$SEED/steam.inf"
    cp -f "$SEED/steam.inf" "$SEED/steamrtarm64/steam.inf" 2>/dev/null || true
    printf '%s\n' "$STEAM_CHANNEL" > "$SEED/.m2381-arm-client"
    touch "$SEED/.install-complete"
    for f in steamrtarm64/steam steamrtarm64/steamui.so steamui/index.html; do
      [[ -s "$SEED/$f" ]] && log "    ✓ $f" || warn "    ✗ 缺 $f"
    done
    log "    客户端体积: $(du -sh "$SEED" 2>/dev/null | cut -f1)"
    cd / && rm -rf /tmp/steamdl
    exit 0
  ) 2>&1 | sed 's/^/[steam] /' || warn "Steam 客户端下载段失败（不影响出图）"
fi
# 启动器：首启把种子拷进用户目录再 exec（P2 再换 gamescope 会话）
cat > /usr/local/bin/steam-arm <<'EOF'
#!/bin/bash
set -eu
SEED=/usr/lib/steam/arm-client
DEST="$HOME/.local/share/Steam"
if [[ ! -x "$DEST/steamrtarm64/steam" ]]; then
  mkdir -p "$(dirname "$DEST")"
  rm -rf "$DEST"
  cp -a "$SEED" "$DEST"
  chown -R "$(id -u):$(id -g)" "$DEST"
fi
# steam.md 配方的软链 + 兼容层目录；~/.steam/steam 数据链缺失会让客户端
# 直接 assert 退出（"Steam data link does not exist"，v3 实机首启实测）
mkdir -p "$HOME/.steam" "$DEST/compatibilitytools.d"
ln -sfn "$DEST" "$HOME/.steam/steam"
ln -sfn "$DEST" "$HOME/.steam/root"
ln -sfn "$DEST/linuxarm64" "$HOME/.steam/sdkarm64" 2>/dev/null || true
# Steam UI 仍要 X11（vgui2/steamwebhelper）；Wayland 会话按需 XWayland 只服务
# 会话内启动，这里无 DISPLAY 就自挂一个 rootless Xwayland（v3 实机验证）
if [[ -z "${DISPLAY:-}" && -n "${WAYLAND_DISPLAY:-}" && -x /usr/bin/Xwayland ]]; then
  for d in 1 2 3 4; do
    [[ -e "/tmp/.X11-unix/X$d" ]] && continue
    Xwayland ":$d" -rootless >/dev/null 2>&1 &
    sleep 1
    export DISPLAY=":$d"
    break
  done
fi
# kwin 自管 Xwayland 启用 Xauthority 票据（/run/user/<uid>/xauth_*），会话外
# 启动缺票会被拒（"Authorization required"，v3 实机 2026-10-10 实测）
if [[ -n "${DISPLAY:-}" && -z "${XAUTHORITY:-}" ]]; then
  xa=$(ls /run/user/$(id -u)/xauth_* 2>/dev/null | head -1)
  [[ -n "$xa" ]] && export XAUTHORITY="$xa"
fi
chmod -R u+rwx "$DEST/steamrtarm64" 2>/dev/null || true
cd "$DEST"
exec ./steamrtarm64/steam "$@"
EOF
chmod 0755 /usr/local/bin/steam-arm
# 桌面入口（种子自带没有 .desktop，应用菜单/启动器才能发现 Steam）
cat > /usr/share/applications/steam-arm.desktop <<'EOF'
[Desktop Entry]
Name=Steam (ARM)
GenericName=Game Client
Comment=Valve Steam ARM64 客户端（m2381 播种，首启拷种子）
Exec=/usr/local/bin/steam-arm
Type=Application
Categories=Game;
Icon=applications-games
Terminal=false
StartupWMClass=steam
EOF
log "  ✓ Steam 桌面入口 steam-arm.desktop"
# libvpx 软链（steam.md：客户端要 so.6，trixie 只有 so.9）
if [[ -e /usr/lib/aarch64-linux-gnu/libvpx.so.9 && ! -e /usr/lib/aarch64-linux-gnu/libvpx.so.6 ]]; then
  ln -s libvpx.so.9 /usr/lib/aarch64-linux-gnu/libvpx.so.6 \
    && log "libvpx.so.6 → so.9 软链就位" || warn "libvpx 软链失败"
fi
# 兼容层（Proton 11 Beta ARM + Steam Linux Runtime ARM）设备侧安装器：
#   Valve 尚无稳定直链（steam.md「若尚未发布，稍后再看」），Steam UI 也能自拉；
#   本脚本 = 手动装的最后手段，压缩包解进 ~/.local/share/Steam/compatibilitytools.d/
cat > /usr/local/bin/m2381-proton-setup <<'EOF'
#!/bin/bash
# 用法: m2381-proton-setup <Proton-ARM.tar.*> [SteamLinuxRuntime-ARM.tar.*]
# 压缩包来源见 docs；解压到 compatibilitytools.d 后完全退出 Steam 再重启客户端。
set -eu
DEST="$HOME/.local/share/Steam/compatibilitytools.d"
mkdir -p "$DEST"
for f in "$@"; do
  [[ -f "$f" ]] || { echo "skip $f (not found)"; continue; }
  echo "解压 $f → $DEST/"
  tar -xf "$f" -C "$DEST"
done
ls "$DEST"
echo "完成后完全退出 Steam（含后台）再启动，设置里选兼容工具。"
EOF
chmod 0755 /usr/local/bin/m2381-proton-setup
log "steam-arm 启动器 + m2381-proton-setup 兼容层安装器就位"

# 首启把 rootfs 长满 userdata 分区（finalize 收缩后 FS 只有镜像大小，Steam/Proton 会秒满）
cat > /etc/systemd/system/rootfs-grow.service <<'EOF'
[Unit]
Description=Grow root filesystem to fill userdata partition
After=local-fs.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'resize2fs "$(findmnt -n -o SOURCE /)" || true'
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl enable rootfs-grow.service 2>/dev/null && log "rootfs-grow 首启扩容已启用" || warn "rootfs-grow 启用失败"

# ---------------------------------------------------------------- 10) 自检收尾
log "10) 终检"
for u in m2381-ncm-gadget m2381-usb0-ip meizu-touch meizu-pas meizu-memsleep \
         meizu-bind-nfc-haptics rootfs-grow sddm ssh NetworkManager; do
  if systemctl is-enabled --quiet "$u.service" 2>/dev/null; then
    log "  ✓ enabled: $u"
  else
    warn "  ✗ NOT enabled: $u"
  fi
done
[[ -x /usr/bin/kscreen-doctor ]] && log "  ✓ kscreen-doctor" || warn "  ✗ kscreen-doctor"
[[ -d /usr/share/wayland-sessions ]] && ls /usr/share/wayland-sessions/ | sed 's/^/    session: /'
cleanup_pol
trap - EXIT
log "Debian m2381 设备层注入完成（内核 $KVER）"
