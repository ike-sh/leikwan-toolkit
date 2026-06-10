#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tool_version="$(awk -F= '$1=="TOOL_VERSION" {gsub(/"/, "", $2); print $2; exit}' leikwan-toolkit.sh)"

grep -q "$tool_version" README.md
grep -q "Shell LTS" README.md
grep -q "lq init" README.md
grep -q "DDNS" README.md
grep -q "dnsutils" README.md
grep -q "DDNS_RESTART_RELAY_COOLDOWN" README.md
grep -q "build-release.sh" README.md
grep -q "leikwan-toolkit-${tool_version}.tar.gz" README.md || grep -q 'leikwan-toolkit-<VERSION>.tar.gz' README.md
grep -q "系统网络优化" README.md
grep -q "8.8.8.8" README.md
grep -q "1.1.1.1" README.md
grep -q "IPv6 入站收口 nftables" README.md
grep -q "VERSION" README.md
grep -q "DNS_RESOLVE_SERVERS" README.md
grep -q "DNS_RESOLVE_STRATEGY" README.md
grep -q "PBR" README.md
grep -q "LEIKWAN_GITHUB_DOWNLOAD_MODE=mirror-first" README.md
grep -q "LEIKWAN_GITHUB_DOWNLOAD_MODE=origin-first" README.md
grep -q "LEIKWAN_GITHUB_MIRRORS=\"https://gh-proxy.com/" README.md
grep -q "https://gh-proxy.com/https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh" README.md
grep -q "fallback 官方 GitHub" README.md
grep -q "panel/" README.md
grep -q "edge-tunnel-panel" README.md

echo "[OK] final README regression passed"
