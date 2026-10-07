# M2381 适配执行计划（P0 宿主轮 → P1 spike → P2 日用化）

> 判词与三路线对比 = `pmos_linux/docs/meizu20/steam-armada-assessment-20261008.md`；
> 上游管线逐行注释都在脚本头（写得极好，动手前先读对应脚本头部注释）。
> 本文 = m2381 视角的执行单。**所有宿主命令在宿主跑（sudo+loop），长命令 systemd-run。**

## P0 宿主构建轮（目标：产出可刷的 rootfs.img，零设备）

### 0. 前置

```sh
sudo dnf install -y btrfs-progs e2fsprogs rsync zstd xz bzip2 python3 curl util-linux
df -h /home   # 构建全程峰值 ~20 GB（bz2 4G + 整盘 7.5G 瞬态 + rootfs.frame 5G + rootfs.img 8-14G）
```
- 工作目录用 `$SM20_ROOT/work`（真实文件系统，gitignore 已挡；**别用 /mnt 默认值也行但要确认空间，禁 /tmp**）。
- `source config.sh && sm20_precheck`（钉子自检：fork 内核树 + pmaports 在位）。

### 1. 取底包（00-fetch-frame-rootfs.sh，原样用）

```sh
chmod +x scripts/host/*.sh scripts/in-chroot/*.sh
sudo env FRAME_IMAGE_URL="file://$PWD/dl/steamframe-repair-latest.img.bz2" \
         WORK="$PWD/work" OUT="$PWD/work/out" \
  bash scripts/host/00-fetch-frame-rootfs.sh
```
- 产物 `work/out/rootfs.frame`（btrfs 分区镜像）+ `frame-src-root` + `frame-src-extra` + `frame-os-release`。
- 下载函数走 curl，file:// 直通；**不放本地镜像就直接用官方 URL**（网络允许时）。
- 探针段会打「关键路径自查」——确认 `usr/lib/libvulkan_freedreno.so`、`usr/bin/gamescope`、
  `usr/share/wayland-sessions` 为 [OK]；核对 frame-os-release 的底包版本号记入交接。

### 2. 备好「我们的层」（替代上游 archlinux-sheng pacman 包）

在 `work/layer/` 组装四件（P0 最小集）：

| 件 | 来源 | 落点 |
|---|---|---|
| 内核模块 | 在机同源 apk：`pmos_linux/pmos/.pmbootstrap/packages/edge/aarch64/linux-meizu-meizu20-*-r66*.apk`，两层 tar 解开（apk 外壳 tar.gz → 内部 data.tar.gz）取 modules 树；备选 = fork 树构建输出 | `usr/lib/modules/<KVER>/`（KVER = 目录名，全程钉死） |
| 固件 | nura Release r66 固件 tarball 资产（qcom+qca+ath12k 收割件） | `lib/firmware/`（合并，不覆盖目录结构） |
| 设备 units | pmaports `device-meizu-meizu20`（phoenix 分支）包文件：meizu-touch.service + `/usr/lib/meizu20/` 脚本 + modprobe.d 黑名单 + 触控/震动 udev 规则 | 原路径 cp |
| 睡眠 mask | 自造：`/etc/systemd/system/{sleep,suspend,hibernate,hybrid-sleep}.target → /dev/null` + sleep.conf `AllowSuspend=no` | — |

- **P0 故意不含**：音频 guard/UCM（P2）、hexagonrpcd+传感器链（glibc 重建，P2）、蜂窝（摘除态）。
- 记下 `KVER`：P0 终检与 P1 `uname -r` 都对它。

### 3. 铺盘（01-lay，原样）

```sh
sudo bash scripts/host/01-lay-rootfs.sh "$PWD/work/out/rootfs.frame" rootfs.img 14G
```

### 4. graft 注入（核心改造）

- **不改上游 10-graft.sh**：`cp scripts/in-chroot/10-graft.sh scripts/in-chroot/10-graft-m2381.sh`
  后动手术（上游文件留作 diff 基准）：
  1. **头部（~L28-80）**：删「pacman -Rdd 底包内核/固件 + pacman -U 设备包」段 →
     换成 `cp -a work/layer/. /`（我们已在 01-lay 后挂载态注入）+ `depmod -a $KVER` +
     `modules.dep` 存在性 die 闸。
  2. **/home 段（bbc6065 的 sda30 兜底）**：**整段删**——我们没有独立 home 分区，
     /home 就在根上；留着会在我们机器上找 /dev/sda30。
  3. **sheng 专属件**（xiaomi-sheng-thp/devauth/fingerprint/pen/keyboard-helper、
     sheng-wifi-backend、sheng-startplasma 引用）：逐段删或跳过；多数是
     `|| warn` 容错，但引用不存在的文件路径的要删干净。
  4. **保留**：fstab（PARTLABEL 入参）、/var 骨架、Frame 引导残留清理、dbus user、
     SDDM/Plasma 会话、WiFi NM keyfile、root 密码、SSH pubkey、steam 客户端播种
     （/usr/lib/steam/arm-client + RUNSTEAM.sh + steam.service PartOf 修复）、
     gamescope-session drm backend 补丁、OOBE 标记（读一遍 mark_oobe_complete 逻辑再定）。
- chroot 执行（照 workflow 的挂蓝本）：

```sh
sudo mount -o loop rootfs.img /mnt/rootfs
# bind dev/pts/proc/sys + resolv.conf 先删再写（上游注释的坑）+ 拷 layer 和 graft 脚本进 /root/graft/
sudo chroot /mnt/rootfs /bin/bash -c \
  "PARTLABEL='userdata' WIFI_SSID='...' WIFI_PSK='...' ROOT_PW='...' SSH_PUBKEY='...' \
   KVER='<上一步钉死的>' bash /root/graft/10-graft-m2381.sh"
sudo env SHRINK_IMAGE=true bash scripts/host/03-finalize-image.sh rootfs.img /mnt/rootfs
```

### 5. 终检（04-verify 的 ESP 变体）

- 上游 04 从 boot.img 抠内核对版本；我们没有 boot.img → **对 ESP 里的 vmlinuz-efi**：
  从 `nura/artifacts/esp-recovery-v47.img.gz` 解出 ESP（mtools `mcopy` 取
  `/EFI/BOOT/vmlinuz-efi`），`tr '\0' '\n' | grep -m1 '^Linux version'` 提取版本串，
  与 rootfs `/usr/lib/modules` 目录名比对（脚本逻辑照抄 04，内核来源换掉）。
- 结果记录：rootfs.img 尺寸 + sha256 + KVER + 底包版本 + graft diff 摘要 → 追加到本文档尾部
  「构建台账」。

## P1 spike 设备日（判生死，不达零损失退出）

1. **刷前**：设备 pmOS 在机 → `ls /dev/disk/by-partlabel/ | grep userdata` 核对 GPT 名；
   回滚件（pmOS rootfs img）在宿主就位；用户点头。
2. 刷写（前台逐条）：`systemctl reboot --reboot-argument=bootloader` → `fastboot flash
   userdata rootfs.img` → `fastboot reboot`。**boot_b/ESP/recovery 不碰。**
3. 首启预期：Mu UEFI → #67 → systemd → SDDM 自动登录 steamos → Plasma。
   无串口，早期死亡无 journal ⇒ 黑屏/卡死 = 直接回刷 pmOS 换迭代变量（fastboot 往返
   几分钟，别恋战）。
4. SSH 里程碑（WiFi 预配入参）后逐项：
   `uname -r` == KVER ｜ `dmesg` 面板/触控/GPU/card0 ｜ `eglinfo`/`vulkaninfo` renderer
   串（预期 freedreno a740）｜ 触屏点按 ｜ 充电插入 upower 有响应 ｜ **powerdevil
   自动睡眠确认被 mask 压住** ｜ `RUNSTEAM.sh`/steam 客户端起得来到登录页。
5. P1 通过线：SSH + GL/VK 渲染串 + Steam 客户端到登录 + 触控可用。
6. 回滚：`fastboot flash userdata <pmOS rootfs.img>` + reboot。

## P2 日用化（P1 过了才谈）

- 音频：我们的 UCM → `/usr/share/alsa/ucm2`；直驱钉值 route → PipeWire 语境 oneshot；
  「听筒当听筒」remap → PipeWire loopback 等价件。游戏可先降级验收「能出声」。
- 传感器：hexagonrpcd glibc 重建（上游双栖已证）+ sensorspd 链移植 → 自动亮度/转屏。
- 震动：SDL 直读内核 ff-memless，udev 规则带上即可（比 pmOS feedbackd 更省）。
- NCM gadget NM 配置（devsh 通道回归）；手柄映射/Steam Input；温控与性能观察。

## 未验证清单（逐项销账）

- 底包 `latest` 是否仍是 20260922.5153644-0.3.0（探针兜底）。
- graft 里 pacman 段以外是否还有对 sheng 包的硬依赖（die 点）。
- PARTLABEL=userdata 与我们 GPT 实名的一致性。
- Frame mesa × Adreno 740 渲染串（Frame 是 750 同族，理论无险）。
- holo systemd/内核 7.3 组合下 growfs/zram/交换等默认行为。
- Steam 客户端播种脚本对用户目录布局的假设（/home 在根上 vs 上游独立分区）。
- 充电/电量在 holo upower 下的表现（内核侧 pmOS 已证，用户态未验）。

## 构建台账（每轮追加）

（空——P0 首轮起记录：日期 / rootfs.img sha256+尺寸 / KVER / 底包版本 / graft diff 摘要 / P1 结果）
