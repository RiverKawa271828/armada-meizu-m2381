#!/usr/bin/env bash
# 00-fetch-debian.sh —— 取 Debian 13 trixie genericcloud arm64 底包（国内源优先）
# 产物: work/out/debian-13-genericcloud-arm64.qcow2 + debian-base-info.txt
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$HERE/work/out"
F="debian-13-genericcloud-arm64.qcow2"
MIRRORS=(
  "https://mirrors.ustc.edu.cn/debian-cdimage/cloud/trixie/latest"
  "https://mirrors.tuna.tsinghua.edu.cn/debian-cdimage/cloud/trixie/latest"
  "https://cloud.debian.org/images/cloud/trixie/latest"
)
log() { printf '[%s] %s\n' "${0##*/}" "$*"; }
die() { printf '[%s] 错误: %s\n' "${0##*/}" "$*" >&2; exit 1; }

mkdir -p "$OUT"; cd "$OUT"

# SHA512SUMS：任一镜像取到即可（也是可用性探针）
SUMS=""
for m in "${MIRRORS[@]}"; do
  log "探针 $m"
  if curl -fsSL --retry 2 --max-time 60 -o SHA512SUMS.part "$m/SHA512SUMS"; then
    mv SHA512SUMS.part SHA512SUMS; SUMS="$m"; break
  fi
done
[[ -s SHA512SUMS ]] || die "SHA512SUMS 全部镜像拉取失败"
want="$(grep " $F\$" SHA512SUMS | awk '{print $1}')"
[[ -n "$want" ]] || die "SHA512SUMS 里没有 $F（上游结构变了？）"

# 已有且校验通过 → 秒回
if [[ -f "$F" ]] && [[ "$(sha512sum "$F" | awk '{print $1}')" == "$want" ]]; then
  log "已有校验通过的 $F"
  exit 0
fi

got=""
for m in "${MIRRORS[@]}"; do
  log "下载 $m/$F"
  rm -f "$F.part"
  if curl -fL --retry 2 --max-time 1800 -C - -o "$F.part" "$m/$F"; then
    mv "$F.part" "$F"; got="$m"; break
  fi
done
[[ -n "$got" ]] || die "底包下载失败（全部镜像）"
actual="$(sha512sum "$F" | awk '{print $1}')"
[[ "$actual" == "$want" ]] || die "SHA512 不匹配: $actual"

{
  echo "base=$F"
  echo "mirror=$got"
  echo "sha512=$actual"
} > debian-base-info.txt
log "OK: $F ($(du -h "$F" | cut -f1)) ← $got"
