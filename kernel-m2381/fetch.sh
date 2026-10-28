#!/bin/bash
# 取内核腿 apk：优先本地已知路径，缺失时尝试 KERNEL_APK_URL（待 nura 钉版）。
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "${REPO}/kernel-m2381/BUILD.env"
DEST="${REPO}/work/armada-m2381/apk"
# r91 起内核 release=7.3.0 而 apk 文件名 pkgver 惯性仍带 7.3.0_rc6——中缀不硬编码，
# 统一通配 + sha 门禁判真。
mkdir -p "${DEST}"

FOUND=""
for f in "${DEST}"/linux-meizu-meizu20-*-${KERNEL_APK_VERSION}.apk; do
    [ -f "$f" ] && { FOUND="$f"; break; }
done
if [ -z "${FOUND}" ] && [ -n "${KERNEL_APK_URL}" ]; then
    curl -fsSL --retry 3 -o "${DEST}/$(basename "${KERNEL_APK_URL}")" "${KERNEL_APK_URL}"
    FOUND="${DEST}/$(basename "${KERNEL_APK_URL}")"
fi
[ -n "${FOUND}" ] || {
    echo "ERROR: 找不到 ${KERNEL_APK_VERSION} apk。把设备 /root 的 apk 拷到 ${DEST}/ 或填 KERNEL_APK_URL" >&2
    exit 1
}
ACTUAL=$(sha256sum "${FOUND}" | cut -d' ' -f1)
[ "${ACTUAL}" = "${KERNEL_APK_SHA256}" ] || { echo "ERROR: sha256 失配 ${FOUND}" >&2; exit 1; }
echo "OK: ${FOUND} (${ACTUAL:0:8})"
