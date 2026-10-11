# system_files — m2381 设备覆盖层（真身）

本目录 = 灌进 armada rootfs 的 m2381 覆盖层（构建时 rsync 进镜像根）。
上游同位目录 = armada-sheng 的 system_files/。

- etc/modprobe.d/       PAS/geni 黑名单（硬定律：remoteproc/geni 冷插拔致死）
- usr/lib/meizu20/      音频编排三件+触屏+PAS 定向绑定脚本、GPU devfreq 看护
                        （gpu-ondemand-watch）+ GPU idle 频率管控（gpu-idle-damp：
                        无游戏+无输入 90s → 钳 max 220MHz 治待机温热，见下）
- usr/lib/systemd/      meizu 编排单元、看门狗放宽 drop-in、journald sync
- usr/share/alsa/ucm2/  MEIZU20 UCM2
- usr/lib/armada/devices/meizu-meizu20.conf   设备档案（竖屏 right + fake suspend）
- usr/libexec/armada/device-env 的 meizu 行
- usr/local/bin/qbootctl + etc/systemd/system/qbootctl-meizu.service
                        A/B 槽位开机标 successful（治 ABL 重试耗尽落 fastboot；
                        linux-msm v0.2.2 aarch64 现编，musl 版不可用于 Fedora 底）
- etc/systemd/system/   NCM gadget / usb0-ip / GPU 看护 / wireplumber 踢卡
- etc/polkit-1/rules.d/ suspend 放行（fake-suspend 链入口）

**GPU idle 管控双件协同（2026-10-11 起）**：gpu-idle-damp 三态机（game/active/idle，
evdev 直读输入，/proc 容器标记判游戏）在 idle 时钳 `max_freq=220` 并立
/run/sm20-gpu-idle/clamped 旗标；gpu-ondemand-watch 见旗标让路（idle 冻结是本意，
勿当"钉死 220 病"重绑 governor）。两坑备忘：①grep 游戏标记必须括号防自匹配
（pressure-[v]essel），否则恒判 game；②输入管道禁用 dd 大口吞（空管 read() 无限
阻塞，状态机停摆）。

**RTC 用户态三件（sm20-rtc1-restore/save/time-wait cap）已撤（r81 起）**——
内核 HCTOSYS/SYSTOHC 已钉 rtc1（pm8xxx），r80 及以前的老腿才需要；勿回加。

**不在 git 的两样**（构建时从 nura apk 取，与 pmOS 线通用）：
- usr/lib/firmware/     （193MB，nura 固件 apk，kernel-m2381/BUILD.env 钉版；
                         布局：qcom/sm8550 + ath12k/WCN7850 + qca + cirrus）
- usr/lib/modules/      （内核腿，r81 apk 解出，见 kernel-m2381/）

Debian 时代防睡死三件（sm20-nosleep.conf / 两份 sleepmask tmpfiles）**故意
不在本树**——它们会 mask 掉 sleep/suspend.target，与 armada 的 fake-suspend
冲突（实机事故：电源键睡眠假死，见 docs/M2381-ARMADA-PORT-20261011.md §4.8）。
