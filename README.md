<h1 align="center">Armada (meizu-m2381)</h1>

<p align="center"><strong>面向魅族 20 的 SteamOS 类 Linux 系统</strong></p>

<p align="center">
  在魅族 20(<code>m2381</code>,SM8550)上运行
  <a href="https://github.com/armada-os/armada">Armada</a>——Steam、FEX、Proton 与
  Game Mode,直接刷入设备内部存储,<strong>不含 bootc/OSTree/OTA</strong>。
</p>

<p align="center">
  <a href="LICENSE.md"><img alt="GPL-2.0-or-later license" src="https://img.shields.io/badge/license-GPL--2.0--or--later-18181a?style=flat"></a>
  <a href="https://github.com/code002-2/armada-sheng"><img alt="upstream" src="https://img.shields.io/badge/fork%20of-armada--sheng-18181a?style=flat"></a>
</p>

> [!WARNING]
> **本项目为试验项目,仅供娱乐。** 安装需要**已解锁的 bootloader**,并会刷写设备分区——
> 可能导致设备变砖、分区损坏或数据丢失,**请先备份数据**。移植者只在魅族 20
> (m2381)一台设备上验证过,不承诺任何设备上的可用性与安全性。

> [!NOTE]
> 本仓是 [code002-2/armada-sheng](https://github.com/code002-2/armada-sheng)
> (小米平板 6S Pro 版 Armada)的 **m2381 适配分叉**。内核与固件料件来自
> **pmOS meizu20 内核线(nura)**,与 pmOS rootfs **通用同一套**——到该线取最新版,
> 配合本仓出盘的 Armada rootfs 刷入即可。

## 关于本构建

与上游 armada-sheng 相比的刻意差异:

1. **boot 链 = 原厂 recovery_a 分区上的 ESP(EFI stub)。** 内核以 EFI stub 方式从
   recovery_a 启动,cmdline 烤死 `root=/dev/sda22`;**boot_a/boot_b 全程不碰**,
   回滚 = 重刷 userdata。上游的 ABL/boot.img 链与本仓的容器构建链
   (Containerfile/packages/kernel-sheng 等)**停用仅存档**。
2. **设备内核来自 pmOS meizu20 线(nura)**,`7.3.0-rc6`(r80,#81),async flip 已启用;
   模块与 ESP 内核逐字节配对(构建门禁强制)。上游 ianchb/sheng-7.2.2 内核弃用。
3. **设备覆盖层 = system_files/**:触屏(Goodix GENI 定向绑定)、音频编排
   (WCD9385 三件套)、NCM gadget 调试通道、PMIC RTC(rtc1)时间持久化、
   fake-suspend、GPU devfreq 看护、polkit 放行——全部构建期内置,不留裸态。
4. **上游 zstd squashfs → gzip**:当前内核缺 `CONFIG_SQUASHFS_ZSTD`,FEX x86 腿的
   两个 sqsh 在构建时重压为 gzip(已向内核线提需求,落地后换回)。

其余均与 Armada 相同:ARM64 Steam(FEX + Proton)、Game Mode、KDE Plasma 桌面、
Waydroid,以及 Armada 设备服务(InputPlumber、powerbuttond、steamos-manager 等)。

### m2381 已实测可用的功能

| 组件 | 状态 |
|---|---|
| 启动(recovery_a ESP EFI stub → 容器根) | ✅ 可进入 Steam |
| Game Mode + 手柄进游戏(InputPlumber → deck-uhid 虚拟 Deck 手柄) | ✅ |
| guide 键 QAM / 菜单↔游戏往返 | ✅ |
| 触摸屏(Goodix,GENI 定向绑定) | ✅ |
| 音频(WCD9385 编排三件,PipeWire sink) | ✅ |
| 电源键睡眠/唤醒(fake-suspend:面板熄→pmic_pwrkey→亮) | ✅ |
| WiFi(ath12k)/ 蓝牙(BLE HOG,uhid 自载) | ✅ |
| x86 游戏(FEX,gzip squashfs 腿) | ✅ |
| 调试通道(NCM gadget `172.16.42.1` + sshd + 自动登录) | ✅ 构建期内置 |
| 真实 s2idle 睡眠 / hibernate | ❌ SoC 限制(fake-suspend 代替 / 无) |

## 构建可刷镜像

宿主 Linux(root;loop/mount 需要内核权限):

```bash
just fetch-base     # 上游 armada-sheng 成品 rootfs(下载/校验/合并,已有则跳过)
just fetch-kernel   # nura r80 内核 apk(sha256 门禁;见 kernel-m2381/BUILD.env)
sudo bash build_files/build.sh   # 适配 → 收缩 → 21 项点验 → work/*.img
```

- `system_files/` = m2381 设备覆盖层(git 真身);固件(193MB)不入 git,构建时从
  nura 固件 apk 提取(与 pmOS 线通用)。
- 版本钉子(内核/固件 apk 的 sha256、腿配对哈希)全部在 `kernel-m2381/BUILD.env`;
  升级 nura 新版料件 = 改该文件 + 换配对 ESP。
- 成品点验独立可跑:`just verify`。

## 刷写

只写 **userdata** 一个分区,boot/ESP/recovery 永不触碰:

```bash
fastboot flash userdata work/meizu-meizu20-armada-r80.img
fastboot reboot
```

首启自动扩容到全盘;插 USB 线 `ssh root@172.16.42.1`(初始密码 123456,登录后请改)。
回滚 = `fastboot flash userdata <任意旧 rootfs>`。完整流程(前提/首启预期/调试/
睡眠/已知限制)见 [刷写指南](docs/flashing-meizu-m2381.md)。

## 开发

- [docs/README.md](docs/README.md) — 文档索引(移植正典/上游考据/内核协作/决策史)
- [docs/flashing-meizu-m2381.md](docs/flashing-meizu-m2381.md) — 刷写与运维
- [AGENTS.md](AGENTS.md) — 仓库结构图 + 会话级现态速记(开发者从这里接续)
- `legacy/` — 冻结的 Debian 管线归档;上游构建链(Containerfile 等)停用存档

## 致谢

- [Armada](https://github.com/armada-os/armada) 与
  [armada-sheng](https://github.com/code002-2/armada-sheng) —— 底盘与构建流形态
- **pmOS meizu20 线(nura)** —— 内核、固件、boot 链(与本仓料件通用)
- [postmarketOS](https://postmarketos.org/) pmaports —— meizu20 设备包原型
- ROCKNIX / [Bazzite](https://bazzite.gg/) —— 上游设备适配与镜像工具源头

## 许可

本仓原创内容以 **GPL-2.0-or-later** 提供,成分溯源见
[LICENSE.md](LICENSE.md)。镜像内 Steam 客户端为 Valve 专有软件,按上游 Armada
同款口径分发。
