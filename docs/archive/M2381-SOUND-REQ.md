> ⚠ 已归档（2026-10-11）：音频需求清单（已由 KERNEL-ENHANCE 接续并落地验证）。现行文档见 docs/README.md 索引。

# m2381 声卡适配要求（SteamOS/Debian 线 → 主项目 pmOS/nura 内核线）

> 2026-10-09 由 steamos-meizu20 线整理，供转告主项目。判词出处：
> `pmos_linux/docs/meizu20/steam-armada-assessment-20261008.md` + 本仓 AGENTS.md 声音定论。
> 一句话背景：~~两线内核腿同源（ESP v58/r77 + 层模块直灌），r77 钉 9-14 源码
> （pmaports _commit=587858367581），而 m2381 音频整块（DTS sound 节点 9-30 /
> sc8280xp.c 的 meizu sndcard 兼容 10-06）在钉子之后 ⇒ r77 的 snd 模块里没有
> `meizu,meizu-20-sndcard` compatible ⇒ 驱动不绑、无声卡。两条线此刻都没声音，
> 唯一解 = r78 内核 bump，SteamOS 侧零代码，等同步即可。~~
>
> **★前提作废（2026-10-09 主项目实测复核；判词与出声必需清单权威版见 §6，
> §1/§3 按「已满足」存档读）**：`_commit=587858367581` 是 pmaports APKBUILD 中
> **无引用的出处注释**（fork 基点备忘），`source=` 实为每轮从 fork 分支
> meizu20-t4b 现打的本地 tarball。开盖 r77 tarball 实测：`meizu,meizu-20-sndcard`
> compatible（sc8280xp.c:581）+ DTS sound 节点（sm8550-meizu-20.dts:425）+
> binding yaml 三处全在，CONFIG 全套 =m。**r77 含完整音频块、pmOS 出声至今；
> 音频不需要 r78 bump。**Debian 无声真因（高置信）= 缺设备包声卡启动编排
> （§6 清单）。

## 1. 内核侧要求（r78 bump 验收项）

1. **源码范围**：r78 rebase 需把 m2381 音频整块带上——
   - `arch/arm64/boot/dts/qcom/sm8550-meizu-20.dts` 的 sound 节点（9-30 提交）
   - `sound/soc/qcom/sc8280xp.c` 的 `meizu,meizu-20-sndcard` 兼容条目（10-06 提交）
   - cs35l45 codec 驱动（扬声器功放）+ 对应 binding yaml 同名
     （nura `script/verify.sh` 已有 "binding yaml 新名" 检查项，r78 应转绿）
2. **CONFIG 抽查**（build config 里确认真开了，且产物里有对应 .ko 或内建）：
   - `CONFIG_SND_SOC_SC8280XP`（machine driver）
   - QDSP6/audio reach 全家（q6apm/q6apm-lpass 等 `CONFIG_SND_SOC_QDSP6_*`）
   - codec/功放：cs35l45（+wm_adsp 依赖）、WCD938X（若 DTS 用到）
   - macro 三件（tx/rx/va `CONFIG_SND_SOC_LPASS_*_MACRO`）+ `CONFIG_SND_SOC_QCOM_COMMON`
   - ADSP 固件加载链：pd-mapping / `qcom/sm8550` adsps firmware 在 linux-firmware 里
     现成可用（dmesg 不许有 firmware load 失败）
3. **交付形式照旧**：apk 内核包 bump → 两线各自取 `/usr/lib/modules`
   （SteamOS 侧 = `20-m2381-layer.sh` 从在机同源 apk 解出）；ESP vmlinuz-efi 同步
   bump（ESP vXX），`04-verify-esp-kernel-match` 闸卡 vermagic 一致。

## 2. 用户态最小集（要对方 r78 定型后给"出声必需清单"）

kernel/固件之外，出声还差的都是设备包用户态件。请 r78 定型后给一份照单平移清单：

1. **UCM2**：`MEIZU20.conf` / `HiFi.conf`（PipeWire 两线同吃；Debian 侧已装
   pipewire/pipewire-pulse/wireplumber，UCM 文件放对路径即生效）
2. **topology**：`MEIZU20-tplg.bin`（若该路径在用）
3. **服务/脚本串**：`meizu-sndcard-bind` / `meizu-amps-load` / `meizu-audio-route`
   （名字以 nura 仓为准；amps-load 涉及 cs35l45 固件/使能顺序）
4. **听筒当听筒 remap**：route/UCM 里的等价件（评估文档点名的翻译工作）
5. cs35l45 的 **wm_adsp DSP 固件**是否在固件包（现 r3）里？r78 要不要连固件一起
   出新版？（= 已转告的四问之 3）

## 3. 同步机制与优先级

- 不阻塞主项目排程：SteamOS 线可等 r78 发布再同步（= 已转告四问之 4）。
- r78 出包后回话一声即可；SteamOS 侧动作 = 重跑 `20-m2381-layer` → `30-build`
  重出镜像 → 只刷 userdata（回滚腿照旧）。
- 用户态件照第 2 节清单平移进 Debian 层（`20-m2381-layer` 或 graft 直放）。

## 4. 两线通用验收 DoD（r78 同步后）

1. `aplay -l` 能看到声卡（sndcard 驱动绑定成功，无 "no sound cards found"）
2. `dmesg` 无 q6apm/ADSP firmware 加载失败；cs35l45 probes 正常
3. `speaker-test`/`wpctl` 出声：双扬声器、听筒各自通路正确（听筒不当扬声器响）
4. 录音通路可用（主 mic；通话降噪链不验收，能录即可）
5. PipeWire：`wpctl status` 见 sink/source，UCM verb 可切换（HiFi/Speaker 等）
6. 回归旧病：长时间播放不哑火/不爆音（评估文档风险 1 的设备日验证项）；
   游戏场景先按"能出声"降级验收。

## 5. 附：已转告四问（2026-10-09，nura AGENTS "带话"节）

1. r78 会不会把 m2381 音频整块带上（DTS + sc8280xp.c meizu 条目 + cs35l45）？
2. 声卡 kernel 侧对方判 = 通用；用户态最小集清单 = 本文第 2 节。
3. cs35l45 wm_adsp 固件在固件包（现 r3）里吗？r78 要不要连固件一起出？
4. 对方可等 r78 发布再同步，不阻塞排程。

## 6. 主项目回信（2026-10-09 复核轮）——判词更正 + 出声必需清单（权威版）

**判词**：r77 已含完整 m2381 音频块（开盖 source tarball 实测：sndcard compatible +
DTS sound 节点 + binding yaml 三处全在，CONFIG 全套 =m；pmOS 10-04 起出声至今）。
**音频不需要 r78 bump，内核腿零等待。**四问逐条：① r77 已带；② 清单见下表；
③ wm_adsp 固件**已在固件包 r3**（`cirrus/cs35l45-{spk,rcv}-dsp1-spk-prot.{wmfw,bin}`
+ `qcom/sm8550/meizu/adsp.*`），无需固件新版，且现行出声路径 = 直驱绕 DSP，
wmfw 非必需；④ 收到不阻塞，可先对接现役 r77，或等 7.3 stable rebase（~10 月中）随车。

**出声必需清单（device-meizu-meizu20 包内，文件名以包内为准）**：

| 类别 | 件 | 备注 |
|---|---|---|
| UCM2 | `MEIZU20.conf` + `HiFi.conf` | PipeWire 直用，放对 ucm2 路径即生效 |
| topology | `MEIZU20-tplg.bin` | **在设备包，不在固件包** |
| 服务串 | `meizu-sndcard-bind.service/.sh` → `meizu-amps.service` + `meizu-amps-load.sh` → `meizu-audio-route.service/.sh` | **声卡非自然 probe**（竞态破案 = device r47）：autoprobe=1→pinctrl→va→sound 按序编排；使能集看 `80-device-meizu-meizu20.preset` |
| 时序 | — | ADSP ~boot+75s 才就绪；pmOS guard = 2s 轮询/6.5min 预算，Debian 层须同等重试耐心 |
| 固件 | 已在 r3 | cirrus 六件 + `qcom/sm8550/meizu/adsp.*`，无需新版 |
| 可选 | `meizu20-spk-mono.pa` | 听筒当听筒 remap（pulse 版）；PipeWire 自行翻译；「能出声」不依赖 |

**Debian 无声真因（高置信）= 缺服务串这一层**，先补编排再谈内核。验收 DoD 沿用 §4，
前置一条：sndcard-bind 等价物跑完后 `aplay -l` 先出卡，再验 wpctl/UCM。
