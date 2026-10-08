# steamos-meizu20 — 魅族 20（m2381/SM8550）SteamOS 移植线

> 本仓 = **改造自 code002-2/Steamos-xiaomi-sheng 的 m2381 适配项目**（fork 时代模式：
> 本地先行零网络，推送目标 = 自建 fork 待建）。
> 新会话必读本文；子系统细节看 `docs/M2381-PLAN.md`，判词出处 =
> `/home/ri/work/pmos_linux/docs/meizu20/steam-armada-assessment-20261008.md`。
> 主仓规范/硬定律 = `/home/ri/work/pmos_linux/AGENTS.md`（本文只留本项目规则与现态，
> 与主仓冲突时以主仓硬定律为准）。

## 现态一句话（新会话从这里接）

- **2026-10-09 同步点（新会话必读）**：pmOS 线内核已 rebase **rc3→rc6（r77/#78）**，
  设备 recovery_a 已刷 **ESP v58** ⇒ 第三轮镜像（af2bde33，rc3 模块）**作废不可刷**
  （vermagic 不匹配 = 零模块）。同步准备已全绿（commit ee1fb99）：钉子 r77/v58、
  层重组（KVER=7.3.0-rc6）、graft 适配。**新会话动作 = 宿主一条命令**：
  `sudo ROOT_PW=123456 bash scripts/host/30-build-m2381.sh`（缺料自动补）→
  04-verify 过 → **只刷 userdata**（ESP 已 v58；boot/recovery 不碰；root 密码=123456）。
  P0 三轮历史：首轮 11G 全绿（c9372d0f）→ 实机三修复（.config 属主/横屏引导/NCM
  gadget 通道，578daa7e）→ 固定密码 123456（af2bde33，已作废）。
- 上游克隆仍钉在 `main @ bbc60650`（原样留作 diff 基准）；m2381 变体 =
  `10-graft-m2381.sh` + `20-m2381-layer.sh` + `30-build-m2381.sh` +
  `04-verify-esp-kernel-match.sh`（改动清单见 M2381-PLAN 台账）。
- 设备 = 魅族 20 m2381，现役 pmOS（mu-r66/ESP v47/内核 #67/device r53/rootfs r53）。
  本项目**只动 userdata**（换 rootfs），boot_b/ESP/recovery 全不碰——回滚 = 重刷 pmOS
  rootfs，30 秒锚照旧。

## 底包镜像（用户下载后放这里）

- 期望路径：`dl/steamframe-repair-latest.img.bz2`（或任何 `*.img.bz2`；**勿提交进 git**，
  `.gitignore` 已挡 `dl/`）。
- 官方源：`https://steamdeck-images.steamos.cloud/recovery/steamframe-repair-latest.img.bz2`
  （~4 GB bz2 → 7.5 GB GPT 整盘）。上游实测版本 `steamframe-oobe-repair-20260922.5153644-0.3.0`；
  `latest` 若已换代，`00-fetch` 的探针（fstype/根子树/os-release）会兜底报结构变化。
- **灌入方式（零脚本改动）**：`FRAME_IMAGE_URL="file://$PWD/dl/steamframe-repair-latest.img.bz2"
  bash scripts/host/00-fetch-frame-rootfs.sh`（DLOAD 走 curl，支持 file://）。
- 备选：上游已发布解好的底包资产 `frame-base-20260922`（code002-2/steamos-sheng release，
  rootfs.partNN.zst + SHA256SUMS），需 GH_TOKEN 时 00-fetch 资产路径自动优先。

## 上游管线 → m2381 改造点（keep / replace / skip）

| 上游件 | 判 | m2381 对应 |
|---|---|---|
| `00-fetch-frame-rootfs.sh` + `parse-gpt.py` | **keep** | 原样用；本地镜像走 file:// URL；rootfs 分区是 btrfs（subvolid=5 挂顶层，勿按 zstd 偏移切片——上游踩过的坑） |
| workflow `packages` job（archlinux-sheng `_packages.yml`，pacman 设备包×16 + ianchb 内核/固件） | **replace** | 我们的层 = ①fork 内核 `/usr/lib/modules`（从在机同源 apk `linux-meizu-meizu20-r66` 解出）②固件 tarball → `/lib/firmware` ③设备 units（meizu-touch 等，源头 = pmaports `device-meizu-meizu20`）④睡眠 mask（s2idle 睡死必防）。全部以**普通文件 cp 进 rootfs**，不需要 pacman 包 |
| `01-lay-rootfs.sh` | **keep** | 原样（btrfs→ext4 铺盘 + 清底包 modules/fstab/boot 残留） |
| `10-graft.sh`（1815 行核心注入） | **keep 主体 + 换头尾** | 头部「pacman -U 设备包 + depmod」段换成「拷我们的层 + depmod」；sheng 专属件（xiaomi-sheng-thp/devauth/fingerprint/sheng-wifi-backend 等）跳过；fstab(WITH PARTLABEL)/var 骨架/WiFi NM/root 密码/SSH pubkey/SDDM-Plasma/steam 客户端播种（bbc6065 的 Valve 掌机 ARM Steam + PartOf 修复）全保留 |
| `03-finalize-image.sh` | **keep** | 原样（收缩 + 固定 UUID；UUID 对我们无约束，我们 cmdline 是 root=/dev/sda22） |
| boot.img 拉取 + `05-patch-bootimg-cmdline.sh`（rootwait 补丁） | **skip** | 我们不刷 boot 分区——内核在 ESP（recovery_a，EFI stub，cmdline 已烤 root=/dev/sda22）；sheng 的 boot.img 是给 sheng ABL 的 |
| `04-verify-kernel-match.sh` | **keep 思路** | 改造为「ESP vmlinuz-efi 的 `Linux version` 串 vs rootfs /usr/lib/modules 目录名」比对（防 vermagic 不一致黑屏，上游用多 tag 翻车换来的闸） |

## 本项目纪律（在主仓纪律之上的增量）

- **构建必须在宿主跑**（脚本全程 sudo + loop 挂载，agent 沙箱 NNP 必死——同 pmbootstrap
  规律）；长构建走 systemd-run，日志进 `/tmp/zcode/`。沙箱里试跑须 `sudo` 可用且先
  `dnf install btrfs-progs zstd`（Fedora 宿主自查）。
- **首次刷 SteamOS rootfs 前**：确认在机 pmOS rootfs img（回滚件）在手——nura Release r66
  rootfs 或本地重刷件；userdata 刷写 = 清掉 pmOS + /home 数据（waydroid/docker 镜像等），
  设备日当天用户点头才刷。
- **PARTLABEL 前置核对**：graft 写 `PARTLABEL=userdata /`——上机前在 pmOS 侧跑
  `ls /dev/disk/by-partlabel/ | grep userdata` 确认 GPT 名（预期就是 userdata，fastboot
  by-name 同源；不符则改 graft 的 PARTLABEL 入参）。
- root 密码不用默认 123456；WiFi 凭据只在构建入参，不进仓。
- 本仓私有；推送（若上游化）先建自建 fork，`origin` 已改名 `upstream` 指向 code002-2。

## 设备通道 / 回滚

- 通道：WiFi + sshd（构建期预配，P1 主通道）；NCM gadget = 内核侧现成、用户态配置挂 P1 可选；
  on-device konsole（触屏）兜底。
- 回滚锚（全不碰）：mu-r64-686a4c0f / v46 / r51（设备 `/home/user/esp-recovery-v26.img`）；
  宿主 30 秒配方 = t-b2（d4928661）+ esp-recovery-v4d（3b106f07）；rootfs 级回滚 =
  `fastboot flash userdata <pmOS rootfs.img>` + reboot（本项目的唯一刷写动作）。
- ⚠ s2idle 睡死定律在新 rootfs 同样成立：镜像内已列「sleep target 全 mask」为 P0 必做项，
  首启再复核 powerdevil 自动睡眠关。

## 排程

- **P0 宿主构建轮 ✅（2026-10-08 完成）**：一条命令 = 宿主 `30-build-m2381.sh`
  （缺料自动补 00-fetch/20-layer → 01-lay → chroot graft → 03-finalize → 04-verify-esp）。
  产物与宿主通道细节见构建台账；重跑（换入参如 WiFi/密码）直接再跑一遍即可
  （01-lay 会删 rootfs.frame，脚本自动重取）。
- **P1 spike 设备日（下一步）**：刷 userdata → SSH 里程碑 → 触控/GL/VK/Steam 客户端判生死；
  不达 = 重刷 pmOS rootfs 零损失退出。刷前核对 = pmOS 侧 `ls /dev/disk/by-partlabel/ | grep userdata`
  + 回滚件（pmOS rootfs img）在宿主 + 用户点头。
- **P2 日用化**：音频 PipeWire 翻译（UCM 复用 + 直驱钉值重表达）/ hexagonrpcd glibc 重建 +
  传感器链 / 震动 udev / 手柄映射 / 性能与温控观察。
