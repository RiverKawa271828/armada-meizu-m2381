# steamos-meizu20 — 魅族 20（m2381/SM8550）SteamOS 移植线

> 本仓 = **改造自 code002-2/Steamos-xiaomi-sheng 的 m2381 适配项目**（fork 时代模式：
> 本地先行零网络，推送目标 = 自建 fork 待建）。
> 新会话必读本文；子系统细节看 `docs/README.md` 索引（移植正典 = M2381-ARMADA-PORT-20261011），判词出处 =
> `/home/ri/work/pmos_linux/docs/meizu20/steam-armada-assessment-20261008.md`。
> 主仓规范/硬定律 = `/home/ri/work/pmos_linux/AGENTS.md`（本文只留本项目规则与现态，
> 与主仓冲突时以主仓硬定律为准）。

## 现态一句话（新会话从这里接）

- **★★ 路线终决（2026-10-10 深夜用户拍板，效力高于本节其余历史）**：**等 nura
  r80/v61 内核两腿 → 全面转向 armada-sheng 线（code002-2/armada-sheng）；Debian 线与
  官方 Frame 线（Steamos-xiaomi-sheng）冻结为参考，不再推进**。重评估全文 =
  docs/M2381-ROUTE-REEVAL-20261010.md（三线账 + 换轨真实案由补录）。冻结 ≠ 删除：
  现役 Debian 环境 = 内核回归试验台（r80 四合一回归照跑，纯内核验收不算"推进"）+
  调试工具链库；Frame 底包 = Valve 原装会话件参照源。**执行序现态（2026-10-10 深夜
  会话收官）**：
  ①**r80/v61 双腿刷入 ✅**（apk sha8 b0c865b7 / img cb7f1e5a 双对拍 ✓ + 腿配对加测：
  v61 内 BOOTAA64.EFI ≡ apk vmlinuz-efi 逐字节 12ee72b9；**uname = #81**，uhid/
  uinput 双解析+自载 ✓，底噪 = a740_sqe.fw 每 boot 底噪与 r79 同款非新伤）。回滚 =
  v60 + `.r79-bak`，深锚 v59+r78 不动；料件留设备 /root。
  ②**四合一回归 ✅ 全部收口（2026-10-11 凌晨，全文 = docs/M2381-KERNEL-ENHANCE.md
  §6）**：(a) kwin sync 扫 **PASS**（Plasma 8s 起、120Hz 横屏/亮度/powerdevil 全在、
  全程零 DRM 报错；切换器两缺陷随线冻结不修）；(b) 睡眠 **FAIL-有数据**（rtc0=
  rtc-efi 读 EIO 废件，闹钟走 PMIC rtc1 ✓；s2idle 入睡后闹钟到点不能 resume →
  ~2-3min 冷复位，最后刷盘行 = adreno_gmu 0x8a1 连发；**armada fake-suspend
  "Real suspend hangs this SoC" 互证**，armada 镜像睡眠腿=抄 fake-suspend）；
  (c) **BLE HID PASS**：MCHOSE 鼠标 BLE HOG 靶心——/dev/uhid 缺失时 bluetoothd
  拒收，modprobe uhid 后出节点+事件流实锤，uhid 自载双落（设备+层源，pmos/ 落盘
  即可）；(d) **uinput 手柄 FAIL = 已知会话层墙原子级取证**（用户判词"能开游戏、
  无法控制游戏，一直如此"：activation 769/413080/261570 翻飞，虚拟手柄随之建/毁，
  容器 appid 挂 empty.vdf；UI 层全程好使=物理链全通唯前景判定坏；r78/79/80 三代
  一致 + kwin 时代正常 = 内核无关，修法在 armada InputPlumber→deck-uhid）。
  ③**nura 收官确认（2026-10-11 回执，§7）**：钉子已落 r80/device r59/v61/#81
  （双侧哈希互证 12ee72b9 闭环），Release 排其推送窗；**suspend 回注 = pmOS wowlan
  三件真睡眠可用**（meizu-wowlan.service + 看门狗 WatchdogSec=0——我们缺 wowlan
  件，armada 睡眠腿改为真睡眠优先、fake-suspend 兜底）；合作轮正式闭环。
  ④**armada-sheng 零刷机考据 ✅**：全文 = docs/M2381-ARMADA-RECON-20261010.md
  （会话栈全景/启动链、steam 四旗标 -steampal -steamdeck 增件、STEAM_GAMESCOPE_*
  能力 env 排、InputPlumber+deck-uhid=手柄主场答案、fake-suspend、gamescope 27
  补丁、SDDM 会话切换、客户端同源 publicbeta 1788652215、设备档案系统=m2381 接入
  点）；**剩 issue 区问询未发**（问 sheng 实机 QAM/往返/BT 手柄三症状）。
  ⑤**armada 移植 ✅ 出盘（2026-10-11 凌晨，全文 = docs/M2381-ARMADA-PORT-20261011.md）**：
  底盘 = armada-sheng v1.2（`sheng-flashable`；实测 **container-export 单分区裸 ext4**——
  不是 ostree 盘，原计划摊平步骤取消；fstab 自带 PARTLABEL=userdata+growfs 与 m2381
  同字零改）+ 腿配对门禁实锤（apk vmlinuz-efi ≡ ESP v61 BOOTAA64.EFI = 12ee72b9 逐字节）
  + meizu 层 287M（固件/音频编排三件/触屏/UCM/黑名单硬定律，modules 弃用改解 r80 apk）
  + 新档案 meizu-meizu20.conf（竖屏 right + USE_ROTATION_SHADER=1 + SUSPEND_MODE=fake）
  + device-env case 行（"Meizu 20 (m2381)"）+ uhid 自载（deck-uhid 前置）+ NCM gadget/
  usb0-ip/ssh(root 123456)/GPU 看护构建期内置；手术摘除 armada-bootimg-sync（boot_b
  重写件）/bootupd/RNDIS/sheng-thp/update-reserve + /sysroot 孤儿 ostree 仓库 2G。
  **21 项点验全绿 → work/meizu-meizu20-armada-r80.img 14.6G（.sha256 旁证）**；steam
  客户端已预种（/var/home/armada/.steam 3.3G，publicbeta 1788652215 同源）首启可离线。
  **★ 已刷入实机 + 首启大半通（2026-10-11 凌晨，全文含抓虫 = docs/M2381-ARMADA-PORT-
  20261011.md §4）**：SSH `reboot bootloader` 进 fastboot（10s）→ userdata 17 块 OKAY
  6m08s；首启 <1min SSH 可达，growfs 457G ✓、steam 四旗标在跑 ✓、meizu 全链 active ✓、
  card0 出卡 ✓、触摸 Goodix ✓、device-env 全对 ✓、/dev/uhid+InputPlumber ✓、fake-suspend
  接线 ✓、gamescope 3.16.19-257 起 DRM connected ✓、终态 --failed=0。首启抓虫六件全修
  （FEX sqsh zstd→gzip【内核诉求 CONFIG_SQUASHFS_ZSTD=y】/wireplumber 踢卡固化/
  controller-type mask【无内置手柄必炸，默认 deck-uhid】/bootc-growpart mask/Decky
  disable/os-release 归位 Armada），全部回写适配脚本保持重建同构。
  **★ ②d 墙破（2026-10-11 用户实测"全部正常"）**：WiFi/登录/手柄进游戏受控/扬声器/
  QAM/往返全绿——Debian 三堵墙在 armada 不存在，路线判决成立，**Debian 盘退役为纯
  备份**（回滚 = 重刷 r78 盘；vermagic 注：r78 模块 #79 vs ESP #81，重刷后宿主 loop
  解 r80 apk 修配对）。**RTC 持久化已装**（治无 RTC 电池首启时钟=盘内烤死旧时间→
  steam TLS 全挂弹"无法下载更新"）：rtc0=efi 废件、rtc1=pm8xxx PMIC 走电正主——
  sm20-rtc1-restore（sysinit hctosys+废值门禁）+ save.timer 每小时写回 +
  time-wait-sync 25s 兜底，持久性待下次重启实证。**睡眠假死已破（同日，最大
  抓虫根因在自己）**：层里 Debian 时代 sleepmask tmpfiles usr 侧漏排除 → 首启
  把 sleep/suspend 等 4 target 全 mask → logind Suspend 永远 Access denied →
  steam "Issuing Suspend Command" 石沉大海停在自己黑屏渲染态；清掩码+删源头
  tmpfiles+**usr rsync basename 排除回写脚本**后，fake-suspend 全链实测通
  （display off→wake pmic_pwrkey→display on），steam 走 PrepareForSleep 正常
  生命周期，电源键睡眠/唤醒=原版 Deck 体验。
  睡眠腿备注：现
  钉 fake（真 s2idle 入睡不 resume 与上游互证）；nura wowlan 三件真睡眠（meizu-wowlan
  + WatchdogSec=0）留作上机后实验项，档案改 s2idle 即切换。选型存档：官方
  armada-os 20260926 = 整盘 UEFI+bootc 不合 fastboot 模型，留参照备胎；Frame 恢复镜像
  20260922 用户已手落 dl/ 收档。适配脚本 = build_files/build.sh
  （宿主 systemd-run，可重入）。
  **★ 会话收官（2026-10-11 晨）**：armada 线全绿服役中（手柄/QAM/往返/睡眠唤醒/音频
  皆验），用户拍板"比之前任何一条线都好用"，**进入 fork 发布评估**。给 nura 的回传已
  定稿（docs/M2381-NURA-RELAY-20261011.md，提交 815aa8c），等回信中：①钉 r80/device
  r59/v61+Release ②SQUASHFS_ZSTD=y 诉求 ③GMU IRQ/rtc1 情报。**发布计划（下会话可执
  行）**：上游 armada-sheng=GPL-2.0-or-later（已核，派生干净）；推荐轻发布=现仓公开为
  适配 overlay（40-adapt+层+档案+文档，base 件链接上游 releases 不重分发），重发布
  （Actions 全自动+挂镜像）二期；发布前清理=README 重写（现为 Frame 旧文）+AGENTS.md
  README 重写+LICENSE 补 GPL-2.0+Credits；内核 apk 分发口径等 nura 确认公开链接。
  ⑥冻结项备忘：Debian graft 固化/mangohud A/B 随线冻结（mangohud 透传脚本保持
  在役防秒退），armada 线若撞墙再解冻 Debian 作对照。
- **★ nura 回信到（2026-10-11，r80/v61 四合一收官轮答复；全文 = nura 仓 AGENTS「带话」节
  2026-10-11 段 + MANIFEST，彼侧已提交推送）**：①**Release r80 上线**（5 件制：mu-r69 +
  v61.gz + rootfs r80[e1b9494f，plasma] + 固件 + SUMS；**锚三件自 r80 起不随发布**——刷坏
  重刷现役三件；上传验收 = 本地 gzip -t + 字节数逐件对拍）；②**SQUASHFS_ZSTD/XZ → 内核
  r81 已出（config-only，tip 不动 349e8aa5579b）**：apk r81 + **ESP v62**（裸 b41b8888 /
  gz 3e4987d5）配对交付，上机期望 **#82**，ArchLinux.sqsh 可直挂——按协议待彼侧点火回归，
  过 = 升现役、挂 = 撤回 r80/v61；device r60（uhid modules-load.d）随轮（我线已自固化、
  不受影响）；③**RTC 情报命中**：nura 核实其 config HCTOSYS/SYSTOHC 原钉 rtc0（rtc-efi
  EIO 废件）→ r81 已改 rtc1（pm8xxx），**我线用户态 hctosys/systohc 持久化脚本在 r81+
  腿上可撤（r80 及以前保留）**；④GMU/IRQ 亲和性情报入 nura 内核候补件③（与我方
  0x8a1/devfreq 病史互证收档，落地后撤 gpu-ondemand-watch；暂无排期）。
  ⑤**协作边界（2026-10-11 定）**：本次目录事故=nura 误操作（本仓一度被换成
  armada-sheng clone，已完整恢复、零净损失）。已与 nura 约定：**他不再动 steamos
  侧本仓**——两条线完全不同，只共享同一份内核 apk + 启动链（ESP）；料件交接走
  kernel-m2381/BUILD.env 钉子 + nura 自己的 Release，不做目录级操作。
  **★ 边界双向对等（2026-10-11 深夜用户拍板）**：**我方亦不再动 nura 仓的文件**
  ——书信由我方起草、用户转告（relay 件 = docs/M2381-NURA-RELAY-*.md，最新
  R82 = r82 点火回执 + v62 哈希定谳 + 本边界告知）。r82 回执曾按旧惯例写进彼仓
  round §6 + AGENTS（八十四）（本地提交 79b4200，未推），系最后一次，留弃由彼定。
  ⑥**下会话执行单（处理 nura 回信）——★ 2026-10-11 晚会话已收口（除推 fork/发 issue 待用户令）**：
  ①**r81/v62 升级判定 = 过，已升现役 ✅**：双腿上机（v62 dd recovery_a + r81 模块
  换装，旧树 .r80-bak），uname = **#82** ✓，zstd 原件
  loop 直挂 ✓（/proc/config.gz 证 ZSTD/XZ=y），RTC 用户态三件撤除后重启时钟正确
  ✓（内核 rtc1 接管，timedatectl 首次能读出 RTC），WiFi/uhid/--failed=0 全绿。
  BUILD.env 已换钉（apk sha 1c31babe / 配对 5cb94ebd）。**FEX gzip 重压已撤**
  （build.sh 删重压段，sqsh 保持 zstd 原件）+ **RTC 三件已从 system_files/build.sh
  撤除**。**r81 镜像已重建** = work/meizu-meizu20-armada-r81.img 14.6G（点验全绿
  含 3 新项：qbootctl 在位/RTC 已撤/sqsh zstd；MANIFEST 生成已变量化）；**盘刷写
  待用户拍板**（在役实机已是 r81 腿 #82，不急）。⚠ **哈希定谳（r82 轮复核，
  取代原「勘误」）**：v62 裸镜像真值全量 sha256 = `b41b88889cadf6060e35…`，
  8 位前缀 = **b41b8888（nura 原手记无误）**；双方手记里的「真值 b41b8889cadf…」
  = 同一转抄病（连排四个 8 丢一个），本节原「勘误」作废（详 PORT 正典 §7/§9）。
  ②**Release URL 回填 = ✅ 已办结（2026-10-11 深夜 nura 加信）**：Release r80
  增补两 apk 资产，双侧下载对拍全等（内核 1c31babe ≡ 本地同件；固件 6e6dac0a
  = Release 重打包，与 nura 本地原始 f0018f56 同版本不同打包，**BUILD.env 固件
  钉已换 6e6dac0a**）；KERNEL_APK_URL/FIRMWARE_APK_URL 已填；build.sh 固件段
  补 URL 拉取分支（本地缺/失配才走，sha 门禁兜底）；固件 apk 已落 APK_DIR。
  口径：以后每轮随件 apk（同 URL 换 rN）；SHA256SUMS 不含 apk。⚠ apk r81 比
  Release rootfs（内烤 r80）新——外人直刷要 ZSTD/RTC 修复 = apk add + ESP v62
  两腿同轮（已注 BUILD.env）。下轮重建起固件走 apk 件（本轮 r81 盘固件仍来自
  work/layer 回退，内容同源）。
  ②b**fastboot 停车根修 ✅（nura 诊断信当日闭环）**：实测复现 slot-successful:b=no
  → qbootctl（linux-msm v0.2.2 tag 0d11f87e，设备端 gcc 现编——pmOS musl 动态版
  不可用于 Fedora 底）+ qbootctl-meizu.service（逐字同款 nura downstream 单元，-m，
  无 androidboot.slot 回退读 GPT active 位验证有效——本机 cmdline 无 slot 参数）；
  mark 后 Successful=1，重启后 unit 自动重标 ✓，ABL 预算不再烧。binary+unit 入
  system_files + build.sh enable，r81 镜像起全带；救机配方（fastboot set_active b）
  + 闭环判据入 docs/flashing-meizu-m2381.md 新节「重启落 fastboot」。
  ③**issue 问询 = 草稿就绪未发**：三症状已破改为报捷+两问（A/B 槽位标记/FEX
  zstd 依赖），docs/ISSUE-DRAFT-armada-sheng.md，等用户过目后发。
  ④**RTC 持久化实证 ✅**：见①。
  ⑤**推 fork**：**用户已定调"要发，但以后完善了再说"（2026-10-11 午）**——轻发布
  方案（仓公开 + tag/Release notes 零镜像）已认可，镜像分发（gzip -9 实测 4.01GB
  切 2 卷可过 GitHub 2GiB 资产上限）留二期；推送动作等用户完善后再发令
  （RiverKawa271828/armada-meizu-m2381）。
- **★ 待机功耗轮（2026-10-11 午，gpu-idle-damp 落地，全文 = PORT 正典 §8）**：
  现象 = idle 44-47°C（GPU 驻留 475/680 档 80%，webhelper 阵发 3 核爆发 ~37%
  占空比）。修复 = gpu-idle-damp 三态机（无游戏+无输入 90s → 钳 max 220 + /run
  旗标；watch 见旗标让路）入 system_files/build.sh enable，已上机在役。实测：
  idle→220(86s)→标记→680(8s)→回 220(10s) 全链 ✓，post-fix 均值 3.08W（静默段
  1.7-1.9W 达标；爆发段 4.5-6.8W = webhelper CPU 项未收）。已证伪 fps_limit 60
  对爆发无效；屏保相册轮播 = idle 动画负载（GPU 侧已钳压住；**用户已 UI 关屏保**，
  键 = config.vdf `IdleScreensaverACSeconds`；`IdleBacklightDimACSeconds=0` =
  AC 永不暗背光，用户侧杠杆）。**候补件③转正申请已发 nura（用户拍板"让 nura
  做内核根治"）**：验收口径 = idle 静态下 trans_stat 低档驻留占主导 + ≤2W 档；
  我方 damp 保留、watch 等 governor 诚实后撤。
  **▶ r82/v63 候选点火轮已收官 = FAIL（2026-10-11 深夜，全文 = PORT 正典 §9）**：
  nura 交付 busy−IFPC 折叠补丁（fork 95284ff2c806， apk r82+ESP v63 配对
  c68f84aa），#83 一次点亮、回归全绿，但 **ifpc_delta_us ≡ 0（100 窗精确零）+
  折叠无物可减 → 分型 H3（IFPC 未协商上/XOCLK4 没在计，GMU FW v4.1.9）**；
  摘 damp 10min：475 档 60.6% 主导（220-295 仅 ~19%）+ 均值 2.20W —— 双判据
  不达。r82/v63/#83 留机在役（debugfs busy_deltas 有用），回滚 = r81+v62+#82
  （.r81-bak 在位）；BUILD.env/nura config.sh 钉均不动。damp/watch 已还原。
  **下会话执行单**：①等 nura r83 候选（H3 分支：HFI 特性位 + silime 血统
  enable→revert 考古）→ 老流程点火；②webhelper
  爆发触发源长观察窗（DevTools 8080 + 占空比日志；瞬时 205%+92% 阵发已抓，
  疑似相册预载/通知/商店轮询；本轮窗内 max 6.95W 阵发仍在）③长 soak 温度稳态
  验证（晾一晚看 ≤40°C）④零改动备选杠杆 upthreshold=90 未测（nura 备选，需要
  时打）⑤老三样：盘刷写待拍板 / issue 草稿待过目 / fork 推送待令。
- **★ Phase-0 探针轮收官 = FAIL，r83 A 路被门挡下（2026-10-12 凌晨，全文 = PORT
  正典 §10 + 回执信 docs/M2381-NURA-RELAY-20261012-R83.md 待用户转交）**：
  nura 定 r83 发货门（r82 腿 debugfs idle_clamp 置位 + 摘 damp 600s，判据 =
  220-295 主导 + ≤2W）。第一轮 23:44 撞用户下载游戏作废（8.4-8.6W/输入 6600B，
  归档 /root/phase0-r1-polluted；另留死因存疑：nohup 点火主 bash 被不明信号孤立
  杀死、监听子进程幸存——第二轮改 **systemd-run 托管**（⚠ 本机不认 --set-env，
  用 `-p Environment=`）全链正常）。**第二轮（23:57-00:07）= FAIL**：475MHz 驻留
  **66.1% 主导**（220-295 仅 22.2%）+ 均值 3.85W（起步 GPU 55°C 余温混杂已注明，
  判据①足判）；**对照 §9 基线（无 clamp）档位分布几乎不动（60.6%→66.1%）=
  idle_clamp 在本机无可测效果**；机制自洽 = busy 地板（恒 ~50% 忙）使 devfreq
  idle 判定永不成立 → clamp_to_idle 无触发点，H3 互证。回执信含两点转告：①
  FAIL 停发、B 路（busy 会计根因）为唯一明路（若彼对 clamp 语义另判，零构建
  10 分钟可复测）②v63 gz 回传件就绪（work/esp-recovery-v63.img.gz 13,942,289B，
  gz sha 425ecd37；解压 = 533f40d0 三处对拍；来历 = 我方清库+彼侧事故双断原件，
  自 recovery_a dd 重得 gzip -n -9 重压，**验真走解压后全量**）。**教训入档：
  nura 交付件哪怕无管线引用也留一份**。r83 预告收悉（apk+ESP v64、#84、七条
  回归卡 + `IFPC feature-ctrl enable sent, ret 0` 日志行），B 路候选到货老流程
  照点火。设备现态已复原（clamp=N、damp/watch active）。
- **★ 上游评估轮（2026-10-12 凌晨，nura 忙其他事我方独立推进；全文 =
  docs/M2381-UPSTREAM-REVIEW-20261012.md）**：**fork 上游维持 armada-sheng**
  （形态兼容 = sheng-flashable 单分区 ext4；我方 fork 点 = sheng main 7cf8163
  未动），**新增内容观察源 armada-os**（官方 20261010 仍是整盘 OTA 格式不合
  fastboot 模型）。remotes 已整理：`upstream`=armada-sheng / `armada-os`=官方 /
  `frame-upstream`=老 Frame 仓留档（原 upstream 改名）。**核心情报 =
  GMU wedge fix 三件套**（armada-os #662，源自 kettlelinux——另一 SM8550 A740
  发行版）：0620 HFI IRQ 清掉轮询中的 MSGQ/OOB ack 位 / 0621 devcoredump 等待
  2s 上限 / 0622 GMU boot 前 mask HFI 中断（SM8550 resume 期幽灵中断）——
  **与 nura IFPC「ack 不执行」同域不同症，短笺 docs/M2381-NURA-RELAY-20261012-GMUHOT.md
  待转告**；附带 ARMADA_IRQ_CORES=0-2（IRQ 亲和性机制，nura 候补件③佐证）。
  sheng upstream-sync 分支领先 main 37 commits 未合（hexagonrpc+libssc 包 =
  我方 P2 传感器链现成参照、用户态栈大版本更新）——**等 sheng 出新
  flashable 再升级底盘，不抢跑**。参考克隆 work/ref/{armada-os-upstream,
  armada-sheng-upstream}（blob:none）。
- **▶▶ 下会话执行单（新会话从这里接，2026-10-12 凌晨五更 = 发布链首轮中断收口）**：
  ①**发布验证进行到「首启冒烟」被三虫截停（球 = 下会话）**：r84 盘已重建刷入
  （a7d4d1e7 盘 = **作废版**，带三虫）+ 设备手修三件已写盘（**等用户手动重启
  验证**：zz-sddm 件已删 = gamescope 会话应起黑屏解 / bootc-generic-growpart
  已真 mask / nura 固件 apk 已补入 /usr/lib/firmware）。**下会话序**：设备重启
  → 冒烟（gamescope 会话/DRM 干净/音频 card/--failed=0/WiFi/触摸/steampal 四
  旗标）→ 全绿 = 三虫修法实证 → **重建镜像**（build.sh 三修复已回写 d6332c2
  后新提交：固件无条件叠加 nura apk + growpart 真 mask + 删 zz-autologin）→
  **重刷** → 终验 → **推 fork + Release**（force 接管公开仓 main = unrelated
  histories；issue 草稿 docs/ISSUE-DRAFT-armada-sheng.md 一并交用户过目）。
  ②**首启三虫（r84 盘 vs 在役机的差异 = 在役机全是热修态，新盘 = 底盘原生态）**：
  (a) **黑屏根因 = 底盘 zz-steamos-autologin.conf 钉 armada-plasma**（zz- 字母
  序压过 armada.conf 的 gamescope 会话）→ Plasma llvmpipe crash；删 = gamescope
  接管（armada.conf 自带 Relogin=true）。(b) **bootc-generic-growpart failed**
  = static unit 走 10-armada-bare-metal drop-in 拉起、摘 wants 不够，真 mask
  修复。(c) **a740_zap.mbn/ADSP 缺** = 底盘自带 Fedora linux-firmware 有
  ath12k → 固件注入段短路跳过 → meizu 专属件（qcom/sm8550 zap/ADSP）全缺
  （在役机固件 = r80 时代 work/layer 覆盖态）→ GPU init 重试风暴（42 连发后
  fallback 成功、GPU 可用但路径缺）+ 音频隐患；修 = 固件段改无条件叠加 nura
  apk（tar 覆盖语义，sha 门禁 + URL 拉取分支保留）。
  ③**GPU 线已收官（§11b）**：r84/v65/#85 收官现役（双侧更钉）；watch 撤/damp
  留；ifpc 残线 lead。nura 下程 = 只候 7.3 stable（~10-18）→ rebase 拼车。
  ④观察项不挡发布：webhelper 长观察窗（damp 防护中）/ 长 soak / upth=90 实验
  档。用户重心转向内核线（nura/armada 都是受益产品），armada 线"有时间再弄"。
  ②**发布链（用户已定序）**：游戏实测（~~DS DC DX12 案~~已结：非硬件墙，turnip
  Vulkan 1.4.354 实测，FEX/Proton-ARM64 组合问题，用户拍板不追）→ **整盘重刷**
  r81damp 盘（sha `79478916`，配 v62 腿 → #82）→ 验证 → **推 fork
  RiverKawa271828/armada-meizu-m2381 + Release**（轻发布案：仓公开+tag/notes
  零镜像分发；issue 草稿 docs/ISSUE-DRAFT-armada-sheng.md 待用户过目后发）。
  ③观察项（不挡发布）：webhelper 爆发长观察窗 / 长 soak 温度 / upthreshold=90
  备选未测。
- **★ nura 回信到（r82 点火轮答复，2026-10-11 深夜用户转告）+ Debian 清库 + 重建出盘**：
  ①v62 哈希彼侧实测盖章（gzip -dc|sha256sum = b41b88889cadf…，前缀 b41b8888），
  （八十三）勘误系彼方转抄病已改回——**哈希公案两清，全量哈希=单一真值源**；
  ②协作边界确认（79b4200 彼核保留；双向书信走用户转告、互不碰对方仓；料件照旧
  BUILD.env + Release）；③**H3 树内精化 = XOCLK4 接线已证通（a740 ∈
  adreno_is_a7xx）、零值 = GMU 从未进 IFPC、H2F_FEATURE_CTRL(IFPC) 消息在发而
  FW v4.1.9 不动作**（固件不配合实锤）；④r82/v63/#83 留机确认，busy_deltas 留给
  r83；⑤**r83 两路排队：A = clamp_to_idle 给 a740 置位**（上游建模的软件 IFPC
  替身，一日件，预期直接拿我方验收口径）**/ B = IFPC 协商/固件血统/silime revert
  考古（追根）——排程球 = 用户**，A 路出件后老流程带话点火。
  **Debian 清库（用户拍板"debian bug 太多=放弃原因"）**：legacy/（管线 9 件+会话件）、
  work/out（qcow2 缓存）、gamescope-master-stack、会话件 v5 全删，**docs/ 记录全留**
  （git 历史可考）；宿主已无任何 Debian 资产。
  **重建出盘（22:48，r81+damp 同构盘，发布候选）**：verify 升 22 项（新增"damp 件在
  位"）全绿；盘内 damp/watch/qbootctl wants 三件齐；新 sha256 = `79478916…`。
  ⚠ 教训：**work/cache/esp-recovery-v62.img 是 build.sh 的 ESP_REF 构建输入（腿配对
  对拍基准）非回滚件**——清库时曾被误删，已自 nura gz 真值还原（b41b8888 ✓）；
  **清理任何料件前必须 grep 管线引用**。**发布链 = 用户游戏实测 → 整盘重刷验证 →
  推 fork + Release（轻发布案）**；重刷注意：r81 盘配 v62 腿 → #82（busy_deltas
  出口随之消失，r83 到货再补）。
- **★ async flip 点火 PASS + 游戏启动修复 + wayland 接线实验（2026-10-10 晚）**：
  ①**r79/ESP v60 双腿已上机**（对拍 0ccfcf72 命中，uname #80；r78 模块树留
  /usr/lib/modules/7.3.0-rc6.r78-bak；回滚 = v59+r78）：cap 翻 1、"Immediate flips" 行消失、
  uAPI ASYNC 探针 0（/root/sm20-async-probe.c）、MODE_ATOMIC ~113/s 连发、**截图差分证明帧
  推进**（cmd 模式 kick 每帧成立），journalctl 干净；GAMESCOPE_DISABLE_ASYNC_FLIPS 已撤
  （会话件升 **v5**，`--force-composition-rotation` 保留）；回传全文 =
  docs/M2381-KERNEL-ENHANCE.md §5；待补 = 用户延迟主观对比 + 空转功耗；kwin/睡眠回归未跑。
  ②**游戏打不开根因 = 新客户端性能显示层注入 `mangohud` 前缀而包不在机**（启动链 exec 秒退
  exit 0；今早能跑 = 当时无注入）：已 apt 装 mangohud，但 GRIS 实测冻帧（单核 70% 自旋、
  GPU 680MHz、合成器/flip 环全正常 = 游戏没吐帧），**/usr/bin/mangohud 现为透传脚本**
  （原件 mangohud.real；GL 钩子冻结嫌疑待 A/B 收口——透传后重启 GRIS 曾 GAME_ADVANCING）。
  ③**手柄失效历史情报（用户口供）= kwin 时代游戏内手柄正常、真掌机模式后失效**；注入链
  节点全活：steam 握 /dev/uinput + 虚拟手柄已建（event6 "Microsoft X-Box 360 pad 0" =
  /devices/virtual/input/input8，uinput 实锤；容器 /dev/input 全量可见 = wine 可读），但
  **steam input 激活路由到错误 appid**（controller.txt：Queueing activation → 443510/413080，
  从不 683320）= 前台感知瞎 = 焦点握手缺口。④**Deck 身份三件套已立（本晚会话件 v7）**：
  (a) os-release 补 `VARIANT_ID="steamdeck"`（上游 graft 650 行同款；Debian 底包本来没有，
  steamui 按 "for steamdeck + gamescope" 分流，jupiter 命令行已开始跑）；
  (b) **steamui.so 按 /sys/class/dmi/id/{board_name,board_vendor,bios_version} 探测
  Jupiter/Galileo**（strings 实锤），本机 = Meizu/meizu20 → 会话件 v7 用非特权
  `unshare --user --map-root-user --mount` 把 /tmp/sm20-dmi/{board_name=Jupiter,board_vendor=
  Valve,product_name=Steam Deck} bind-mount 盖到 sysfs 上（ns 内实测读到 Jupiter）；
  (c) steam 挂 `WAYLAND_DISPLAY=gamescope-0`——⚠单独挂 = v5 黑屏事故（SDL3 见
  WAYLAND_DISPLAY 自动转 wayland，弃写 X11 的 STEAM_OVERLAY/STEAM_INPUT_FOCUS 属性通道，
  而 gamescope-control 真绑定又没发生 → gamescope 无焦点信息可合成 = 全黑有声；
  32s 截图格式报错要用 8s；**SDL_VIDEODRIVER=wayland 更毒，直接 webhelper 未响应**）。
  **v7 = (a)+(b)+(c) 三合一套装，UI 渲染正常 + webhelper 8 进程活**（v5 黑屏疑因缺 Deck
  身份时 wayland 模式走错分支）；"binding gamescope-control" 行三种配置下都不出现
  （strings 85011 行确认代码在，门禁未破译），但 v7 下游戏内 QAM 面板首次渲染成功
  （用户实测，v4 纯 X11 时代从不映射）；menu→game 回程 / 手柄路由 / 反复切换黑屏仍未收口。
  **★ v7 三合一套装用户实测判词（2026-10-10 深夜）：无任何改善**——游戏内手柄照旧死、
  一下菜单键照旧黑屏。已撤 WAYLAND_DISPLAY 回稳定形态（v7-stable = VARIANT_ID + DMI
  Jupiter 伪装保留、无 wayland；/root/steamos-gamescope-session.v7-stable.bak；
  gamescope-control 绑定是唯一没打通的枢纽，strings 门禁破译排下会话主攻）。
  ⑤备份链 /root/steamos-gamescope-session.{v4,v5-nowayland,v5,v6,v7,v7-wayland}.bak；
  v7 源已收编 scripts/device/steamos-gamescope-session（work/layer 沙箱只读，graft 固化时归位）。
  **（执行单已上移至「路线终决」条目，本条执行单作废。）**
- **★ 真掌机模式点火成功（2026-10-10 午）**：gamescope standalone（**master
  自建**）+ steam -gamepadui = 真 Deck 架构**在魅族 20 上点亮**：横屏 2400x1080、flip 零失败、
  **UBWC（QCOM_COMPRESSED）直接扫描输出**（plane49 gamescope-xwm XR30+UBWC，vsync 持续）。
  五层洋葱全在手册出参（docs/archive/M2381-GAMESCOPE-IGNITION.md，权威）：①msm 无 async flip →
  GAMESCOPE_DISABLE_ASYNC_FLIPS=1；②EINVAL 根本没到内核（strace 实证零 atomic ioctl，
  drm.debug 抓不到——拒绝在用户态 liftoff）；③libliftoff BTI-safe 补丁日志看到层带
  rotation=8（ROTATE_270）；④msm plane 只支持 rotate-0/180 + gamescope 对竖屏面板自动
  ORIENTATION_270 → 逐 plane 属性校验必挂；⑤3.16.22 无合成器旋转兜底 → **设备自建 master**
  （/usr/local/bin/gamescope，依赖升栈 wayland1.24/libdrm2.4.129/xkbcommon1.8/pixman0.46/
  protocols1.47 全 /usr/local）+ `--force-composition-rotation` = 点火。
  ⚠ 两条旧判词再作废：「EINVAL 当场抓 dmesg」对用户态拒绝无效（strace 才是判别武器）；
  「Debian gamescope 3.16.22 可用」作废（无 --force-composition-rotation，竖屏面板必死，
  勿回退）。会话件 = steamos-gamescope.desktop → /usr/local/bin/steamos-gamescope-session（v4），
  SDDM Autologin 已切；kwin steamos-session 保留为第二会话项（逃生门）；
  sm20-session 切换器两态可用。栈快照 = work/cache/gamescope-master-stack.tar.gz（16MB）。
  **下个会话执行单**：①用户手柄实测验收 #3/#4（home 键覆盖层回程 + 每游戏缩放/限帧——本架构
  覆盖层 gamescope 自管，kwin 死穴理应消失）；②graft 固化：层带 gamescope-master-stack.tar.gz
  + 会话件 + SDDM 默认切 gamescope + steamos-select-branch / jupiter-dock-updater 桩
  （上游 11.7 参照 work/ref/upstream-10-graft-bbc6065.sh:903）；③UDEBUG=noubwc 等诊断
  env 已全撤（TU_DEBUG 勿再加，UBWC 实测通）。
- **★ 点火后首轮实测：两大问题定性（2026-10-10 晨后段）**：
  ①**手柄全灭 = BT 链路僵死，非 gamescope 回归**：Xbox 手柄闲置自动关机后旧链路不释放
  （重连报 Busy），evdev 节点成僵尸（steam 握着死 fd，6 秒采样 0 字节）；`systemctl restart
  bluetooth` 后 3 秒重枚举全链复活（steam sdl:// 热插拔 ✓）。自救命令已交用户。**nura 事项：
  r78 内核无 uhid 模块**（modprobe FATAL）——现役手柄走经典 BT hidp 不受影响，但 BLE HID
  全灭，下轮内核建议 CONFIG_UHID=m。
  ②**游戏内 QAM 不显示 = 未决新案（当前最高优先）**：guide 触发后 steam 播声+内部切焦点
  （游戏暂停渲染 = 用户看到的"死报纸"），但 **UI 窗口从不映射**（400x300 隐藏小窗，UnMapped；
  大屏幕窗口游戏启动后即 unmap）。gamescope 机制 = 窗口带 `STEAM_OVERLAY` 属性 + 全宽/
  STEAM_INPUT_FOCUS 才画覆盖层——实查大屏幕窗口 `STEAM_OVERLAY=0`（ARM 客户端从不置 1），
  手动置 1 + 强制 map/activate/resize 全无效（webhelper 在游戏模式下不渲染提交）。
  **关键差异线索：steam 0 条 wayland 连接**（纯 X11 客户端，gamescope-0 socket 没碰）——
  Deck 上 gamepadui 走 wayland（gamescope-control 协议管焦点/OSD/UI 可见性握手），
  ARM 客户端不走 = 集成缺口。库里 QAM 待用户耳朵/眼睛边界测试（Xbox 在库里出不出面板）。
  诊断工具链已备：`GAMESCOPECTRL_REQUEST_SCREENSHOT` root 属性触发 gamescope 合成输出截图
  （/tmp/gamescope.png，xwd 看不到 GPU 窗口内容，此法为唯一眼睛）+ xdotool（XTEST 可触发
  QAM 热键 ctrl+shift+Tab）。下一方向：a) 强制 steam UI 走 wayland（SDL_VIDEODRIVER=wayland
  / 拆 DISPLAY 引导）接上 gamescope-control；b) 自写 guide 键监听守护 + 强制 map UI 窗口
  （卡在 webhelper 不渲染，需查 webhelper 恢复渲染信号）；c) 查 ARM 客户端是否有
  wayland UI 开关旗标。
  ③**手柄游戏内控制未通（用户点名的待办）**：BT 复活后事件流到 steam（controller.txt
  可见 sdl:// 枚举+绑定激活），但 Proton 游戏（Blasphemous 2 实测）不受控制。已知：
  Steam 虚拟手柄（uinput）从未创建（/dev/uinput 引用计数 0，steam 不尝试）——uinput 腿
  （r78 ko+ACL+rules）在位但端到端从未验证过；kwin 时代该路径同样未验。下轮排查 =
  steam↔proton 控制器通道（steam input 对 proton 的注入/IPC、proton 容器内 /dev/input
  可见性、或 steam input 设置层）。
- **★ 内核增强件判词已立（2026-10-10，nura 协作对接文件）**：**docs/M2381-KERNEL-ENHANCE.md**
  = async flip（先行，撤 GAMESCOPE_DISABLE_ASYNC_FLIPS）+ inline rotation rotate-90
  （排后不弃，撤 --force-composition-rotation，master bScanoutCanRotate 自动切回）+
  uhid（CONFIG_UHID=m，trivial）三缺件；含我方三承诺（m2381 当验证平台/两行撤除开关/
  #80+ 回归回传）与 Pocket S2、kwin 逃生门保留、/root 诊断资产等侧锚点。nura 正在配
  新内核。
  **边界收口（用户实测关机前）**：**库里 QAM 正常弹出+有声** = QAM 通路/UI 层本身是好的，
  坏的只是「游戏运行中」的切换（focus 切给 UI 但窗口不 map）。下轮主攻 = 游戏内切换，
  方向 a（steam UI 走 wayland 接 gamescope-control）权重最高。当日会话日志已存设备
  /root/steamos-gamescope-session.log.20261010 + gamescope-last-frame.png。
- **★ 设备日晨场：发热结案 + uinput 实锤 + 覆盖层修复 + 频道归位（2026-10-10 晨，新会话从这里接）**：
  ①发热排查结案 = Warframe（230410，**非 XCOM2**）下载 + 53GB staged 哈希校验的真负载：CDN 双线
  合计 ~550Mbps、steam 六个 CContent 线程烧 2~3.5 核、校验期 ~560MB/s 磁盘读，cpu7 峰值 95°C
  未降频、随阶段自然回落；全程无空转进程（systemd/udevd 高占用 = 开机风暴余波，瞬时 0%）。
  ②**uinput 已闭环（nura 当日 r78/#79 内核轮 + 我方模块腿）**：前情 = 缺失实锤（console_log
  反复 Couldn't open /dev/uinput → Proton 游戏手柄死路；原生 Linux 游戏直读 evdev 不受影响
  ——"stable 能玩"实为玩原生游戏）。nura 已代刷 boot_b（mu-r69 同字节重刷）+ recovery_a
  （ESP v59 = r78 内核，CONFIG_INPUT_UINPUT=m，#79 一次点亮；现有 r77 层模块树同 KVER 同
  vermagic 兼容，无需重 graft）。模块腿四件当日双落：设备 = uinput.ko（r78 apk 解出）+depmod
  +60-meizu20-uinput.rules（uaccess，ACL user:steamos:rw- 验收过）+modules-load.d；
  构建 = 层脚本 ⑤ 节固化（ko 取自最新 apk+vermagic 守门，胶水照抄 pmaports r59，层重建绿）。
  待验 = Warframe 手柄（steam 探针随控制器枚举触发，04:46 后零新增报错）。③**覆盖层置顶修复**：主页键唤起掌机菜单被游戏盖住 = kwin 焦点抢占防御（默认
  Medium）把 steam 置顶请求按抢焦点降级（kwin 看不见手柄动作）；修 = kwinrc
  `[Windows] FocusStealingPreventionLevel=0`，graft（10-graft-debian.sh kwinrc 段）+ 设备双落，
  频道切换重登后已生效。④客户端频道已归位 **steamdeck_stable**（03:50 更新完成自动重登；
  publicbeta 试验段结束，上条"已切 publicbeta"作废）。⑤真掌机模式路线图：L1 配置层（FSP=0 ✓；
  嵌套 gamescope 包游戏可选，wayland 后端已证；Deck UI 自带 OSK 待验）/ L2 内核层（uinput→
  Proton 手柄（✅ 已闭环，见②）；IN_FORMATS 翻案实锤→gamescope standalone = 真 Deck 会话
  合成器，**点火排下会话，手册 = docs/archive/M2381-GAMESCOPE-IGNITION.md**；s2idle→
  电源键秒睡（drop-in 已平移，见⑦，解锁待拍板））/ L3 不追（steamos-manager/TDP——SM8550 无 Deck EC/TDP 硬件路径，Steam 直连
  NM/BlueZ/logind 够用）。⑥**IN_FORMATS 翻案结案（nura 判词 + drm_info 复核，上条"疑似自带
  待查证"升级为实锤）**：旧探针 grep state 无效（state dump 根本不打 IN_FORMATS 属性，恒 0
  非读数）；drm_info 实测 10 个 plane 全带 IN_FORMATS blob，modifiers =
  DRM_FORMAT_MOD_QCOM_COMPRESSED（0x500000000000001，kwin 扫描面正用 UBWC 出图）——
  gamescope standalone 可在 #79 再点火，原 atomic flip EINVAL 真因另查（探针 =
  drm_info / modetest -p）。⑦**s2idle 用户态件已平移**：r58 看门狗 drop-in 全家
  （udevd/logind WatchdogSec=0、14 内部服务 30min、journald 30s sync；设备+层双落，daemon-reload
  过）——睡眠 mask 仍保留（内核侧 r72 起 cmdline no_console_suspend 已实证在跑，但电源键
  睡后唤醒不稳未治本，解锁待用户拍板）。⑧**覆盖层回程 bug 实锤（Warframe/Ori 复现）**：
  game→menu 方向正常（FSP=0 生效）；menu→game 方向 steam 不发"自降+还焦点"操作——kwin
  脚本实验钉死窗口层无碍（手动 minimize steamui 后游戏窗口立即 active=true 补位）；
  旁证 = gameoverlayrenderer.so（x86 版）LD_PRELOAD 失败，ARM 客户端游戏内覆盖体系残缺，
  菜单走"抬 steamui 窗口"降级路径、回程动作缺失。伴随：手柄配置 basicui↔游戏模板横跳、
  steam 主动收拆游戏树（exit -1，非崩溃非 OOM）；GPU 220MHz 系空载瞬态非假死复发。
  自救 = home 键进库点游戏；根修候选 = 自写手柄监听守护+kwin 脚本 / steam 旗标 / gamescope
  再点火。⑨**镜像 r78 出炉（含本轮全部修复）**：work/meizu-meizu20-debian-r78.img 11G，
  SHA256 148efbd075eb13f4de8c866d34ae25121f56099bdd01bec7c4d1d8e64b4b7b9f，04-verify 过
  （ESP↔rootfs 7.3.0-rc6 一致）；uinput 腿全套 + FSP=0 + 整包缓存命中播种（stable
  1791415817 新包 1.98G 免 CDN；v3 旧包留档 .v3.bak）。首启 rootfs-grow 自扩容照旧。
- **2026-10-09 换轨 Debian 13（新会话必读）**：用户拍板兴趣线弃 holo 底包、改
  **Debian 13 trixie genericcloud arm64（USTC 国内源）**；定位 = 纯兴趣/游戏性能线，
  **pmOS（nura）才是主战地，无回滚腿**（回滚 = nura 的 pmOS rootfs）。已删：Frame
  底包管线（00-fetch-frame/01-lay/parse-gpt/05-patch/04-verify-kernel-match，git 历史
  D 状态可考）、steamos-r77 镜像、dl bz2、frame-src/out 残留；holo 的
  `10-graft-m2381.sh` + `30-build-m2381.sh` 已随 Debian 过闸删除（git 历史可考）。
  **新管线四件**：`00-fetch-debian.sh`（USTC→TUNA→官方 + SHA512）→
  `01-lay-debian.sh`（qcow2→raw→blank ext4，清自带内核/cloud-init/host key）→
  `10-graft-debian.sh`（国内源 apt + Plasma 精简栈 + m2381 层注入 + 平移件：
  NCM gadget/usb0-ip/横屏 autostart/Steam ARM 播种/睡眠 mask；usb0 走 NM unmanaged
  预防针 + 直配单元，DNS 走 resolvectl）→ `30-build-debian.sh`（复用 20-m2381-layer /
  03-finalize / 04-verify-esp；产物默认 `meizu-meizu20-debian-r77.img` 10G）。
  Steam zip 走 `work/cache/steam-arm` 缓存（版本件名缓存，命中免下载，损坏自愈，
  30-build bind 进 chroot）；**整包缓存 `steam-client-full.tar.zst`（2026-10-10 自 v3
  实机 bootstrap 拉全后打包，1.5G/14500 项，含 .installed 清单）为最高优先播种源
  ——graft 第 9 步命中即零下载，回退 zip 流程**；设备侧恢复脚本 =
  `scripts/host/50-steam-client-restore.sh [IP] [备份]`（默认 172.16.42.1）。
  m2381 层（work/layer，287M）base 无关直用。
- **★ Steam 破局 + 扩满结案（2026-10-10 凌晨，新会话从这里接）**：**镜像账本**：
  v4 = `277b985683e5…65dde`（8.2G 保守版：缺 libgtk2.0-0t64/libopenal1，已退役）；
  **v5 = `c63d41006d5c…8e9912`（14G 整包种子版，离线扩容 14G 在案）= 设备现役**
  （10-09 深夜上机，SSH host key 轮换 = 重刷实锤；Debian 13.7；原 10G 满态
  SHA 1bf413c2 作废）。**扩满结案**：设备 /dev/sda22 文件系统 = 457G clean
  （分区 463.6G，差值 = ext4 元数据开销；用 9.5G 剩 429G）；ROOTFS_SIZE/
  zip-瘦身两案弃用，权威路径 = graft rootfs-grow.service 首启自扩（resize2fs，
  已满则 no-op，graft 在案）。**Steam 根因 = lsof 缺失**（Debian trixie 最小集
  不带；console_log 同一告警 1093 遍）：`GetIPCConnectionDetails` 跑
  `lsof -P -F upnR -i TCP@127.0.0.1:<port>` 反查 webhelper IPC 端口 → exit 127
  → steamui 连 WebUITransport 全部 "Connection rejected" → 白屏/"Unexpected
  Transport Error"、~90s 自退。设备 `apt install lsof` 复验：0 告警、端口↔进程
  映射解析正常、websocket accepted、**登录窗+QR 截图上屏**
  （/tmp/zcode/steam-shot-1.png）——v3 悬案"进程起 UI 不上屏"了结
  （libgtk2/libopenal/X11 三修仍有效，第四件 = lsof，graft PKGS 已补）。
  **下一步 = 用户实机登录 Steam**（账号密码或手机 QR），验登录后 store/好友/
  下载链路；未登录期 sharedconfig.vdf 的 RemoteStorage FileWrite false 属预期
  （will retry，登录后观察）；IPv6 TIMEOUT 定性 = 非致命（IPv4 通，登录窗能出
  即证）。会话纪律不变：SDDM Wayland 自动登录、锁屏关、调试走会话内件
  （kwin 自管 :0 + /run/user/1000/xauth_* 票据）。
- **★ 掌机模式定版（2026-10-10 凌晨，开机即 Deck UI · 最小 kwin 路线）**：gamescope
  standalone **判死**——本内核 msm DPU 平面不声明 IN_FORMATS（debugfs state 里
  in_formats=0，只吃线性缓冲），gamescope 的 turnip 平铺输出每次 atomic flip 被
  EINVAL 拒 → 永久黑屏（color/layers/composition/60Hz 全试过无效）；llvmpipe 合成
  缺 VK_EXT_physical_device_drm 也死。**权威路线 = 最小 kwin(DRM, GBM 线性分配,
  本面板 120Hz 已证) + steam -gamepadui**：省 plasmashell 657M/polkit 167M/maliit
  167M（kwin 自身 ~300M），GPU 合成不倒退。设备在役：SDDM autologin
  Session=steamos-session → /usr/local/bin/steamos-session（kwin --xwayland +
  steam-arm -gamepadui，横屏/120Hz 沿 kwinoutputconfig.json 持久化），Plasma 留
  SDDM 第二会话项。会话件三坑已固化进 graft：①kwin 6.3 必须显式 `--xwayland`
  （否则 steam "Unable to open X11 display"，sddm 拆会话连坐杀 kwin，日志只在
  /tmp/kwin-session.log）；②本镜像 tmpfiles 不建 /tmp/.X11-unix（x11-common conf
  缺失，graft 已补 /etc/tmpfiles.d/x11-unix.conf）；③gamescopereaper 补链
  /usr/lib/gamescope + /usr/local/bin。快速设置（WiFi/电源/蓝牙）= Steam 客户端
  直连 NM/BlueZ/logind（Bazzite 同构；steamos-manager 只服务真 Deck EC/TDP 硬件，
  SM8550 不需要）；**WiFi 密码未持久化**（设备档案缺 secrets，重启即断网），
  首件事 = 在 Deck UI 网络设置输一次 PSK。gamescope 翻案唯一路径 = 内核
  IN_FORMATS 补丁（pmOS 主战线；新版 mainline msm 疑似自带，值得查证）；嵌套
  gamescope（wayland 后端）不受影响照旧可用。**GPU 调频坑（同日实测）**：游戏重载
  后 simple_ondemand 会瞎——感知不到 kwin 合成负载，钉死 220MHz 最低档（频率表
  220→680 八档；governors 只有 userspace/simple_ondemand，无 performance）→ 全界面
  发卡。临时修 = min_freq 钳 401MHz（会话脚本开机自动 + gpu-perf/gpu-quiet 游戏拉
  满频开关，均已固化 graft）；根治 = pmOS 线查 devfreq busy 统计/GMU 状态（伴生
  dmesg 痕迹：adreno_gmu "delay in fenced register write (0x8a1)"）。**已升级为
  看护方案（同日凌晨）**：重绑 governor 即复活（`echo simple_ondemand >
  /sys/class/devfreq/3d00000.gpu/governor`，cur 立回 615→680 正常爬，trans_stat
  换档史 1849 次全在）——调度逻辑没坏，是重载冲击后 governor 状态卡死。
  gpu-ondemand-watch.service（检测"钉死最低档+零换档"30s → 重绑唤醒）已固化
  graft 并在机启用；min_freq 钳位撤除；真修复 = pmOS 线 devfreq/msm 补丁
  （证据三件套：trans_stat 冻结 + rebind 复活 + GMU 警告），落地后删看护。
  **掌机/桌面切换（同日）**：`sm20-session desktop|handheld|status`（设备侧）/
  `scripts/host/60-session-switch.sh [desktop|handheld]`（宿主侧）——desktop 置
  一次性旗标 /var/lib/sm20/want-desktop，下次 autologin 进 Plasma（注销/重启自动
  回掌机）；黑屏自救（大屏窗口被最小化时 steam 活着但无窗）= `sm20-session
  handheld` 重启会话。**同日收尾**：①`-steamos3` 旗标点亮 Deck 式设置面板
  （WiFi 分栏出现，用户已在掌机界面原生连上家里 WiFi——系统级+密码落盘，重念不丢；
  Plasma 密钥环坑：applet 默认存"仅本用户+kwallet"，换会话形态=没存）；②客户端
  频道已切 steamdeck_publicbeta（原 steamdeck_stable）；③SDDM `Relogin=true`
  已固化（autologin 只在服务启动时生效一次，steam 更新退出会掉登录屏）；④
  libpam-kwallet5 已卸（PAM 钩子会白白拉起 kwalletd；kwallet6 本体不能删——
  连坐 plasma-pa/kscreenlocker/plasma-integration 等桌面内脏）。
- **⚠ 宿主事故（2026-10-09，已恢复）**：Debian 首跑 chroot 死于宿主 binfmt 是
  OC-flag（无 F）；修复时手写 binfmt hex 的 mask 长度写歪 → 宿主全进程 exec ELOOP，
  用户 GRUB 加 `module_blacklist=binfmt_misc` 重启救回。复盘与正确注册法见记忆
  sm20-binfmt-incident-20261009（要点：逐字节照抄 /usr/lib/binfmt.d/qemu-aarch64.conf
  只改 flags=F + 当场冒烟；手写 hex = 高危）。重启后发行版新 conf 自带 F，chroot
  冒烟（CHROOT-QEMU-OK）通过，构建续跑中。
- **下个会话设备日执行单（2026-10-09 排定，v3）**：**用户已误刷一版裸底包**（deb3 被
  stop 后 sudo 子进程脱管成孤儿、与 deb4 并发互踩，产物 = 09:59 的无 graft 裸 cloud
  镜像：无触屏/无键盘/无 gadget，设备被锁在外面——**这版救不回来，直接重刷**）。
  v3 已出炉（2026-10-09 20:59，8.1G，SHA256 d69da03c97878f64e30035c94c1f9acfe43d450b32af5a12b6ffb671a48ed571，
  Steam 播种完整 408M + .install-complete，04-verify 过）。刷机 = `fastboot flash userdata
  work/meizu-meizu20-debian-r77.img`（只动 userdata；root/steamos 密码均 123456）。
- **设备日首启四修（2026-10-09 晚，v3 已刷实机并在机）**：① sshd 起不来（22 refused）
  = Debian graft 丢了 holo 版的 `ssh-keygen -A`（01-lay 删底包 host key + openssh-server
  预装不重跑 postinst）——设备上手动补 key 后 SSH 恢复；graft 已补该行。② USB 通道
  "连不上"真因 = 宿主 udev 改名规则 `DEVPATH~="*18d1*4ee1*"` 从未生效（DEVPATH 不含
  VID:PID），网卡一直叫 enp104s0f3u1、NM profile 只认 sm20ncm → 无人配 IP；已改写规则为
  `ATTRS{idVendor}/ATTRS{idProduct}` 匹配（下次插线自动改名+autoconnect），本次会话手工
  `ip addr add 172.16.42.2/24 dev enp104s0f3u1`，`ssh root@172.16.42.1` 实测通。③
  应用菜单无 Steam = 种子无 .desktop，graft 从来没放过入口——设备+graft 双补
  steam-arm.desktop（Exec=/usr/local/bin/steam-arm）。④ 根分区仅剩 1.2G（finalize 收缩
  后 FS<分区）——在线 `resize2fs /dev/sda22` 长满 457G；graft 新增 rootfs-grow.service
  首启自扩容。另：设备时钟已对（RTC 无电池每boot会漂，检查项）；睡眠 mask 在位
  （sleep/suspend/hibernate 全 → /dev/null）；WiFi 用户已手动连上。设备侧待验：
  Steam 菜单首启、Proton 兼容层、maliit 虚拟键盘。
- **设备日晚场二：Steam 起不来定位 + 出网政策拍板 + gamescope 上机（2026-10-09 深夜）**：
  ⑤ Steam 菜单点没反应 = 两层根因叠加：`~/.steam/steam` 数据链缺失（launcher 只建了
  sdkarm64 一根链，客户端直启 assert 退出）——设备手补 steam/root 两根链 + graft launcher
  已补；出网被 `m2381-usb0-ip` 的 metric-500 默认路由截胡（走宿主 NAT，而宿主 firewalld
  对非 zone 接口的转发包一律 reject——若将来要 NAT 上行，需 firewall-cmd 把接口加
  trusted zone，本次未做）。⑥ **用户拍板：设备出网走自身 WiFi，usb0 只做调试通道**——
  m2381-usb0-ip 单元已剥掉默认路由+DNS（设备与 graft 双同步），撤路由后 Steam CDN
  即通。⑦ 首启进 updater 后因无 .installed 清单走全量 651MB 重下，设备 WiFi 直连
  CDN 仅 ~95KB/s（v6 无路由），后台挂着续传（logs/bootstrap_log.txt 看进度），预计
  深夜跑完，跑完前菜单图标无窗口属正常。⑧ **gamescope 实锤可装**：trixie 主仓没有、
  **trixie-backports 有 3.16.22+ds-1~bpo13+1**（USTC 镜像同步）——设备已装可跑
  （二进制在 `/usr/games/gamescope`，非登录 shell PATH 外）；graft 已固化
  （sources.list 加 backports 行 + 可选件段改 `-t trixie-backports` 安装）。
  测试序列：①通道 `ssh root@172.16.42.1`（NCM gadget + m2381-usb0-ip 直配 +
  宿主 sm20ncm/NAT 已固化；兜底 = fe80 NDP 发现法）②桌面：SDDM 自动登录
  steamos/Plasma-Wayland、横屏 autostart、**触屏**（meizu-touch 同 holo 已验链路）、
  **虚拟键盘**（maliit-keyboard 已装，kwin-wayland 下首验）③**Steam**：`steam-arm`
  首启拷种子+自动更新，闪退就再跑一次（steam.md）④**兼容层**：Proton 11 Beta ARM +
  SteamLinuxRuntimeARM → `m2381-proton-setup <tar>` 或 Steam UI 自拉，装完全退 Steam
  再开⑤**gamescope**：trixie 主仓没有、**trixie-backports 有 3.16.22**（v3 实机已装
  可跑 /usr/games/gamescope；graft 已固化 backports 源+安装行）⑥性能基线：
  glmark2-wayland / vulkaninfo（freedreno a740）⑦WiFi 用户已手动连上 ✓ ⑧声音 = **不等
  r78**（2026-10-09 主项目复核：r77 已含完整音频块，「r77 钉 9-14 源码」系误读
  APKBUILD 出处注释 `_commit`；真缺口 = 用户态编排，清单 = `docs/archive/M2381-SOUND-REQ.md`
  §6；四问已由 nura AGENTS 带话节回信）——**编排串已平移实机出声 ✓**（深夜 v3 实机：
  amps→sndcard-bind→audio-route 三件 enable 后 card0 出卡、硬件直放出声、PipeWire
  sink「Built-in Audio Stereo」；`20-m2381-layer` ③b 段 + graft enable/自检已固化）。
  steam.md 原方 =
  github.com/code002-2/Xiaomi-pad-6s-pro-Linux/blob/sheng/docs/steam.md。
  **运维铁律（本轮血泪）**：停构建绝不能只 `systemctl stop`（外层 bash 死、sudo 子进程
  脱管成孤儿）——必须宿主侧 `pgrep -f 30-build` 核实 + kill 进程树 + 清 /mnt 残挂，
  再起新构建；起构建前先 ps 确认无同类进程。**杀设备进程严禁裸 `pkill -f <词>`**
  ——`-f` 匹配进程全命令行，会命中自己 SSH 远端脚本的文本把自己杀掉（SSH 假死，
  2026-10-10 实锤）；用 `pkill -x -u steamos <进程名>`（精确名+限定用户）。
- 设备现状：**在跑无 graft 的裸 Debian cloud 镜像**（deb3 孤儿互踩产物，无触屏/无键盘/
  无 gadget，救不回，等 v3 重刷）；~~声音两条线同源 = 等 pmOS r78 内核（r77 钉 9-14
  源码，早于 m2381 音频提交）。~~ **更正（10-09 主项目复核）：r77 已含完整音频块
  （pmOS 出声至今），无声 = 缺设备包用户态编排，清单 = SOUND-REQ §6，内核侧零等待。**
- 上游克隆仍钉在 `main @ bbc60650`（原样留作 diff 基准）；m2381 现役管线 =
  `10-graft-debian.sh` + `20-m2381-layer.sh` + `30-build-debian.sh` +
  `04-verify-esp-kernel-match.sh`（holo 变体已删，改动清单 git 历史可考）。
- 设备 = 魅族 20 m2381，现役 pmOS（mu-r66/ESP v47/内核 #67/device r53/rootfs r53）。
  本项目**只动 userdata**（换 rootfs），boot_b/ESP/recovery 全不碰——回滚 = 重刷 pmOS
  rootfs，30 秒锚照旧。

## 仓库结构（2026-10-11 重组；参考上游布局，主体 = 保住镜像构建流）

**料件原则：内核 apk + 固件 apk = nura 线料件，pmOS rootfs 与本 armada rootfs 通用
同一套**——用户到 nura 侧取最新版（kernel-m2381/BUILD.env 钉当前验证版+兼容门禁），
配合刷本仓出的 armada rootfs 即可。

```
armada-meizu-m2381/
├── build_files/      构建流：build.sh（主适配，原 40-adapt）、fetch-base.sh（上游 rootfs 取件）
├── system_files/     m2381 覆盖层【git 真身】：设备档案/编排单元/黑名单/UCM/NCM/RTC/polkit
├── kernel-m2381/     内核腿钉子：BUILD.env（apk sha256/腿配对 sha）+ fetch.sh
├── post_process/     finalize（收缩对齐）/ verify（21 项点验）
├── docs/             索引 README + 刷机指南 + 现行参考；archive/=旧线归档
├── legacy/           （已清 2026-10-11：debian 管线+会话件随 Debian 线弃用全删，git 历史可考）
├── config.sh         全局钉子
├── Justfile          fetch-base / fetch-kernel / adapt / verify
└── AGENTS.md         本文档
work/、dl/ = gitignore（镜像/apk/固件大件不进仓；固件回退源 = work/layer）。
**旧镜像清库（2026-10-11 用户拍板「不留回滚，现在的比任意旧版本都好」）**：宿主仅存
armada-r81.img（现役可刷锚）+ 钉子 apk 件（r81/固件 1-r3）+ steam 播种/gamescope 栈缓存；
debian-r77/r78、pmOS r66 分卷、ESP 旧腿、Frame 收档件全清——ESP 全梯（v43→v63 gz）与
pmOS rootfs 现役件都在 nura artifacts，Frame 官方源长期可下。设备侧 .r81-bak/.r80-bak
模块树暂留（r82 实验腿的在机保险，r83 轮收官后撤）。
**旧路径对照**：build_files/build.sh → build_files/build.sh；
scripts/{host,in-chroot,device}/* → legacy/{debian,device}/；work/layer → system_files/（真身）。
```

## 底包镜像（自动获取，无需手动）

- Debian 线：`30-build-debian.sh` 缺料自动跑 `00-fetch-debian.sh`，源序 =
  USTC → TUNA → cloud.debian.org，SHA512SUMS 强校验，产物缓存 `work/out/*.qcow2`。
- （已弃）holo Frame 底包管线已删，需要考古走 git 历史；Valve 官方源
  `steamdeck-images.steamos.cloud/recovery/steamframe-repair-latest.img.bz2` 长期有效。

## 上游管线 → m2381 改造点（keep / replace / skip）

| 上游件 | 判 | m2381 对应 |
|---|---|---|
| `00-fetch-frame-rootfs.sh` + `parse-gpt.py` | **keep** | 原样用；本地镜像走 file:// URL；rootfs 分区是 btrfs（subvolid=5 挂顶层，勿按 zstd 偏移切片——上游踩过的坑） |
| workflow `packages` job（archlinux-sheng `_packages.yml`，pacman 设备包×16 + ianchb 内核/固件） | **replace** | 我们的层 = ①fork 内核 `/usr/lib/modules`（从在机同源 apk `linux-meizu-meizu20-r66` 解出）②固件 tarball → `/lib/firmware` ③设备 units（meizu-touch 等，源头 = pmaports `device-meizu-meizu20`）④睡眠 mask（s2idle 睡死必防）。全部以**普通文件 cp 进 rootfs**，不需要 pacman 包 |
| `01-lay-rootfs.sh` | **keep** | 原样（btrfs→ext4 铺盘 + 清底包 modules/fstab/boot 残留） |
| `10-graft.sh`（1815 行核心注入） | **keep 主体 + 换头尾** | 头部「pacman -U 设备包 + depmod」段换成「拷我们的层 + depmod」；sheng 专属件（xiaomi-sheng-thp/devauth/fingerprint/sheng-wifi-backend 等）跳过；fstab(WITH PARTLABEL)/var 骨架/WiFi NM/root 密码/SSH pubkey/SDDM-Plasma/steam 客户端播种（bbc6065 的 Valve 掌机 ARM Steam + PartOf 修复）全保留 |
| `03-finalize-image.sh` | **keep** | 原样（收缩 + 固定 UUID；UUID 对我们无约束，我们 cmdline 是 root=/dev/sda22） |
| boot.img 拉取 + `05-patch-bootimg-cmdline.sh`（rootwait 补丁） | **skip** | 我们不刷 boot 分区——内核在 ESP（recovery_a，EFI stub，cmdline 已烤 root=/dev/sda22）；sheng 的 boot.img 是给 sheng ABL 的 |
| `04-verify-kernel-match.sh` | **keep 思路** | 改造为「ESP vmlinuz-efi 的 `Linux version` 串 vs rootfs /usr/lib/modules 目录名」比对（防 vermagic 不一致黑屏，上游用多 tag 翻车换来的闸） |

## 本项目纪律（在主仓纪律之上的增量）

- **构建必须在宿主跑**（脚本全程 sudo + loop 挂载，agent 沙箱 NNP 必死——同 pmbootstrap
  规律）；长构建走 systemd-run，日志进 `/tmp/zcode/`。沙箱里试跑须 `sudo` 可用且先
  `dnf install btrfs-progs zstd`（Fedora 宿主自查）。
- **首次刷 SteamOS rootfs 前**：确认在机 pmOS rootfs img（回滚件）在手——nura Release r66
  rootfs 或本地重刷件；userdata 刷写 = 清掉 pmOS + /home 数据（waydroid/docker 镜像等），
  设备日当天用户点头才刷。
- **PARTLABEL 前置核对**：graft 写 `PARTLABEL=userdata /`——上机前在 pmOS 侧跑
  `ls /dev/disk/by-partlabel/ | grep userdata` 确认 GPT 名（预期就是 userdata，fastboot
  by-name 同源；不符则改 graft 的 PARTLABEL 入参）。
- root 密码不用默认 123456；WiFi 凭据只在构建入参，不进仓。
- 本仓私有；推送（若上游化）先建自建 fork，`origin` 已改名 `upstream` 指向 code002-2。

## 设备通道 / 回滚

- 通道：WiFi + sshd（构建期预配，P1 主通道）；NCM gadget = 内核侧现成、用户态配置挂 P1 可选；
  on-device konsole（触屏）兜底。
- 回滚锚（全不碰）：mu-r64-686a4c0f / v46 / r51（设备 `/home/user/esp-recovery-v26.img`）；
  宿主 30 秒配方 = t-b2（d4928661）+ esp-recovery-v4d（3b106f07）；rootfs 级回滚 =
  `fastboot flash userdata <pmOS rootfs.img>` + reboot（本项目的唯一刷写动作）。
- ⚠ s2idle 睡死定律在新 rootfs 同样成立：镜像内已列「sleep target 全 mask」为 P0 必做项，
  首启再复核 powerdevil 自动睡眠关。

## 排程

- **P0 宿主构建轮 ✅（2026-10-08 完成）**：一条命令 = 宿主 `30-build-m2381.sh`
  （缺料自动补 00-fetch/20-layer → 01-lay → chroot graft → 03-finalize → 04-verify-esp）。
  产物与宿主通道细节见构建台账；重跑（换入参如 WiFi/密码）直接再跑一遍即可
  （01-lay 会删 rootfs.frame，脚本自动重取）。
- **P1 spike 设备日（下一步）**：刷 userdata → SSH 里程碑 → 触控/GL/VK/Steam 客户端判生死；
  不达 = 重刷 pmOS rootfs 零损失退出。刷前核对 = pmOS 侧 `ls /dev/disk/by-partlabel/ | grep userdata`
  + 回滚件（pmOS rootfs img）在宿主 + 用户点头。
- **P2 日用化**：音频 PipeWire 翻译（UCM 复用 + 直驱钉值重表达）/ hexagonrpcd glibc 重建 +
  传感器链 / 震动 udev / 手柄映射 / 性能与温控观察。
