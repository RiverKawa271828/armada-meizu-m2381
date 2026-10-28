# m2381 armada r85

魅族 20（m2381 / SM8550）的 SteamOS（Armada）**userdata 镜像**。

**刷机方法与 [nura 项目](https://github.com/RiverKawa271828/nura-meizu-m2381) 的教程完全相同，只是把 userdata 换成本 Release 的镜像。**

- boot / recovery 腿（ESP 内核）、内核 apk、固件 → 全部从 [nura 项目 Release r91](https://github.com/RiverKawa271828/nura-meizu-m2381/releases/tag/r91) 获取（**内核 apk r91 + ESP v71 与本镜像逐字节配对，同一套 CI 件**）。
- 镜像 = 上游 [armada-sheng](https://github.com/code002-2/armada-sheng) v1.2 底盘 + r91 内核腿（**7.3.0 stable rebase，#92**）+ meizu 设备层；steam 客户端已预种，首启可离线进会话。

> **⚠ 本版起内核升 7.3.0（模块目录改名）——ESP 必须同轮换 v71**： userdata（r85，模块 7.3.0）+ recovery_a（v71，内核 r91）两件一起刷。只刷 userdata 不动旧 ESP（v65）会起旧内核加载不到模块 → WiFi/触屏/NCM 全灭。在役 r84 机升级 = userdata + recovery_a 两腿同轮（数据在 userdata，重刷即清，先备份）。

## 使用

```bash
# 合并切片并解压
cat meizu-meizu20-armada-r85.img.xz.?? > meizu-meizu20-armada-r85.img.xz
xz -d meizu-meizu20-armada-r85.img.xz            # 得 14.6G 裸 ext4 镜像
sha256sum -c SHA256SUMS                          # 切片校验

# 按 nura 教程刷写，userdata 用这个（recovery_a 用 nura r91 的 esp-recovery-v71）：
fastboot flash userdata meizu-meizu20-armada-r85.img
```

首启：NCM `ssh root@172.16.42.1`（密码 `123456`，**首启后请改**）；时区默认 UTC（`timedatectl set-timezone` 自改）；首启自动扩容全盘。其余注意事项（ABL 强启撕裂写规避——大体积刷完后 fastboot 无响应勿长按电源强启、steam 首启弹窗重启即过）见本仓 [docs/flashing-meizu-m2381.md](https://github.com/RiverKawa271828/armada-meizu-m2381/blob/main/docs/flashing-meizu-m2381.md)。

适配层源码：本仓（GPL-2.0-or-later）；内核源码见 nura 项目（GPL）。
