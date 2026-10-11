# issue 草稿 — armada-sheng 上游问询（2026-10-11 定稿，待用户过目后发）

> 发帖目标：code002-2/armada-sheng issues 区。原计划问三症状（QAM/往返/BT 手柄），
> 但 m2381 侧三者已全绿，改为**报捷 + 两个技术问询**。未发原因：内容较原计划
> 有实质变化，发帖是公开动作，等用户点头。

---

标题：m2381 (SM8550) 移植报告 + 两个问题：A/B slot successful 标记与 FEX zstd squashfs

你好，我们把你 v1.2 的 sheng-flashable 底盘移植到了魅族 20（m2381/SM8550，
container-export 单分区 ext4 路径同款），实机已日用：gamescope 会话、Steam
手柄（InputPlumber→deck-uhid）、QAM、菜单↔游戏往返、电源键睡眠唤醒、音频
全部正常——Layer 兼容性做得非常好，感谢。

两个问题想请教 sheng 实机情况：

**1) A/B 槽位 successful 标记**
我们在 Snapdragon A/B 设备上复现了一个通病：rootfs 里没有 mark-boot-successful
机制时，ABL 的启动重试计数（boot_x GPT 属性位）每次重启烧一次，~7 次耗尽后
设备落 fastboot。你的镜像里是用什么标记 successful 的？（qbootctl？bootc/bootupd
附带？还是 sheng 的 ABL 不走 retry 计数？）我们目前是移植了 pmOS 的 qbootctl
（linux-msm/qbootctl v0.2.2，`-m` oneshot unit）解决。

**2) FEX 的 zstd squashfs 与内核 SQUASHFS_ZSTD**
RootFS 的 ArchLinux/ArmadaMesa `.sqsh` 是 zstd 压缩，宿主内核需要
CONFIG_SQUASHFS_ZSTD=y 才能挂。我们第一块自编内核没开这个、首启 FEX 挂载
必败；你的 Fedora 底盘内核是自带 zstd 的吗？（顺带：如果上游有兴趣，可以
在文档里标注这个内核依赖。）

再次感谢，m2381 适配层我们整理后会开源出来。

---

（发帖用 gh：`gh issue create -R code002-2/armada-sheng -t <标题> -F <本文件正文段>`）
