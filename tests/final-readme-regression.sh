#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

grep -q "1.4.5" README.md
grep -q "LTS" README.md
grep -q "lq init" README.md
grep -q "DDNS" README.md
grep -q "域名解析变化自动刷新" README.md
grep -q "默认不修改 DNS 服务商记录" README.md
grep -q "本机公网 IP 检测只作为辅助状态" README.md
grep -q "多 DNS 解析器" README.md
grep -q "dnsutils" README.md
grep -q "DDNS_RESTART_RELAY_COOLDOWN" README.md
grep -q "build-release.sh" README.md
grep -q "DNS_RESOLVE_SERVERS" README.md
grep -q "DNS_RESOLVE_STRATEGY" README.md
grep -q "DNS 分歧" README.md
grep -q "自动刷新本地转发" README.md
grep -q "PBR" README.md

echo "[OK] final README regression passed"
