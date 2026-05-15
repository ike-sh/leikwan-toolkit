#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=tests/test-lib.sh
source "$ROOT_DIR/tests/test-lib.sh"

TMP_DIR="$(test_mktemp_dir "$ROOT_DIR")"
trap 'rm -rf "$TMP_DIR"' EXIT

export LEIKWAN_STATE_DIR="${TMP_DIR}/state"
export LEIKWAN_BACKUP_DIR="${TMP_DIR}/backups"
export LEIKWAN_RUN_DIR="${TMP_DIR}/run"
export LEIKWAN_LOG_DISABLED=1
export LEIKWAN_NO_CLEAR=1
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

advanced_out="$(print_advanced_menu_options)"
grep -q "7. 系统网络优化" <<<"$advanced_out"
grep -q "8. 卸载" <<<"$advanced_out"

system_out="$(print_system_network_menu_options)"
grep -q "查看系统网络优化状态" <<<"$system_out"
grep -q "IPv4 优先：开启 / 关闭" <<<"$system_out"
grep -q "DNS 服务器：设置 / 恢复" <<<"$system_out"
grep -q "IPv6：禁用 / 恢复" <<<"$system_out"
grep -q "BBR / fq：开启 / 恢复" <<<"$system_out"
grep -q "IPv6 入站收口 nftables" <<<"$system_out"

echo "[OK] system network menu regression passed"
