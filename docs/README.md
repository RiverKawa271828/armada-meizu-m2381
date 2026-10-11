# docs — 索引

m2381 × Armada 移植全程的工作文档。阅读顺序 = 新会话/新读者从上往下。

## 现行（活跃参考）

| 文档 | 内容 | 一句话 |
|---|---|---|
| [M2381-ARMADA-PORT-20261011.md](M2381-ARMADA-PORT-20261011.md) | **移植正典** | 底盘选型/构建台账/首启八抓虫/判决/回滚，想知道"为什么是现在这个样子"看这里 |
| [M2381-ARMADA-RECON-20261010.md](M2381-ARMADA-RECON-20261010.md) | 上游考据 | armada-sheng 会话栈/输入栈/睡眠栈逐层读透，InputPlumber→deck-uhid 与 fake-suspend 的出处 |
| [M2381-KERNEL-ENHANCE.md](M2381-KERNEL-ENHANCE.md) | 内核协作台账 | r80 四合一回归 + 内核诉求清单（async flip / rotation / uhid / SQUASHFS_ZSTD），对接 nura 线用 |
| [M2381-NURA-RELAY-20261011.md](M2381-NURA-RELAY-20261011.md) | 回传文本 | 发给 nura 的收官消息（钉版请求+新诉求+情报），留档可考 |
| [M2381-NURA-RELAY-20261011-R81.md](M2381-NURA-RELAY-20261011-R81.md) | 回信（最新） | r81/v62 点火 PASS 回执 + qbootctl 治 fastboot 停车通报 + v62 裸镜像哈希勘误 + apk 公开链接请求 |
| [ISSUE-DRAFT-armada-sheng.md](ISSUE-DRAFT-armada-sheng.md) | issue 草稿 | 给上游 armada-sheng 的问询草稿（A/B 槽位标记 + 三症状报捷），待用户过目后发 |
| [M2381-ROUTE-REEVAL-20261010.md](M2381-ROUTE-REEVAL-20261010.md) | 决策史 | 三条线（官方 Frame / Debian / armada）的换轨账，为什么终决 armada |
| [flashing-meizu-m2381.md](flashing-meizu-m2381.md) | **刷机指南** | 用户向：前提/三步刷机/首启/调试通道/回滚/已知限制 |

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
