# m2381 内核增强件判词（gamescope 点火线 → 主项目 pmOS/nura 内核线）

> 立 2026-10-10 晨（gamescope 点火当日收口）。出处 = 本仓
> docs/M2381-GAMESCOPE-IGNITION.md 出参五层洋葱 + nura 侧聊判词回话（用户转告）。
> 格式照 M2381-SOUND-REQ。用途 = 下个会话直接对接 nura 内核轮（#80+），
> 缺件清单/工作量/顺序/接入开关全在此，无需考古。

## 0. 背景（一句话）

真掌机架构（gamescope standalone + steam -gamepadui）已在 m2381 点火成功，但为绕开
msm DPU 两个能力缺口，用户态挂了两个补偿开关。内核侧补齐后即可撤除，并解锁
gamescope 原生低延迟路径。另附一个 trivial 缺件（uhid）。

## 1. 缺件清单（按 nura 排程顺序）

### 1.1 async flip（nura 排程：先行，中件、mdp5 参照、纯增益）

- **现状**：`DRM_CAP_ATOMIC_ASYNC_PAGE_FLIP = 0`（drm_info 实测），gamescope 开场报
  "Immediate flips are not supported by the KMS driver"，低延迟 immediate flip 路径全关。
- **用户态补偿**（会话件 v4 在役）：`export GAMESCOPE_DISABLE_ASYNC_FLIPS=1`。
- **接入开关（我方承诺，内核落地即撤）**：会话脚本
  /usr/local/bin/steamos-gamescope-session 撤除该行；撤除后 gamescope 自动走 async。
- **我方承诺的验证平台**：async flip 的 mid-frame 撕裂/竞态轮 = m2381 实机当试验田
  （nura 明确"须上机验"）。点火一轮 + 回传 flip 行为实测 = #80+ 内核轮回归项。

### 1.2 inline rotation / plane rotate-90（nura 排程：排后不弃，等 kalama SDE catalog 收割真值）

- **现状**：msm DPU plane rotation 只声明 {rotate-0, rotate-180, reflect-x, reflect-y}
  （drm_info 实测）；gamescope 对竖屏面板要求 rotate-270 → libliftoff 逐 plane 属性校验
  必挂（详见 ignition 手册出参第 4 层）。
- **用户态补偿**（会话件 v4 在役）：`--force-composition-rotation`（GPU 合成器里旋转，
  master 专属；Debian 3.16.22 无此能力，勿回退）。
- **接入开关（我方承诺，内核落地即撤）**：撤除 `--force-composition-rotation`——master
  的 `bScanoutCanRotate` 探测会自动切回 plane 旋转（drm 挂钩自动生效，无需其他改动）。
- **我方承诺的验证平台**：rotate-90 的 RGB/UBWC × rot 真值轮 = m2381 实机试验田。
- **前置**：等 kalama SDE catalog 真值收割（nura 侧排程，球在主仓排程区待用户拍板）。

### 1.3 uhid（trivial，顺手带上）

- **现状**：r78 内核 **无 uhid 模块**（modprobe: Module uhid not found）。经典蓝牙 HID
  （现役 Xbox 手柄）走 hidp 不受影响；**BLE HID 设备全灭**（新式手柄/BLE 键鼠无法建输入）。
- **请求**：下轮内核 `CONFIG_UHID=m`。

## 2. 同步机制与回归协议

- nura 每出内核轮（#80+）→ m2381 点火一轮 → 回传两项实测：①flip 行为（async cap 是否
  翻转 + 撤开关后撕裂/竞态观察）②旋转路径（rotate-90 声明后 gamescope 是否自动切 plane
  旋转 + RGB/UBWC×rot 真值）。结果回传两边档案（本仓 ignition 手册出参节 + nura 侧）。
- 排程态（用户侧默认，若用户另有拍板以用户为准）：async flip 先行；rotate-90 排后不弃。
  nura 侧已报主仓排程区待拍板。

## 3. 侧锚点（对账用）

- **Pocket S2 素材已留档**："gamescope 3.16.x + 竖屏面板 = 必现 flip EINVAL；
  master + --force-composition-rotation = 解"。撞见 pmaports 原 issue（AYANEO Pocket S2，
  2026-04）随手贴回。
- **kwin 会话（steamos-session）保留**为 SDDM 第二会话项/黑屏逃生门——固化时勿清。
- **诊断资产在设备 /root/**（重刷前有留价值，nura 暂不收资产、路径在案）：
  sm20-liftoff-probe.c（libliftoff 分配矩阵探针；转 pmOS 调试协议时入库）、
  sm20-plane-props.c、sm20-allprops.c、libliftoff.so.0.bak（原件备份）、
  steamos-gamescope-session.log.20261010、gamescope-last-frame.png。
- 宿主侧栈快照：work/cache/gamescope-master-stack.tar.gz（/usr/local 全量）。

## 4. 回执状态

- nura 两判词（async flip 可做/rotate-90 待真值）已回话，我方三项承诺（本文 §1.1 验证
  平台、§1 接入开关两行、§2 回归回传）以此文档为准入册。
- 关口承诺：点火线 #3（home 键覆盖层 menu→game 回程）+ #4（每游戏缩放/限帧）手柄实测
  = 最后一步，"近期收口、结果回传两边档案"。

## 5. async flip 点火回传（2026-10-10 晚，r79/ESP v60 双腿实机）

**结论：PASS，三项机器验证全绿， kicking 每帧实锤；用户态开关已撤。**

- 双腿配对刷入：模块腿 r79 apk（sha8 57f468b0 对拍 ✓，/usr/lib/modules 整树替换，
  r78 树留设备 `/usr/lib/modules/7.3.0-rc6.r78-bak`）+ ESP 腿 v60（分区级 dd 读回
  0ccfcf72 精确命中）。uname = **#80-meizu-meizu20**。
- 验证配方逐项：
  1. ✓ "Immediate flips are not supported by the KMS driver" 会话开场行**消失**；
     drm_info `DRM_CAP_ASYNC_PAGE_FLIP = 1`（r78 为 0）。
  2. ✓ uAPI 层：空原子提交 `TEST_ONLY|DRM_MODE_PAGE_FLIP_ASYNC` 返回 0
     （探针 /root/sm20-async-probe.c 在役；r78 同探针 = -EINVAL 路径）。
  3. ✓ strace 持续 `MODE_ATOMIC = 0`（~113 次/秒 @120Hz）；**截图差分证明帧持续推进**
     （cmd 模式 kick 每帧成立——「不冻结也不前进」未发生）。
  4. ✓ journalctl -k 无 DPU/DSI 运行期报错（仅开机期 a740_sqe.fw 探测噪音，前轮即有）。
- 待补（用户侧）：~~d 项延迟主观对比~~ → **已回（2026-10-10 晚用户实测）：画面跟手度
  与 sync 基线无差异** = PASS；观察项空转功耗采样仍未采。
- 用户态撤除记录：`GAMESCOPE_DISABLE_ASYNC_FLIPS=1` 已从会话脚本删除（v5 在役）；
  `--force-composition-rotation` 按 nura 嘱咐**保留**（等 kalama SDE catalog）。
- 回归：kwin 会话/睡眠 wow 未跑（当日时间线让位给游戏启动修复+手柄排查），下轮补扫。
- 顺手修复：`mangohud` 缺失（新客户端性能显示层注入 `mangohud` 前缀，包不在即秒退
  exit 0）已 `apt install mangohud`；当前 /usr/bin/mangohud 为透传脚本
  （A/B 用，原件 = mangohud.real，GL 钩子在该栈的冻结嫌疑待 A/B 收口）。

## 6. r80/ESP v61 回归轮（2026-10-10 深夜，#81 实机）

**结论：双腿刷入 ✓、uhid/uinput ✓、kwin sync 扫 PASS；睡眠 = FAIL-有数据（s2idle
resume 冷复位，与 armada 上游"Real suspend hangs this SoC"判词互证）；BLE HID 与
uinput 手柄两件待用户带设备实测。**

- **双腿刷入**（料件 sha8 端到端复检：apk `b0c865b7` / img `cb7f1e5a`）：
  模块腿 = r79 树 → `.r79-bak`，r80 apk 解包（APK-TOOLS checksum 告警噪音照旧），
  depmod 后 `modinfo -n uhid|uinput` 双解析 ✓，新树 vermagic 不带 build 号（跨
  #80/#81 兼容，r78 树在 #79 的先例同构）；ESP 腿 = v61 dd recovery_a(sde27)
  conv=fsync，**读回 sha256 全串精确命中 `cb7f1e5a…`**。加测一道腿配对：v61 内
  `EFI/BOOT/BOOTAA64.EFI` 与 apk 自带 `boot/vmlinuz-efi` **sha256 逐字节相同**
  （`12ee72b9…`）——双腿同源零风险。reboot 后 **uname = #81-meizu-meizu20**，
  uinput 随 modules-load.d 自载，`modprobe uhid` 成功（r80 主打件落地）。
- **底噪判据 PASS**：journalctl -k DPU 报错仅 `a740_sqe.fw` 探测对（-2 → 2 秒后
  "loaded from new location" 自愈），与 r79/#80 上一 boot 逐行同款 = 每 boot 底噪
  非新伤；GPU devfreq 680MHz/ondemand 正常。零 critical/oops（grep 误伤 cmdline
  `oops=panic` 与 ramoops 字样已甄别）。
- **(a) kwin sync 扫 PASS**：SDDM 临时覆盖 Session=steamos-session.desktop 消费
  want-desktop 旗标 → Plasma 8 秒起；kscreen-doctor = DSI-1 1080x2400@120Hz、
  Rotation 8 持久化在位、亮度 control supported/34%（powerdevil 在跑）、
  kscreen+powerdevil 6.3.6 双装；**会话切换全程内核零 DRM 报错**；切回掌机会话
  8 秒起（gamescope --force-composition-rotation --force-orientation right 照旧）。
  **顺手发现切换器两处缺陷（不阻塞回归，armada 换轨后随线冻结）**：
  ① `sm20-session desktop` 失灵——旗标消费者在 `steamos-session`（kwin 最小会话
  包装器），而 SDDM 默认已钉 `steamos-gamescope.desktop`（不认旗标）→ 切桌面
  重启后仍进 gamescope；② 旗标 `rm -f` 以 steamos 用户跑在 root:root 目录上静默
  失败，"一次性"实为"永久直到 root 清"（`sm20-session handheld` 可清，兜底有效）。
- **(b) 睡眠/wow FAIL-有数据**：`rtcwake -m mem`（s2idle 路径，`/sys/power/mem_sleep`
  = `[s2idle]`）+ PMIC `rtc1`（rtc-pm8xxx）闹钟。RTC 布局实锤：rtc0 = rtc-efi
  **读 EIO 废件**（ABL EFI RTS 不给时间），闹钟腿必须 `-d /dev/rtc1`。时间线：
  闹钟挂上 → 入睡 → **闹钟到点平台没能 resume → ~2-3 分钟后冷复位**（uptime 归零
  重计；journal 异步尾 ~4 分钟随复位丢失，最后刷盘行 = `adreno_gmu: delay in
  fenced register write (0x8a1)` 连发 + ADSP GPR RX 刷屏；pstore 空 = 冷复位
  ramoops 不保）。"wow 保连接"无从谈起。logind 一发（电源键唤醒路径）待用户配合
  可选补打——与 rtcwake 同一内核入睡路径，增量数据有限。**对照铁证 = armada-sheng
  `fake-suspend` 脚本注释原文 "Real suspend hangs this SoC"**——SM8550 主线 s2idle
  resume 问题上游同样存在，他们的答案 = 假睡眠守护（systemd-suspend.service 换
  挂起阻断 + Steam 熄屏 + 电源键唤醒）+ NM 补丁保 WiFi。**armada 镜像睡眠腿 =
  直接抄 fake-suspend 家族**，真睡眠留 pmOS 内核线长线。
- **(c) BLE HID PASS（2026-10-11 凌晨，用户实机三设备）**：K380 键盘与 Xbox 手柄均
  走经典 HID（00001124/hidp）正常出节点；MCHOSE A7 Pro 鼠标 = **BLE HOG
  （00001812）**，初次连接被 bluetoothd 拒收（`input-hog profile accept failed`）
  ——根因 = `/dev/uhid` 不在（=m 模块无自启，bluez 打不开就放弃）；`modprobe uhid`
  后重连即出 event8/9（`/sys/devices/virtual/misc/uhid/0005:005D:4762` 出身实锤），
  25s 采样 22920 字节事件流，三设备全活。**r80 CONFIG_UHID=m 靶心验证 PASS**。
  修复固化 = uhid 开机自载双落（设备 `/usr/lib/modules-load.d/uinput.conf` 增行；
  层源 pmos_linux `device-meizu-meizu20/meizu20-uinput.conf` 同步，pmos/ 为
  gitignore 工作树落盘即可）。⚠ 对 nura 的可操作建议：**UHID 若改 =y 可省自载件**
  （与 uinput 同理，misc 设备无 open-time autoload）。
- **(d) uinput 手柄 FAIL = 已知会话层墙的原子级取证（2026-10-11 凌晨，用户实测判词
  "能开游戏、无法控制游戏，一直如此"）**：Ori（261570，Proton 11 ARM64 容器链）
  由 `steam://run` 拉起、标题画面完美渲染；steam 正确采纳 Ori 绑定
  （xboxone 模板 + Config Cache 261570 hit），Xbox 手柄（经典 hidp，event5）事件流
  到内核、steam sdl:// 枚举正常。**死穴原子动作 = steam input 前景感知瞎**：
  activation 在 769/413080（SLR 容器，配置 empty.vdf）/261570 之间翻飞，虚拟手柄
  随之创建/销毁（00:49:01 Created → 00:52:20 Destroyed → 00:54:04 又 Created），
  销毁窗口内游戏无输入通道。手柄在 Steam UI 层全程好使（能导航、能启动游戏）=
  物理链路/枚举/绑定全通，唯「游戏前台」判定坏。**内核无关实锤**：r78/r79/r80
  三代行为一致（本代对照）+ kwin 时代正常（用户口供）= gamescope 会话集成缺口，
  非 uinput 非内核。**修法方向已由 armada 考据给出**：InputPlumber → deck-uhid
  第一方 Deck 手柄（绕开 steam 自建虚拟手柄/焦点握手）+ gamescope 焦点回退补丁，
  见 docs/M2381-ARMADA-RECON-20261010.md。
- **回归轮总结论（回传 nura 用）**：r80/v61 **零回归**——两件交付物全验证（async
  flip r79 §5 PASS + uhid r80 ②c PASS）；两件 FAIL 均为已知非内核墙且带完整取证
  （睡眠 = SM8550 主线 s2idle resume 冷复位，与 armada 上游 "Real suspend hangs
  this SoC" 互证；游戏内手柄 = steam 会话焦点握手，内核无关三代一致）。**按协议
  可钉 r80/device r59/v61 + Release**。
- **回滚锚更新**：本轮回滚 = ESP v60 + `/usr/lib/modules/7.3.0-rc6.r79-bak`；
  深锚 v59+r78（`.r78-bak`）不动。料件留在设备 /root（apk + img）。
