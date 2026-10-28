# Mu ABL fastboot 大体积刷写后命令环僵死（→ 强启撕裂写）— bug 报告

> 整理：2026-10-28（steamos-meizu20 线）。状态 = **待用户过目后转交 nura / 上游会诊，
> 未发 issue**。我方规避 SOP 已固化生效（见 §5）。
> 事故叙事全量 = docs/M2381-CARDMU-AUDIT-20261012.md（§9 对照定谳）；本文是该档案
> 的 bug-face 抽取，只含可复现事实与排查入口。

## 0. 一句话

魅族 20（m2381）上，Mu ABL（boot_b UEFI 内 fastboot 实现）在 **14.6G 级 userdata
sparse 刷写正常完成（逐块 OKAY）之后偶发命令环僵死**；宿主侧表现为 set_active 无
应答、getvar/reboot「假应答」。此态本身无害，**危害在用户被迫长按电源强启**：
UFS 写缓存未 flush → ext4 撕裂写（两轮事故撕裂清单逐文件一致）。

- 域：**Mu-Silicium（boot_b）** —— 本报告只含宿主侧观察，设备侧内部状态无从取证
  （无 UART 采集，强启后现场已被覆盖）。
- 事故时点 boot 链：mu-r69 boot_b + recovery_a v65（内核 r84/#85）；与 ESP/内核
  版本无关联证据（对照轮换镜像不换腿照撕）。
- 严重度：高（静默数据损坏路径），但可规避；触发概率样本内 = 脚本刷 2/3 中招。

## 1. 现象（宿主侧观察）

- `fastboot flash userdata`（14.6G sparse，分块下载）全程正常：逐块 OKAY。
- 其后 `fastboot set_active b` 挂住 ≥6 min 无真应答（正常 <1 s）。
- 此后 `getvar` / `reboot` **假应答**：宿主 fastboot 显示 OKAY，设备侧不动作
  （不重启、不枚举）。
- 脚本刷写（宿主 systemd-run 直跑 fastboot，非容器转发）三轮两中招；用户手动
  刷写一轮全程正常。**下发侧差异（时序/驱动路径）是否为触发条件 = 样本不足未定论**；
  僵死本体判定在设备侧 ABL（见 §2 收敛逻辑）。

## 2. 对照实验（2026-10-12，同一镜像三次刷写）

| 轮次 | 刷写方式 | 刷后重启 | 结果 |
|---|---|---|---|
| 1 | 脚本刷 v4 盘 | 僵死 → 长按电源强启 | boot#1 早期死亡，EXT4 撕裂（§3） |
| 2 | 同镜像重建后脚本重刷 | 再僵死 → 强启 | **撕裂清单与轮 1 逐文件一致** |
| 3 | 同镜像用户手动刷 | 正常重启 | 全绿零撕裂 |

**收敛**：镜像本体无罪（轮 3 全绿）、宿主刷写工具无罪（轮 1/2/3 同工具不同果）、
撕裂与「强启」强相关（轮 1/2 有撕、轮 3 无撕）→ 变量收敛于
**ABL 僵死态 + 非正常复位路径**。

## 3. 撕裂写证据链（危害实证）

- 首启 health 采样：dmesg `EXT4-fs error`（目录块校验和）+ tune2fs
  `Filesystem state: clean with errors`。
- 撕裂面：30+ 文件，其中 **13 个 Vulkan ICD/layer JSON 全灭**（base 构建期同批
  写入、物理相邻，一撕一串）→ 首启 `vkCreateInstance -9` → gamescope SIGABRT×4
  → armada takeover 回落 Plasma「黑屏」。
- **撕裂点确定性**：两轮撕裂清单完全一致 → 同一写入序下缓存截断点同位。
- 修法实证：kexec cmdline 去 `rw` + `fsck.mode=force` 修元数据（本盘 cmdline 带
  rw，systemd-fsck-root 条件恒不满足 = boot 期 fsck 从不跑，kexec fsck = 标准救机
  程序）+ base 盘逐字节 cmp 回填数据件 → boot#3 全绿。

## 4. 根因界定

- **实锤**：僵死本体在设备侧 ABL（§2 收敛）；强启 = 撕裂写的直接因果（UFS 写缓存
  未持久化）。
- **归因假说（未取证，供排查）**：大体积 sparse 下载收尾后，命令环失去调度 ——
  候选：USB bulk 传输完成回调悬挂 / 传输缓冲未释放 / 命令环线程饿死 / heap 耗尽；
  「假应答」提示宿主侧请求被 ACK 而设备侧状态机不再消费。
- **未定项**：①是否 sparse 特定块模式/传输时长触发（小体积刷写从未见僵死）；
  ②宿主下发侧时序是否为共因；③Mu 版本相关性（仅 mu-r69 时点观察）。

## 5. 我方规避 SOP（已固化：docs/flashing-meizu-m2381.md + post_process/post-flash-health.sh）

按序尝试，**强启是最后手段**：

1. `fastboot reboot` 重发一次（假应答后设备有概率已离队，先看 NCM 是否枚举）；
2. `fastboot continue`（若 Mu 支持 = 优雅继续启动，不走电源循环）；
3. 实在不行才长按电源强启 —— **强启后首启必跑** `post-flash-health.sh`：
   看 `Filesystem state`（"clean with errors" = 有撕裂）+ `vulkaninfo` Invalid
   JSON 计数（JSON 可读性 = 数据块健康代理，13-JSON 清单 = 首个报警器）。
4. 有伤处置 = 重刷一遍 userdata；或 kexec fsck + 原盘回填（AUDIT §9.3）。

## 6. 若转交：给维护者的排查入口（建议）

- **复现配方**：14G 级 sparse userdata `fastboot flash` → 完成后立即
  `getvar`/`set_active` 连发采样应答延迟；对照小体积（100M 级）刷写后同采样。
  脚本直跑 fastboot（宿主 systemd-run）提高命中率（样本 2/3）。
- **器材**：设备侧 UART 采 ABL 日志（我方无此件，强启后现场亦被覆盖）。
- **源码面**：Mu-Silicium fastboot（AndroidBootlib）命令环在大传输完成后的状态机
  —— transfer completion 回调路径 / 下载缓冲释放 / 命令分发循环的阻塞点。
- **候选加固**（防后果兜底）：flash OKAY 前显式 flush/sync；reboot 命令路径保证
  缓存落盘后再复位；命令环看门狗自恢复。（长按电源 = 硬件路径，防不了，只能靠
  前两者把「被迫强启」的概率打下去。）

## 7. 同域不同症区分（防混淆）

- **「重启落 fastboot」（槽位重试耗尽）**：ABL 的 slot successful 标记缺失 →
  tries 计数烧尽落 fastboot，GPT 属性位问题 —— 已由 qbootctl-meizu（mark
  successful 单元）根修，与本僵死**无关**。
- **卡 Mu 事故的「机制 A fs 写伤」** = 本 bug 的**后果**（撕裂写）；机制 B（GPT
  写坏）已排除、机制 C（电池）弱化 —— 见 AUDIT 档。
