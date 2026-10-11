#!/bin/bash
# 收尾：e2fsck + 收缩到实际用量 + 4096 对齐。参数 = 镜像路径（.tmp）。
set -euo pipefail
IMG="${1:?usage: finalize-m2381-image.sh <img>}"
sudo e2fsck -f -y "${IMG}" >/dev/null 2>&1 || true
sudo resize2fs -M "${IMG}" | tail -1 || true
BLOCKS=$(sudo dumpe2fs -h "${IMG}" 2>/dev/null | sed -n 's/^Block count:[[:space:]]*//p')
BSIZE=$(sudo dumpe2fs -h "${IMG}" 2>/dev/null | sed -n 's/^Block size:[[:space:]]*//p')
# 4096 对齐：fastboot sparse 块链要求（不满 4K 倍数会被 ABL 拒）
[ -n "${BLOCKS}" ] && [ -n "${BSIZE}" ] && \
    sudo truncate -s "$(( (BLOCKS * BSIZE + 4095) / 4096 * 4096 ))" "${IMG}"
echo "finalize: $(stat -c %s "${IMG}") bytes"
