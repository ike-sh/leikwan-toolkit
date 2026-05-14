#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

grep -q "1.4.1" README.md
grep -q "LTS" README.md
grep -q "lq init" README.md
grep -q "DDNS" README.md
grep -q "全局 IP 变化检测" README.md
grep -q "默认不修改 DNS 服务商记录" README.md
grep -q "内置公网 IP 检测 URL" README.md
grep -q "自动刷新本地转发" README.md
grep -q "PBR" README.md

echo "[OK] final README regression passed"
