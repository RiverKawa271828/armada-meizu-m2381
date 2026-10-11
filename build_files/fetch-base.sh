#!/bin/bash
# 取上游 armada-sheng rootfs（sheng-flashable v1.2）八分卷 → 校验 → 合并。
# 产物: work/armada-m2381/dl/rootfs.img（裸 ext4 单分区，build.sh 的输入）
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DL="${REPO}/work/armada-m2381/dl"
mkdir -p "${DL}"; cd "${DL}"

GH=https://github.com/code002-2/armada-sheng/releases/download/sheng-flashable
M1=https://ghfast.top          # CN 加速镜像（直连慢时自动受益）；失败可删掉重试
ROOTFS_SHA256="719477ffac6def4f856b2f89010102c82a6b225f9ce9199b58d26397be080d52"

if [ -f rootfs.img ] && echo "${ROOTFS_SHA256}  rootfs.img" | sha256sum -c --quiet 2>/dev/null; then
    echo "OK: rootfs.img 已在且校验通过"; exit 0
fi

curl -fsSL -o SHA256SUMS.parts "${GH}/SHA256SUMS.parts"
curl -fsSL -o SHA256SUMS "${GH}/SHA256SUMS"

PARTS_OK=1
sha256sum -c SHA256SUMS.parts >/dev/null 2>&1 || PARTS_OK=0
if [ "${PARTS_OK}" -ne 1 ]; then
    for s in a b c d e f g h; do
        f="rootfs.img.part.a$s"
        [ -f "$f" ] && sha256sum "$f" | grep -qf - SHA256SUMS.parts 2>/dev/null && continue
        rm -f "$f" "$f.aria2"
        aria2c -x8 -s8 -k4M --file-allocation=none -c --summary-interval=60 \
            --max-tries=0 --retry-wait=3 --timeout=30 --lowest-speed-limit=20K \
            "${M1}/${GH}/${f}" "${GH}/${f}" -o "$f"
    done
    sha256sum -c SHA256SUMS.parts
fi

cat rootfs.img.part.a{a,b,c,d,e,f,g,h} > rootfs.img
echo "${ROOTFS_SHA256}  rootfs.img" | sha256sum -c -
echo "== DONE: ${DL}/rootfs.img"
