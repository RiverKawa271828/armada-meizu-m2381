# system_files — m2381 设备覆盖层（真身）

本目录 = 灌进 armada rootfs 的 m2381 覆盖层（构建时 rsync 进镜像根）。
上游同位目录 = armada-sheng 的 system_files/。

- etc/modprobe.d/       PAS/geni 黑名单（硬定律：remoteproc/geni 冷插拔致死）
- usr/lib/meizu20/      音频编排三件+触屏+PAS 定向绑定脚本、GPU devfreq 看护
- usr/lib/systemd/      meizu 编排单元、看门狗放宽 drop-in、journald sync
- usr/share/alsa/ucm2/  MEIZU20 UCM2
- usr/lib/armada/devices/meizu-meizu20.conf   设备档案（竖屏 right + fake suspend）
- usr/libexec/armada/device-env 的 meizu 行 + sm20-rtc1-restore.sh
- etc/systemd/system/   NCM gadget / usb0-ip / GPU 看护 / wireplumber 踢卡 /
                        RTC restore+save / time-wait 限时
- etc/polkit-1/rules.d/ suspend 放行（fake-suspend 链入口）

**不在 git 的两样**（构建时从 nura apk 取，与 pmOS 线通用）：
- usr/lib/firmware/     （193MB，nura 固件 apk，kernel-m2381/BUILD.env 钉版；
                         布局：qcom/sm8550 + ath12k/WCN7850 + qca + cirrus）
- usr/lib/modules/      （内核腿，r81 apk 解出，见 kernel-m2381/）

Debian 时代防睡死三件（sm20-nosleep.conf / 两份 sleepmask tmpfiles）**故意
不在本树**——它们会 mask 掉 sleep/suspend.target，与 armada 的 fake-suspend
冲突（实机事故：电源键睡眠假死，见 docs/M2381-ARMADA-PORT-20261011.md §4.8）。
