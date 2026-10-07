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

- ~~底包 `latest` 是否仍是 20260922.5153644-0.3.0（探针兜底）。~~
  ✅ 本地 bz2 即 `steamframe-oobe-repair-20260922.5153644-0.3.0`；BUILD_ID=20260922.6152327，
  os-release = SteamOS holo 0.3.0 / VARIANT_ID=vr（graft 已改 steamdeck）。
- ~~graft 里 pacman 段以外是否还有对 sheng 包的硬依赖（die 点）。~~
  ✅ 全轮 graft EXIT=0：pacman 只剩 --dbonly 摘项（linux-firmware-deckard）；无其它 die。
  ⚠ 注：`pacman -Qq | grep -E '^linux(-[a-z0-9]+)?$'` 在这份底包上没匹配到内核包项
  （上游在他们的底包上匹配到过）——/usr/lib/modules 由 01-lay 清空，包项残留无害（P0 不跑 pacman 事务）。
- ~~PARTLABEL=userdata 与我们 GPT 实名的一致性。~~
  ✅ fstab 落 `PARTLABEL=userdata /`；fastboot by-name 同名（设备日 `ls /dev/disk/by-partlabel` 复核一次即可）。
- Frame mesa × Adreno 740 渲染串（P1 设备日 glmark2/vkmark）。
- holo systemd/内核 7.3 组合下 growfs/zram/交换等默认行为（P1 首启看 journal）。
- ~~Steam 客户端播种脚本对用户目录布局的假设（/home 在根上 vs 上游独立分区）。~~
  ✅ RUNSTEAM 首启播种逻辑不依赖分区布局（seed 在 /usr/lib/steam/arm-client，/home 在根上直接可见）。
- 充电/电量在 holo upower 下的表现（P1；meizu-pas 已 enable 作为前置）。
- **新增（本轮）**：qemu-aarch64 chroot 内跑的 systemctl enable/depmod/ssh-keygen 产物
  在真机上与原生一致（理论无差，P1 首启 journal 佐证）；uinput 内核未编（CONFIG_INPUT_UINPUT=n）
  —— Steam Input 虚拟手柄在 P2 前不可用，属内核缺口非镜像缺口。

## 构建台账（每轮追加）

### 2026-10-08 P0 首轮（宿主 = Fedora 宿主本体，systemd-run --user 通道）

| 项 | 值 |
|---|---|
| rootfs.img | `work/rootfs.img`，11 GiB（14G 收缩后），sha256 `c9372d0fee39c8ba0d464683e0d220f166d756d5924f1435a1f58fd777d0a93a` |
| KVER | `7.3.0-rc3`（r66 apk 模块腿 = ESP v47 BOOTAA64.EFI zboot payload，04-verify-esp 比对一致；vermagic `7.3.0-rc3 SMP preempt mod_unload aarch64`） |
| 底包 | SteamOS holo 0.3.0，BUILD_ID `20260922.6152327`（本地 bz2 = steamframe-oobe-repair-20260922.5153644） |
| graft | `10-graft-m2381.sh`（vs 上游 10-graft.sh 净改 539 行）：pacman 装包段→`cp -a` 层注入 + `--dbonly` 摘 Frame 内核/固件包项；/dev/sda30 home 段→删，换睡眠三防线（sleep.conf.d 全关 + 5 个 sleep target mask + memsleep 单元）+ powerdevil `powermanagementprofilesrc` 三档自动挂起关；sheng 专属（thp/devauth/fingerprint/pen/keyboard/expand-home）删；SteamOS-on-SM8550 通用修复全保留并更名 sheng→m2381；enable 集 = meizu-touch/pas/memsleep/bind-nfc-haptics；uinput 段删（内核未编） |
| 层 | `work/layer/`（20-m2381-layer.sh 产物，287M）：内核模块 94M + 固件 193M（ath12k/WCN7850、qca、qcom、cirrus）+ 4 units/2 脚本/黑名单/vibra 规则/sleepmask |
| Steam 客户端 | steamdeck_stable v1788652215，bins 105M + steamui 32M 解包 779 条，408M 落 /usr/lib/steam/arm-client，自检三项 ✓ |
| 入参 | root 密码随机生成（构建尾打印，不入仓）；WiFi 未预配；SSH 公钥已注入 /root/.ssh/authorized_keys |
| 宿主通道 | 容器内 `systemd-run --user --unit=<名> bash -lc 'sudo -n … >/tmp/zcode/<log> 2>&1'` = 宿主执行（/tmp/zcode 与容器共享）；宿主有 qemu-aarch64-static（11.1.2）+ binfmt F-flag，chroot 直跑 aarch64 |
| 宿主侧偏差 | ①01-lay rsync `-aHAX`→`-aHA`：SELinux 宿主上 security.selinux xattr 往 loop ext4 写/删被 LSM 拒（rc=23），且这套标签对设备镜像本来就是错的；②构建驱动 `30-build-m2381.sh`（00-fetch/20-layer 缺料自动补、chroot 挂蓝本、03/04 收尾）；③verify 用 `04-verify-esp-kernel-match.sh`（zboot-zstd 解包，非上游 boot.img 路径） |
| P1 | 未上机。刷写 = `fastboot flash userdata work/rootfs.img`；首启预期 Mu UEFI → 7.3.0-rc3 → SDDM 自动登录 steamos → Plasma；P1 判据与回滚见 §P1 |

### 2026-10-08 P0 第二轮（实机首刷反馈三修复，镜像 sha256 `578daa7e…`，root 密码重新随机）

| 实机发现 | 根因 | 修复（graft） |
|---|---|---|
| 登录后 ~/.config 全家 not writable（systemsettingsrc/powerdevilrc/kaccessrc…） | graft `install -d /home/steamos/.config` 默认 root 属主 → steamos 写不进任何配置 | `install -d -o steamos -g steamos -m 0700` + chown 兜底；顺带 RUNSTEAM.sh 拷贝件也 chown 给 steamos（steam.service 每次要覆盖它） |
| 默认竖屏 | 内核 DTS 未声明 panel rotation（pmOS 靠传感器自动转，无静态判据），kwin 跟随原生扫描向 | 新增 m2381-landscape：user 单元在 graphical-session 后 kscreen-doctor 转输出（连接器 DSI-1，pmOS 文档实证）；方向开关 `/etc/default/m2381-rotation`（默认 right，横反了改 left），结果持久化进 kwinoutputconfig.json |
| 无 WiFi 预配 = 不可调试 | 凭据属构建入参，P0 首轮没给 | 新增 m2381-ncm-gadget：USB NCM configfs gadget（18d1:4ee1，内核 F_NCM/CONFIGFS=y 编死）+ NM keyfile 固定 usb0=172.16.42.1/24 —— 插线即 `ssh root@172.16.42.1`，WiFi 之后可远程 nmcli 配 |

首刷其余判据全过：Mu UEFI → 7.3.0-rc3 → SDDM 自动登录 → Plasma 直连 Wayland ✓。
（插曲：宿主侧清理 fastboot 探针残留时误杀了用户正在跑的 flash 进程一次——教训 = 清理
必须先核对进程属主，重刷即覆盖无损失。）
