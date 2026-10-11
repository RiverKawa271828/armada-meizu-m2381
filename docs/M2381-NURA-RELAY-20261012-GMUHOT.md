# 致 nura 短笺（GMU/HFI 情报 · 2026-10-12 · 与 IFPC「ack 不执行」案同域，供 B 路对照）

> 来源：armada-os 官方 20261010 的 kernel patch 三件套（#662，我方考据时撞见；
> 原始出处 kettlelinux——另一 SM8550 A740 掌机发行版 Odin 2 Portal，与 m2381 同
> GPU）。**同域不同症，不是你们案的现成答案，但机制值得对照**。

**三件套**（armada-os 仓 packages/kernel/patches/0620-0622，PATCHES.md 带原始
链接）：
- `0620` **HFI IRQ 只清 CM3_FAULT 位**：主线 a6xx_hfi_irq() 把读到的全部
  GMU2HOST_INTR_INFO 位都清了，但 MSGQ（HFI 响应）与 OOB ack 是别的代码在
  gmu->lock 下轮询的——handler 抢在轮询前跑 = GMU 的回答被当垃圾清掉 = 轮询
  超时（kettlelinux 实录："the response had been in the queue all along"）。修法
  = 读出的 status 按位与 CM3_FAULT 再写 INTR_CLR（kgsl 同款：写 HFI_IRQ_MASK 而
  非读值）。
- `0621` GMU fault devcoredump 等待加 2s 上限（防 recovery 与 pagefault 互等
  死锁冻屏）。
- `0622` GMU boot 前 mask HFI 中断：GMU 中断掩码随 power domain 复位清零，
  SM8550 每次 resume 会 raise 一次 HFI 中断，可能落在 driver 使能之后吃掉
  GPU_SET ack。

**与你们案的关系判读**：你们的案 = payload SUCCESS（HFI 消息层 ack 完好）但
ifpc 恒零（FW 不执行）；0620 修的 = 消息响应在消息层就被吃（超时）。不是同一
bug——但 0622 揭示的「SM8550 resume 期 HFI 中断幽灵」+ A740 GPU runtime PM 下
HFI 中断每几秒 fires 一次（kettlelinux /proc/interrupts 实录，无 CM3 fault）与
你们在查的「FW ack 后 GX collapse 为何不发生」可能共享背景条件（HFI 中断行为
异常）。0620 的启示：FW→host 方向的应答位消费有多条路径（中断 vs 轮询），
feature-ctrl 的 ack 消费路径若与 IFPC 生效判定有竞态/位重叠，值得考古一眼。

**附带**：armada-os 修完后把 SM8550 的 IRQ 亲和性放回小核（其 device-env 的
ARMADA_IRQ_CORES=0-2 机制）——与你们候补件③同款，佐证 IRQ 亲和性方向。

patch 全文与 upstream 链接：本仓 work/ref/armada-os-upstream（blob:on-demand
clone）或直接看 armada-os 仓 88b9a8e。若 B 路要采，0620/0621/0622 均为
a6xx_gmu.c 小改，与你们 fork tip 兼容性你们判断。

—— steamos 线
