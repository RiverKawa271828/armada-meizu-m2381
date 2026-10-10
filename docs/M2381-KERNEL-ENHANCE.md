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
