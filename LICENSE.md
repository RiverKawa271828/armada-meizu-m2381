# Licenses

本仓是 Meizu 20 (m2381 / SM8550) 的 Armada 适配层，由多个开源成分组成，
各自保留其原始许可。

## 本仓原创内容

构建脚本（build_files/、post_process/、kernel-m2381/）、system_files/ 中的
m2381 覆盖层、docs/ 工作文档，以 **GPL-2.0-or-later** 提供（与上游 Armada 同
许可家族）：

    Copyright (C) armada-meizu-m2381 contributors

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
    General Public License for more details.

    https://www.gnu.org/licenses/old-licenses/gpl-2.0.html

## 派生与上游成分（各自保留原许可）

- **Armada**（[armada-os/armada](https://github.com/armada-os/armada) 及
  code002-2/armada-sheng）—— rootfs 底盘、部分构建流形态参考，GPL-2.0-or-later；
- **pmOS meizu20 线（nura）** —— 内核 apk、固件 apk、boot 链（GPL-2.0，内核源码
  随其仓库发布）；本仓不重分发料件本体，只钉版本与校验；
- **ROCKNIX / Bazzite（ublue）** —— 上游 Armada 设备适配与镜像工具的源头
  （GPL-2.0 / Apache-2.0，经 Armada 间接引入）；
- pmaports（postmarketOS）—— meizu20 设备包（触屏/音频编排脚本原型），GPL-2.0-or-later。

发衍生的镜像产物时：镜像内 Steam 客户端为 Valve 专有软件，按上游 Armada 同款
口径分发；内核/固件料件的公开下载以 nura 线的 Release 为准。
