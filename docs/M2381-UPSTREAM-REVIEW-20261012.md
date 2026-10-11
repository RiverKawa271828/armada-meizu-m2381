# m2381 上游评估：armada-os vs armada-sheng（2026-10-12，nura 忙其他事、我方独立推进轮）

## 结论先行

**fork 上游维持 = armada-sheng（code002-2/armada-sheng），新增内容上游观察源 =
armada-os（armada-os/armada）**。两者不是竞争关系而是供应链上下级；remotes 已按
此配置（原 `upstream` 老 Frame 仓改名 `frame-upstream` 留档）：

```
armada-os/armada（官方主线：kernel patches + 用户态包 + 设备支持）
    ↓ sheng 定期同步（upstream-sync 分支 → PR 合 main）
code002-2/armada-sheng（sheng 适配 fork：出 sheng-flashable 单分区裸 ext4）
    ↓ 我方 fork（fork 点 = 7cf8163 = sheng main HEAD）
本仓 RiverKawa271828/armada-meizu-m2381（m2381 适配 overlay）
```

**判据**：
- 形态：armada-os 官方 20261010 仍是整盘镜像分层/OTA 格式（downloads.armadaos.dev
  分发），不合我方 fastboot 单分区模型——不可直接当基线；armada-sheng 的
  sheng-flashable（container-export 单分区 ext4）正是我方底盘（v1.2 在役）。
- 血统：我方 fork 点 = sheng main @ 7cf8163（含 PR #24 = 首轮 armada-os 同步，
  截止 armada-os 816091e ≈ FEX 2610 那轮）——diff 基线在 sheng，换上游 = 重定
  基线纯亏。
- 内容流向：所有实质创新（kernel patches/包版本/设备档案）都从 armada-os 流向
  sheng——观察 armada-os = 提前拿货；sheng upstream-sync 分支 = 下一轮同步预告
  （现在领先 main 37 commits 未合）。

## armada-os 20261010 现态（我方 fork 点之后的新东西）

**发布形态**：单压缩整盘 `armada-20261010.img.gz`（image-layer/OTA 分层格式，
内部安装器可与 Android 共存）——**仍不合 fastboot 模型，维持「参照备胎」判词**。

**对 m2381 有直接价值的**（按相关度）：

1. **GMU wedge fix 三件套（#662，10-08，fork 点未含 / upstream-sync 已含）**：
   - `0620` HFI IRQ 只清 CM3_FAULT 位（**来源 kettlelinux**——另一 SM8550 A740
     掌机发行版 Odin 2 Portal）：a6xx_hfi_irq() 把读到的全部 INTR_INFO 位清掉，
     但 MSGQ（HFI 响应）与 OOB ack 是轮询的——handler 抢先清 = GMU 的回答丢了 =
     轮询超时（"the response had been in the queue all along"）。A740 + GPU
     runtime PM 下 HFI 中断每几秒 fires 一次（无 CM3 fault）。
   - `0621` GMU fault devcoredump 等待加 2s 上限（防 recovery deadlock 冻屏）。
   - `0622` GMU boot 前 mask HFI 中断（SM8550 每次 resume 会 raise 一次，可吃掉
     GPU_SET ack）。
   - **与 nura IFPC「ack 不执行」案的关系**：同域不同症——0620 修的是「响应被
     中断 handler 吃掉」（超时），nura 案是「payload SUCCESS 但 IFPC 不执行」
     （ack 到了、GX collapse 没发生）。非同一 bug，但都是 HFI 消息/ack 消费机制
     族——**转告 nura 对照**（patch 文本在本仓 work/ref/armada-os-upstream 可
     取，PATCHES.md 带 kettlelinux upstream 链接）。
   - 附带：修完后 **SM8550 中断回小核（ARMADA_IRQ_CORES=0-2）**——armada-os 的
     device-env 有 IRQ 亲和性机制，与 nura 候补件③（GMU/IRQ 亲和性）同款。
2. **hexagonrpc + libssc 包（upstream-sync 独有，45bd0bb/7bdf757/a70f016）**：
   官方直接出 hexagonrpc 包 + libssc 传感器 patch——**我方 P2 清单的
   hexagonrpcd glibc 重建 + 传感器链有现成参照**（sheng 下一轮同步后即可抄）。
3. **SM8550 专项**：睡眠功耗 -50%（20260926，已含于我们基线的一部分？需核对
   具体件）、Odin 2 电池续航（20261010）、HDR 支持 + **HDR direct scanout on
   SM8550**（20261010）、UFS/UART sleep backports（#647）。
4. **用户态栈领先**：Gamescope 3.16.31-ogc1（我方 3.16.19-257）、Mesa 26.2.4、
   FEX 2610、Proton CachyOS 11.0-20261005、InputPlumber 0.81、KWin/Plasma/
   powerdevil 更新——**sheng 下一轮同步（upstream-sync 领先的 37 commits）合入
   后随 sheng-flashable 升级即可拿到**。
5. 其他：Lepton Android app 运行（Aurora Store/双屏/手柄）、嵌套 Plasma 桌面、
   手柄校准重写、AYANEO haptics 烧核修复、Spectre v4 缓解去除（Oryon 核，SM8550
   X3 不适用）。

## armada-sheng 现态

- **main @ 7cf8163 未动**（= 我方 fork 点）；**upstream-sync 分支领先 37 commits**
  （同步至 armada-os 1e2802a #689，20261010 tag 之后）未合——下一轮 sheng-flashable
  预告。
- 未合 PR 若干（社区 PR，含 gyro toggle 等——已被 armada-os 上游 #685 revert 的
  gyro 线在 sheng PR 里还有，勿误采）。

## 行动清单（我方独立推进路线）

1. **remotes 已配**：`upstream` = armada-sheng（fork 基线）/ `armada-os` = 官方
   （内容观察源）/ `frame-upstream` = 老 Frame 仓留档。origin 待推送令时加
   （RiverKawa271828/armada-meizu-m2381）。
2. **sheng 下一轮同步观望**：upstream-sync 37 commits 合入 main 出新
   sheng-flashable 时，我方底盘可选升级（用户态栈 + hexagonrpc/libssc +
   SM8550 优化全进来）——升级 = 重建镜像（build.sh 换 fetch-base 目标版本），
   m2381 层照旧。**等 sheng 出件再动，不抢跑**。
3. **GMU wedge fix 转告 nura**（随 R84 回执或独立短笺）：三件套文本 +
   kettlelinux upstream 链接 + 「同域不同症」判读。
4. **不追的**：armada-os 官方镜像/OTA 形态（模型不合）；Lepton/嵌套桌面
   （sheng 同步后自然有）；HDR 直扫出（gamescope 版本墙，随栈升级）。
