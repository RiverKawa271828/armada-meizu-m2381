# docs — 索引

m2381 × Armada 移植全程的工作文档。阅读顺序 = 新会话/新读者从上往下。

## 现行（活跃参考）

| 文档 | 内容 | 一句话 |
|---|---|---|
| [M2381-ARMADA-PORT-20261011.md](M2381-ARMADA-PORT-20261011.md) | **移植正典** | 底盘选型/构建台账/首启八抓虫/判决/回滚，想知道"为什么是现在这个样子"看这里（§11 GPU 线、§10b 探针轮） |
| [M2381-CARDMU-AUDIT-20261012.md](M2381-CARDMU-AUDIT-20261012.md) | **卡Mu事故全档** | 三盘审计→写伤实锤→对照实验定谳（ABL 强启撕裂写）→修复与固化全记录 |
| [M2381-UPSTREAM-REVIEW-20261012.md](M2381-UPSTREAM-REVIEW-20261012.md) | 上游评估 | fork 上游维持 armada-sheng + armada-os 观察源（GMU wedge fix 三件套） |
| [M2381-ARMADA-RECON-20261010.md](M2381-ARMADA-RECON-20261010.md) | 上游考据 | armada-sheng 会话栈/输入栈/睡眠栈逐层读透，InputPlumber→deck-uhid 与 fake-suspend 的出处 |
| [M2381-KERNEL-ENHANCE.md](M2381-KERNEL-ENHANCE.md) | 内核协作台账 | 四合一回归 + 内核诉求清单（async flip / rotation / uhid / SQUASHFS_ZSTD），对接 nura 线用 |
| [M2381-ROUTE-REEVAL-20261010.md](M2381-ROUTE-REEVAL-20261010.md) | 决策史 | 三条线（官方 Frame / Debian / armada）的换轨账，为什么终决 armada |
| [flashing-meizu-m2381.md](flashing-meizu-m2381.md) | **刷机指南** | 用户向：前提/三步刷机/首启/调试通道/回滚/ABL 僵死警告/已知限制 |

## 与 nura 线的往来信（内部协作记录）

| 文档 | 一句话 |
|---|---|
| [M2381-NURA-RELAY-20261011.md](M2381-NURA-RELAY-20261011.md) | 发给 nura 的收官消息（钉版请求+新诉求+情报） |
| [M2381-NURA-RELAY-20261011-R81.md](M2381-NURA-RELAY-20261011-R81.md) | r81/v62 点火 PASS 回执 + qbootctl 通报 |
| [M2381-NURA-RELAY-20261011-R82.md](M2381-NURA-RELAY-20261011-R82.md) | r82 点火轮回执 + 边界告知 |
| [M2381-NURA-RELAY-20261012-R83.md](M2381-NURA-RELAY-20261012-R83.md) | Phase-0 FAIL 回执 + v63 gz 回传 |
| [M2381-NURA-RELAY-20261012-R84.md](M2381-NURA-RELAY-20261012-R84.md) | r84/v65 B 路点火回执 |
| [M2381-NURA-RELAY-20261012-GMUHOT.md](M2381-NURA-RELAY-20261012-GMUHOT.md) | GMU wedge fix 情报短笺 |
| [ISSUE-DRAFT-armada-sheng.md](ISSUE-DRAFT-armada-sheng.md) | 给上游 armada-sheng 的问询草稿（待用户过目后发） |

## 归档（历史线，仅供考古）—— [archive/](archive/)

| 文档 | 时代 | 为什么归档 |
|---|---|---|
| [M2381-PLAN.md](archive/M2381-PLAN.md) | Frame/holo 线 | 执行计划被 armada 线整体取代 |
| [M2381-GAMESCOPE-IGNITION.md](archive/M2381-GAMESCOPE-IGNITION.md) | Debian 线 | gamescope standalone 点火手册；armada 会话层下仅作考古 |
| [M2381-SOUND-REQ.md](archive/M2381-SOUND-REQ.md) | Debian 线 | 音频需求清单，已由 KERNEL-ENHANCE 接续并实机验证 |

## 相关位置

- 仓库结构 / 构建入口 / 料件原则 → 仓根 `README.md` + `AGENTS.md`
- 会话级现态速记（新会话必读）→ 仓根 `AGENTS.md`「现态一句话」
- 上游结构参照（只读克隆）→ `work/ref/armada-sheng/`
