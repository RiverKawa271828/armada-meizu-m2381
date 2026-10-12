# m2381 armada r84

魅族 20（m2381 / SM8550）的 SteamOS（Armada）**userdata 镜像**。

**刷机方法与 [nura 项目](https://github.com/RiverKawa271828/nura-meizu-m2381) 的教程完全相同，只是把 userdata 换成本 Release 的镜像。**

- boot / recovery 腿（ESP 内核）与 r84 内核 apk 也在本 Release Assets（`esp-recovery-v65.img.gz` / `linux-meizu-meizu20-*-r84.apk`，上游 nura 线构建）；固件 apk 从 [nura 项目 Release](https://github.com/RiverKawa271828/nura-meizu-m2381) 获取。
- 镜像 = 上游 [armada-sheng](https://github.com/code002-2/armada-sheng) v1.2 底盘 + r84 内核腿（7.3.0-rc6 #85）+ meizu 设备层；steam 客户端已预种，首启可离线进会话。

## 使用

```bash
# 合并切片并解压
cat meizu-meizu20-armada-r84.img.xz.?? > meizu-meizu20-armada-r84.img.xz
xz -d meizu-meizu20-armada-r84.img.xz            # 得 14.6G 裸 ext4 镜像
sha256sum -c SHA256SUMS                          # 切片校验

# 按 nura 教程刷写，userdata 用这个：
fastboot flash userdata meizu-meizu20-armada-r84.img
```

首启：NCM `ssh root@172.16.42.1`（密码 `123456`，**首启后请改**）；时区默认 UTC（`timedatectl set-timezone` 自改）；首启自动扩容全盘。其余注意事项（ABL 强启撕裂写规避、steam 首启弹窗重启即过）见本仓 [docs/flashing-meizu-m2381.md](https://github.com/RiverKawa271828/armada-meizu-m2381/blob/main/docs/flashing-meizu-m2381.md)。

适配层源码：本仓（GPL-2.0-or-later）；内核源码见 nura 项目（GPL）。
