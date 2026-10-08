#!/usr/bin/env bash
# steamos-meizu20 — 全局钉子（唯一定位点）
# 本文件只被 source，不直接执行。上游 provenance 与设备现役版本都钉在这里。

# ---- 本仓 ----
SM20_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SM20_WORK="${SM20_WORK:-$(dirname "$SM20_ROOT")}"   # 兄弟目录布局：linux-mobile-ports/pmos_linux/nura 都在工作根

# ---- 上游 provenance（克隆基点；勿动）----
PIN_UPSTREAM_GIT="https://github.com/code002-2/Steamos-xiaomi-sheng.git"
PIN_UPSTREAM_TIP="bbc60650a15dabfbf50141d51e597c465ab97997"
PIN_UPSTREAM_BRANCH="main"
PIN_UPSTREAM_PKGREF="code002-2/archlinux-sheng"        # 上游设备包仓（我们不消费其产物，仅审计参照）
PIN_IANCHB_KERNEL="https://github.com/ianchb/sm8550-mainline"  # sheng 内核仓（我们不消费，同 SoC 参照）

# ---- 底包（Steam Frame 官方，Valve 公开直连）----
PIN_FRAME_URL="https://steamdeck-images.steamos.cloud/recovery/steamframe-repair-latest.img.bz2"
PIN_FRAME_KNOWN_VER="steamframe-oobe-repair-20260922.5153644-0.3.0"  # 上游实测版本
SM20_DL_DIR="$SM20_ROOT/dl"                             # 用户手放的底包镜像放这里（gitignore）
PIN_FRAME_LOCAL_BZ2="$SM20_DL_DIR/steamframe-repair-latest.img.bz2"

# ---- 设备侧现役（= pmos_linux 主仓/nura 2026-10-07 检查轮终态；换内核须同步改）----
PIN_LINUX_DIR="${SM20_LINUX_DIR:-$SM20_WORK/linux-mobile-ports}"   # fork 内核树
PIN_LINUX_BRANCH="meizu20-t4b"
PIN_LINUX_TIP="02fe4629080a"
PIN_NURA_ROOT="${SM20_NURA_DIR:-$SM20_WORK/nura-meizu-m2381}"      # 内核 apk/ESP 产物出处
REL_LINUX_PKGREL="77"       # r77 = 7.3.0_rc6（pmOS 2026-10-09 现役；功放风暴全套 + ath12k 暖重连 + rebase rc3→rc6）
REL_KERNEL_VER="#78"        # r77/rc6 内核（#N=pkgrel+1 定律；uname 期望）
REL_ESP_IMG="$PIN_NURA_ROOT/artifacts/esp-recovery-v58.img.gz"  # v58 = r77 内核；SteamOS 模块腿必须同源（两腿铁律）
REL_DEVICE_PKGREL="58"
PIN_PMAPORTS="${SM20_PMAPORTS_DIR:-$SM20_WORK/pmos_linux/pmos/pmaports}"  # 设备层源头（device-meizu-meizu20）
PIN_PMAPORTS_BRANCH="phoenix"
PIN_FW_TARBALL_TAG="r66"    # 固件 tarball 在 nura Release r66 资产里（→ /lib/firmware）

# ---- 目标分区/挂载（graft 入参依据）----
TARGET_PARTLABEL="userdata"   # fastboot flash userdata；上机前 ls /dev/disk/by-partlabel 核对
TARGET_PART="/dev/sda22"
TARGET_FSMODE="single (userdata)"   # 上游 boot_mode 只取 fstab PARTLABEL 语义；boot.img 我们不用

# ---- 回滚锚（本项目只刷 userdata；三锚全不碰）----
ANCHOR_PMOS_ROOTFS="$PIN_NURA_ROOT/artifacts"   # pmOS rootfs 回滚件出处（Release r66 rootfs 或本地重建）
ANCHOR_TB2="$SM20_WORK/meizu20/meizu20-m1/artifacts-uefi/mars-t-series/t-b2-m2381Pkg-RELEASE-d4928661.img"
ANCHOR_ESP_V4D="$SM20_WORK/meizu20/meizu20-m1/m1-work/arch-a/esp-recovery-v4d.img"

# ---- 设备通道（P1 主通道 = WiFi+sshd，构建期预配）----
DEV_IP="172.16.42.1"
DEV_USER="root"
# DEV_PASS / WIFI_SSID / WIFI_PSK / SSH_PUBKEY = 构建入参，不写进仓（现场 export）

sm20_die() { echo "FATAL: $*" >&2; exit 1; }
sm20_require() { [ -e "$1" ] || sm20_die "钉子失效：$1 不存在（改 config.sh）"; }
sm20_precheck() {
	sm20_require "$PIN_LINUX_DIR"
	sm20_require "$PIN_PMAPORTS"
}
