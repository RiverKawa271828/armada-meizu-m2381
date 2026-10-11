> ⚠ 已归档（2026-10-11）：Debian 线 gamescope 点火手册（armada 线下仅作考古）。现行文档见 docs/README.md 索引。

# M2381 GAMESCOPE 点火手册（真掌机模式）

> 排定 2026-10-10 晨。目标 = gamescope standalone DRM backend 当会话合成器 +
> steam -gamepadui 跑其内 = 真 Deck 架构。kwin 路线的覆盖层回程死穴
> （AGENTS 晨场条目 ⑧）在此架构下不存在。旧判词「msm 只吃线性」已翻案作废
> （AGENTS ⑥：grep state 探针无效，IN_FORMATS 从来都在）。

## 验收判据

1. gamescope 作为会话合成器点亮 1080x2400@120 横屏；
2. steam -gamepadui 跑其内；
3. **home 键覆盖层原生工作（menu→game 回程不再失灵）**——本轮 kwin 路线死穴的直接验收；
4. 每游戏缩放/限帧可用。

## 前置在位清单（2026-10-10 实测）

- 内核 #79（r78，ESP v59）在役；IN_FORMATS 实锤：drm_info 10 plane 全带 blob，
  modifiers 含 QCOM_COMPRESSED（0x500000000000001），kwin 正用 UBWC 扫描出图。
- gamescope 3.16.22+ds-1~bpo13+1（/usr/games/gamescope，trixie-backports）。
- **turnip 在位**：`/usr/share/vulkan/icd.d/freedreno_icd.json` +
  `/usr/lib/aarch64-linux-gnu/libvulkan_freedreno.so`（mesa-vulkan-drivers 25.0.7-2；
  trixie-backports 有 mesa 26.1.6 可选升级，对齐 pmOS 26.2 世代）。
- kmscube 已装（/usr/bin/kmscube）。
- steam stable 1791415817 整包在役（r78 镜像已播种同版本）。
- 上游参照：`work/ref/upstream-10-graft-bbc6065.sh`（sheng 上游 10-graft.sh 原件；
  11.6 节 = gamescope 会话解耦 SteamVR + VK_ICD 钉 freedreno；11.7 = jupiter-dock-updater 桩）。

## nura 回信要点（2026-10-10，四答全实据）

1. **零实跑记录可抄**：pmOS 从未跑过 gamescope；SM8550 世界唯一触碰 = 我们自己当年那五轮
   EINVAL。机制上无拦路虎：`VK_EXT_physical_device_drm` 自 mesa 22.2（2022-07）、
   `VK_EXT_image_drm_format_modifier` 更早。
2. **DPU 吃 GPU UBWC = kwin 现量铁证**（a740 产 0x500000000000001 FB 正在被扫描输出）。
   QCOM_COMPRESSED 是裸令牌不带版本参数，UBWC 版本/macro-tile 是 SoC 代隐式属性，
   同机生产/消费天然匹配。⇒ EINVAL 高发类 = **UBWC 对齐约束**（plane x/y offset 的
   macro-tile 对齐、尺寸/格式须在该 plane IN_FORMATS 列表）或 **gamescope/turnip 的
   分配-导入 flag 组合**——当年那次大概率在后者。
3. **modetest 干不了 modifier**（`-P` 只走 AddFB2 隐式 LINEAR + dumb buffer，无 modifier
   语法；核自 libdrm 主干 modetest.c）——黄金分界换三件套，见下节。
4. **mesa 对照**：pmOS 现役 26.2.4-r1（Alpine edge，纯 GL 未装 vulkan）；Debian 25.x/26.x
   均含全部所需扩展。已知雷三件：lavapipe 抢枚举（钉设备）、gamescope 要 DRM master +
   logind seat 激活会话、ARM64/异形面板必须显式 `-W/-H/-r` 别让它猜。

## 黄金分界三件套（点火失败先跑这个）

```bash
# ① LINEAR/mode 腿：核对 connector 名与实际刷新率，再单发静态 flip
modetest -M msm                      # 列 connector/crtc/mode
modetest -M msm -s <conn>@<crtc>:1080x2400@<实际刷新率>
#    过 = KMS/模式链路 OK（此腿只证线性）

# ② modifier 腿：kmscube GBM 协商（freedreno GL+GBM = kwin 同款路径）
kmscube -D /dev/dri/card0 -g
#    另开 shell 看 modifier 是否协商出 UBWC：
grep -A3 modifier /sys/kernel/debug/dri/0/state
#    gbm 总选 LINEAR 也不算翻车——内核判据回退 kwin 现量铁证 + drm_info blob

# ③ 静态 drm_info（已做过：10 plane 全带 IN_FORMATS blob）
```

判读：①②过而 gamescope 败 ⇒ 锅在 gamescope/turnip 用户态；②败 ⇒ 内核侧
（kwin 现量证词在，基本到不了这）。

## 取证协议（点火失败当场做，别凭印象记）

```bash
echo 0x14 > /sys/module/drm/parameters/debug   # KMS+ATOMIC 类目
# …复现失败…
dmesg | grep -iE "atomic|reject|failed"        # drm_atomic check failed 打印
#   = 哪个 plane / 哪个属性被拒，EINVAL 真因就在这
echo 0 > /sys/module/drm/parameters/debug      # 完事必须归零！
```

⚠ drm.debug 洪泛冲环缓冲 = nura 在册教训，取证完立刻关。
gamescope 侧加 `-v` 落日志。

## 点火命令（草案）

前提：**停 SDDM/kwin**，由 logind TTY 会话起（gamescope 要 DRM master + seat）：

```bash
systemctl stop sddm
# tty1（steamos autologin）或 ssh + chvt：
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.json
export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/freedreno_icd.json
export GAMESCOPE_FORCE_INTERNAL=1        # 上游经验：强制内屏，防走偏
gamescope --backend drm -W 1080 -H 2400 -r 120 --fullscreen --xwayland-count 1 \
  --prefer-vk-device <turnip设备号> -- steam -gamepadui
```

- `--prefer-vk-device`（老版 `--vknr`）钉 turnip，防 lavapipe 抢枚举；
  设备号先 `vulkaninfo --summary` 或 gamescope -v 日志里看。
- 上游 11.6 节权威改法 = Frame 底包的 /usr/lib/steamos/gamescope-session 被
  sed 改 `--backend openvr`→`--backend drm`；我们 Debian 无此底包件，
  直接自己的命令行，旗标以后从实跑回填。

## 通过后落地件（graft 固化清单）

- gamescope-session 会话项（照 steamos-session.desktop 模式；或 systemd user 单元：
  gamescope-session.service/target，PartOf=graphical-session.target，
  Wants=steam.service——上游 11.6 节同构，SteamVR 那串不要）。
- jupiter-dock-updater 桩（上游 11.7：缺失 = Steam「软件更新」报错；`--check` 退出 7 = 最新；
  参照 work/ref/upstream-10-graft-bbc6065.sh:903）。
- /tmp/.X11-unix sticky 位（上游实测：权限不对时 X 客户端连不上；graft 已有此件，核对即可）。
- 会话切换环境清理：unset QT_QPA_PLATFORM GAMESCOPE_WAYLAND_DISPLAY
  GAMESCOPE_SESSION_TARGET（上游：gamescope 残留 env 会把别的会话带沟里）。
- kwin/Plasma 保留为 SDDM 第二会话项（桌面兜底 + gamescope 黑屏时的逃生门）。

## 出参记录（2026-10-10 点火成功回填）

**结果：✅ 点火成功。** 真 Deck 架构在魅族 20 上点亮：gamescope standalone（master 自建）+
steam -gamepadui，横屏 2400x1080@120，**flip 零失败**，**UBWC（QCOM_COMPRESSED）直接扫描
输出**（debugfs 实证：plane49 gamescope-xwm XR30 modifier=0x500000000000001，kwin 之外
第二个 UBWC 消费者；vsync 中断持续）。验收 #1/#2 达成；#3（home 键覆盖层）#4（每游戏
缩放/限帧）待用户手柄实测——本架构下覆盖层是 gamescope 自管，kwin 死穴理应不存在。

最终命令行（= steamos-gamescope-session v4，设备 /usr/local/bin/）：

```bash
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.json
export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/freedreno_icd.json
export GAMESCOPE_FORCE_INTERNAL=1
export GAMESCOPE_DISABLE_ASYNC_FLIPS=1     # msm 无 async flip（cap=0）
export GAMESCOPE_LIFTOFF_CACHE_DISABLE=1   # liftoff 失败布局缓存保险丝
/usr/local/bin/gamescope --backend drm --force-composition-rotation \
  --force-orientation right -W 1080 -H 2400 -r 120 --fullscreen \
  --xwayland-count 1 -- /usr/local/bin/steam-arm -gamepadui -steamos3
```

点火路上的五层洋葱（每层都吃掉一批旧假设）：

1. **msm 无 async/immediate flip**（DRM_CAP_ATOMIC_ASYNC_PAGE_FLIP=0，gamescope 开场报
   "Immediate flips are not supported by the KMS driver"）→ GAMESCOPE_DISABLE_ASYNC_FLIPS=1。
   必要但不充分——刷屏照旧。
2. **EINVAL 根本没到内核**：strace 实证 flip 刷屏期 **零 MODE_ATOMIC ioctl**，EINVAL 是
   gamescope/libliftoff 用户态自造。⚠ 旧取证协议「drm.debug 当场抓 dmesg」在此类场景
   失效——拒绝发生在内核之前，dmesg 永远沉默。判别武器 = strace（ioctl 层）+
   libliftoff 补丁日志（分配层）。
3. **libliftoff 全拒 "incompatible properties"**：给 /lib/.../libliftoff.so.0 打
   BTI-safe 补丁（0x4830 liftoff_log_set_handler 首两条指令改 `bti c; ret`——原首指令
   BTI C 被裸 RET 覆盖会 SIGILL，arm64 PAC/BTI 教训）绕过 gamescope 的日志过滤，
   liftoff debug 直落 stderr → 层属性现形：**`rotation = 8`（ROTATE_270）**。
4. **msm DPU plane 只支持 rotate-0/180**（drm_info：{rotate-0, rotate-180, reflect-x,
   reflect-y}），且 gamescope 对竖屏面板（hdisplay<vdisplay）**自动 ORIENTATION_270**
   （`UpdateEffectiveOrientation` auto-detect），把旋转交给 KMS plane → 逐 plane 属性
   校验必挂 ×10 → needs_composition → -EINVAL。摘掉 --force-orientation 无用（auto-detect
   照样 270）。kwin 当年 Rotated270 能亮是因为它自己做合成旋转，不走 plane rotation。
5. **3.16.22 无合成器旋转兜底**：master 的 `g_uOutputRotation` / `--force-composition-
   rotation`（plane 转不动就在 GPU 合成里转）是 3.16.22 之后加的。→ **设备上自建
   master**（meson+ninja aarch64 原生，~分钟级）。依赖升栈全部 /usr/local 前缀：
   wayland 1.24.0、libdrm 2.4.129、libxkbcommon 1.8.1、pixman 0.46.2、
   wayland-protocols 1.47、luajit（openresty 版）、catch2；子项目 wlroots 0.20.2-master/
   libliftoff 0.5.0/vkroots/glm/stb 预克隆上设备（设备直连 GitHub 不稳，宿主中转）。
   `--force-composition-rotation` 一上 → rotation=0 出层 → liftoff 分配成功 → 内核
   flip 通过 → UBWC 上屏。

判词更新：
- 「lavapipe 抢枚举」：VK_ICD/VK_DRIVER_FILES 双钉 freedreno 即可，turnip 顺位选中
  （`vulkan: selecting physical device 'Turnip Adreno (TM) 740'`），无需 --prefer-vk-device。
- **UBWC 全链路实测通**：turnip 合成 → dma_buf → AddFB2(QCOM_COMPRESSED) → msm scanout ✓
  （nura 判词「同机生产/消费天然匹配」成立；TU_DEBUG=noubwc 不需要，勿再加）。
- nura「黄金分界三件套」没用上（锅在用户态属性校验，不在内核），但 modetest/kmscube
  腿保留为下次内核侧怀疑时的首查。

落地态（设备侧，graft 固化待下轮）：
- SDDM Autologin Session=steamos-gamescope.desktop → /usr/local/bin/steamos-gamescope-session
  （v4，秒退重试 ≤5 次防 sddm 重启竞态）；kwin 会话 steamos-session 保留为 SDDM 第二项
  （桌面兜底 + 逃生门），sm20-session 切换器两态均可用。
- master gamescope 栈快照 = 宿主 `work/cache/gamescope-master-stack.tar.gz`（16MB，
  /usr/local bin+lib+share 全量），graft 层打包直接用；设备 /root/gamescope-master-stack.tar.gz
  同源。Debian gamescope 3.16.22 仍在 /usr/games（弃用勿回退，无合成器旋转）。
- 诊断资产（设备）：/root/sm20-liftoff-probe.c（liftoff 分配矩阵探针，modetest 级别）、
  /root/sm20-plane-props.c、/root/libliftoff.so.0.bak（原件，已恢复）、
  /tmp/steamos-gamescope-session.log*（各轮日志）。
- 雷项备忘：给 arm64 .so 打 inline-hook 必须保留 BTI（首指令 bti c）+ 函数内 RET，
  裸 RET 覆盖 BTI 会在 PLT 间接跳转上 SIGILL（本轮实锤，gamescope 侧表现为
  "Illegal instruction" 秒退循环）。
- 待办：①steamos-select-branch / jupiter-dock-updater 桩（日志刷 not found，照上游
  11.7）；②graft 固化（层带 gamescope-master-stack.tar.gz + 会话件 + SDDM 默认切
  gamescope）；③验收 #3/#4 用户实测；④drm.debug 全程未开（零 ioctl 实锤后不需要）。
