# armada-meizu-m2381

**Armada（SteamOS-like）for 魅族 20 / Meizu 20（m2381 · SM8550）**

English: An [Armada](https://github.com/armada-os/armada) adaptation for the Meizu 20
(Snapdragon 8 Gen 2). We keep the vendor's fastboot-only model: the mainline kernel
(pmos-meizu line) boots as EFI stub from the recovery partition, and an upstream
Armada container rootfs is adapted into a single-partition ext4 `userdata` image —
no bootc/OTA, reflash-to-upgrade.

> ⚠ 文档整理中（发布前会补英文全文）。以下为现状速览。

## 实测状态（2026-10，r80 内核 + armada v1.2 底盘）

| 功能 | 状态 |
|---|---|
| gamescope 会话 + Steam Game Mode（`-gamepadui -steamos3 -steampal -steamdeck`） | ✅ |
| 手柄进游戏（InputPlumber → deck-uhid 虚拟 Deck 手柄 28DE:12F0） | ✅ |
| guide 键 QAM / 菜单↔游戏往返 | ✅ |
| 音频（WCD9385 编排三件 → PipeWire sink）/ 触摸（Goodix 定向绑定） | ✅ |
| 电源键睡眠/唤醒（fake-suspend：面板熄→pmic_pwrkey→亮，全链） | ✅ |
| WiFi（ath12k）/ 蓝牙手柄（BLE HOG 需 uhid，已自载） | ✅ |
| x86 游戏（FEX，gzip squashfs 腿） | ✅ |
| 调试通道（NCM gadget 172.16.42.1 + sshd + 自动登录） | ✅ 构建期内置 |
| 真实 s2idle 睡眠 / hibernate | ❌ SoC 限制（fake-suspend 代替 / 无） |

## 布局

```
build_files/    构建流：build.sh（主适配）+ fetch-base.sh（上游 rootfs 取件）
system_files/   m2381 设备覆盖层（设备档案/编排单元/黑名单/UCM/NCM/RTC/polkit）
kernel-m2381/   nura 线料件钉子（内核+固件 apk 的 sha/门禁；与 pmOS 线通用）
post_process/   finalize（收缩对齐）/ verify（21 项离线点验）
docs/           移植全程工作文档（PORT / RECON / RELAY …）
legacy/         冻结线归档（Debian 管线 / 会话件）
```

## 出盘（宿主 Linux，root）

```bash
just fetch-base && just fetch-kernel   # 或手动放料
sudo bash build_files/build.sh         # 适配 → 收缩 → 21 项点验 → work/*.img
just verify                            # 单独复核成品
```

料件（内核 apk / 固件 apk）来自 nura 的 pmOS meizu 线，**与 pmOS rootfs 通用**；
版本与 sha256 钉在 `kernel-m2381/BUILD.env`，公开下载链接待钉版后补。

## 刷机（只动 userdata）

前提：解锁 BL + recovery_a 已刷 nura 线配对 ESP（EFI stub，cmdline `root=/dev/sda22`）。

```bash
fastboot flash userdata work/meizu-meizu20-armada-r80.img
fastboot reboot
```

首启自动扩容到全盘；插 USB 线 `ssh root@172.16.42.1`（初始密码 123456，登录后请改）。
回滚 = `fastboot flash userdata <任意旧 rootfs>`，boot/ESP/recovery 永不触碰。

## Credits

- [armada-os/armada](https://github.com/armada-os/armada) 与
  [code002-2/armada-sheng](https://github.com/code002-2/armada-sheng) —— 底盘（GPL-2.0-or-later）
- pmOS meizu20 内核/设备线（nura）—— 内核腿、固件、boot 链
- ROCKNIX / Bazzite —— 上游设备适配与镜像工具源头
- 本仓新增内容以 GPL-2.0-or-later 提供，见 LICENSE.md
