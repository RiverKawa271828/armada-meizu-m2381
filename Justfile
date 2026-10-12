# armada-meizu-m2381 构建入口（对齐 armada-sheng 的 Justfile 风格）
# 全部构建动作必须在宿主 root 下跑（loop/mount 需要内核权限；
# 容器/agent 环境用 systemd-run --user + sudo 通道）。

REPO := `git rev-parse --show-toplevel`

# 默认列表
default:
    @just --list

# 取上游 rootfs（八分卷→校验→合并，已有且校验过则跳过）
[group('build')]
fetch-base:
    sudo bash "{{REPO}}/build_files/fetch-base.sh"

# 取钉子版内核腿 apk（本地已知路径或 KERNEL_APK_URL，sha256 门禁）
[group('build')]
fetch-kernel:
    bash "{{REPO}}/kernel-m2381/fetch.sh"

# 全流程出盘：适配 → 收缩 → 31 项点验（宿主 root）
[group('build')]
adapt:
    sudo bash "{{REPO}}/build_files/build.sh"

# 只跑成品点验（不重建）
[group('build')]
verify image="work/meizu-meizu20-armada-r84.img":
    sudo bash "{{REPO}}/post_process/verify-m2381-image.sh" "{{image}}"

# 刷机提示（fastboot 动作永远人工执行）
[group('flash')]
flash-hint:
    @echo "1) 设备: reboot bootloader（SSH: reboot bootloader / 或 按键组合）"
    @echo "2) fastboot flash userdata {{REPO}}/work/meizu-meizu20-armada-r84.img"
    @echo "3) fastboot reboot   # 首启 growfs 自长满；插线 ssh root@172.16.42.1"
