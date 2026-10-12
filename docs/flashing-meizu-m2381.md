# 刷机指南 — Meizu 20 (m2381) × Armada

> 面向已解锁设备的完整刷写/验收/回滚流程。工程背景与"为什么"见
> [M2381-ARMADA-PORT-20261011.md](M2381-ARMADA-PORT-20261011.md)。

## 前提（三条腿的来源）

| 部件 | 来源 | 说明 |
|---|---|---|
| 解锁 bootloader | 自备 | 与刷任何第三方系统同要求 |
| **boot 腿（ESP）** | [nura 项目](https://github.com/RiverKawa271828/nura-meizu-m2381)（现役 v65） | 刷在 **recovery_a**，EFI stub 内核，cmdline 烤死 `root=/dev/sda22`；**与内核 apk 必须配对** |
| **rootfs 镜像** | 本仓构建（见下） | 单分区裸 ext4，只进 **userdata** |
| 内核 apk / 固件 apk | [nura 项目 Release](https://github.com/RiverKawa271828/nura-meizu-m2381)（与 pmOS 通用） | 出盘时打进 rootfs，模块与 ESP 内核逐字节配对（构建门禁强制） |

boot_b / boot_a / 其它分区**全程不碰**——回滚 = 重刷 userdata，30 秒退出。

## 出盘（宿主 Linux，root）

```bash
just fetch-base     # 上游 armada-sheng rootfs（自动下载/校验/合并，已有则跳过）
just fetch-kernel   # 钉子版内核 apk（本地件或 nura 公开链接，sha256 门禁）
sudo bash build_files/build.sh    # 适配 → 收缩 → 点验 → work/meizu-meizu20-armada-r84.img
```

固件 apk（firmware-meizu-meizu20）放到 `work/armada-m2381/apk/` 即可被自动识别；
版本钉子在 `kernel-m2381/BUILD.env`，换新版料件 = 改那里 + 换配对 ESP。

## 刷写（三步）

```bash
# 1) 进 fastboot（系统内 'reboot bootloader'，或关机后按住音量下插线）
fastboot devices                      # 确认设备出现
# 2) 刷 userdata（唯一被写的分区；14.6G ≈ 6-7 分钟）
fastboot flash userdata work/meizu-meizu20-armada-r84.img
# 3) 重启
fastboot reboot
```

## ⚠ 刷写后偶发：ABL fastboot 僵死与「强启撕裂写」（2026-10-12 三轮对照实证）

**现象**：14G 级 userdata 刷写完成后，Mu ABL 的 fastboot 命令环偶发僵死——
`set_active b` 挂住数分钟无应答（正常 <1s），此后 `getvar`/`reboot` 全部
假应答（显示 OKAY 但设备不动）。三次脚本刷写两轮中招，手动刷写一轮正常
（脚本 = 宿主 systemd-run 直跑 fastboot，非容器转发；是否与下发侧时序有关
样本不足未定论，僵态本体在设备侧 ABL）。

**危害**：此时若长按电源强制重启，UFS 写缓存中未持久化的尾巴丢失 →
**撕裂写**，且必定砸坏 `/usr/share/vulkan` 的 ICD JSON 群（base 构建期同批
写入、物理相邻，一撕一串；两次事故撕裂清单完全一致）→ 首启 gamescope
`vkCreateInstance -9` SIGABRT → 回落 KDE「黑屏」。

**规避（按序尝试，强启是最后手段）**：
1. `fastboot reboot` 重发一次（假应答后设备有概率已离队，先看 NCM 是否枚举）；
2. `fastboot continue`（若 Mu 支持 = 优雅继续启动，不走电源循环）；
3. 实在不行才长按电源强启——**强启后首启必查**：SSH 跑
   `post_process/post-flash-health.sh`，重点看 `Filesystem state`（出现
   "clean with errors" = 有撕裂）与 `vulkaninfo` 的 Invalid JSON 计数。
   有伤的修法 = kexec fsck + 从原版 rootfs 回填撕伤文件（见
   M2381-CARDMU-AUDIT-20261012.md §9.3），或直接重刷一遍 userdata。

**待办**：ABL 僵态 bug 待整理给 nura / 上游会诊（复现步骤 = 大体积 sparse
刷写 → set_active 假应答 → 命令环死）。

## 首启预期

- **<1 分钟**进桌面：SDDM 自动登录 `armada`（密码 `armada`）→ gamescope → Steam。
- Steam 客户端已预种，可离线进 UI；联网后按提示完成一次更新。
- 磁盘自动扩容到全盘（457G）；声卡在开机 ~75s 后就位（wireplumber 会被自动踢一次）。
- 首件事：Steam 设置里连一次 WiFi（系统级落盘，重启自动重连）。

## 调试通道

- 插 USB 线：`ssh root@172.16.42.1`（初始密码 **123456，登录后请改**；
  `armada` 用户密码 `armada`）。
- 常用检查：
  ```bash
  systemctl --failed                      # 应为空
  systemctl is-active meizu-{pas,touch,amps,audio,sndcard-bind,audio-route}
  aplay -l | grep MEIZU20                 # card0 出卡
  ```
- 手柄：蓝牙配对后默认伪装成 Steam Deck 手柄（deck-uhid）；换伪装目标 =
  `sudo /usr/libexec/armada/controller-type apply`（需手柄已连接）。
- A/B 槽位健康（防 fastboot 停车，见下节）：`qbootctl` 看当前槽
  `Successful: 1`；开机由 `qbootctl-meizu.service` 自动标记。

## 重启落 fastboot（ABL 槽位重试耗尽）— 救机与根修

**现象**：重启若干次后设备停在 fastboot，`fastboot getvar slot-retry-count:b`
= 0、`slot-successful:b = no`。

**原理**：ABL 的启动重试计数记在 boot_x 的 GPT 属性位（不在 misc）。每次开机
由 OS 侧把当前槽标记 successful；缺标记时每次重启烧一次尝试，累计 ~7 次耗尽
即落 fastboot 兜底。本盘自带 `qbootctl-meizu.service`（qbootctl `-m`，开机
oneshot）自动标记，正常不会复发；只刷了旧盘或手动停了该 unit 才会遇到。

**救机**（设备已在 fastboot）：
```bash
fastboot getvar current-slot      # 确认槽位（现役 b）
fastboot set_active b && fastboot reboot
```
`set_active` 把重试预算重置回满，正常起系统。**misc 勿动**——仅当
`set_active` 后仍循环落 fastboot 才按 nura FLASHING §6 阶梯清 misc。

**修后闭环判据**：起机后 `qbootctl` 应显示当前槽 `Successful: 1`；或下次
fastboot 里 `slot-successful:b = yes` 且 retry 回满。

## 双线互斥律（2026-10-12 事故新律，nura 侧实证）

**fastboot 单通道独占设备**：本线与 nura 线并行对同一设备下发 fastboot 会
互相污染分区且**无任何报错**——2026-10-12「卡 Mu 引导」事故根因即此（彼侧
全量三件重刷一次点亮 = boot 链 mu-r69/ESP v65/内核 r84 无罪的对照组）。

- 本线刷写一律走守门脚本（flock 互斥 + 排查他线 fastboot 进程 + 串行下发 +
  全程留痕 /tmp/zcode/flash-meizu.log）：

  ```bash
  post_process/flash-meizu.sh [--set-active] [--reboot] 分区=镜像 [分区=镜像 ...]
  ```

- 跨线协调：**窗口互斥或串行**，刷前互相知会；裸 fastboot 直发 = 违律。
- boot 链件共享且由 nura 维护锚（boot_b = mu-r69、recovery_a = 现役 v65）：
  本线边界照旧**只刷 userdata**；仅在互踩存疑时补刷 recovery_a（v65 =
  work/esp-recovery-v65.img，sha 463efc45）重锚，不碰 boot_b。

## 电源与睡眠

- **短按电源键** = 睡眠（fake-suspend：面板熄、音频静、radio 软阻断）；
  再短按 = 唤醒。真 s2idle 在本 SoC 上会睡死（rtc-efi 废件），勿在
  设备档案里改回 `s2idle`。
- **长按** = Steam 电源菜单（重启/关机）。
- 关机也可以走 SSH：`systemctl poweroff`。

## 回滚（30 秒锚）

```bash
fastboot flash userdata <任意旧 rootfs.img>   # Debian 盘 / pmOS 盘 / 本盘旧版
fastboot reboot
```

boot / ESP / recovery 从不被触碰。注：回 Debian 旧盘后如遇内核模块不匹配，
把 nura 配对 apk 重解进 `/usr/lib/modules/` 即可（SSH/NCM 不受影响）。

## 已知限制

- 真实 s2idle 睡眠不可用（SoC/内核限制，fake-suspend 全链已验证）；
  hibernate 不支持。
- Decky 插件加载器默认停用（首启不稳）；需要时在设备上 unmask
  `plugin_loader.service`。
- m2381 无内置手柄，`armada-controller-type` 服务默认停用是正常现象
  （接手柄后手动 apply）。
