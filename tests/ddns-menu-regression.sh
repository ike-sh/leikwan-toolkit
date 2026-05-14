#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/.tmp"
TMP_DIR="$(TMPDIR="$ROOT_DIR/.tmp" mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export LEIKWAN_STATE_DIR="${TMP_DIR}/state"
export LEIKWAN_BACKUP_DIR="${TMP_DIR}/backups"
export LEIKWAN_RUN_DIR="${TMP_DIR}/run"
export LEIKWAN_LOG_DISABLED=1
export LEIKWAN_NO_CLEAR=1
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

main_out="$(print_main_menu_options)"
grep -q "4. DDNS" <<<"$main_out"
grep -q "6. 高级维护" <<<"$main_out"
grep -q "0. 退出" <<<"$main_out"

ddns_out="$(print_ddns_menu_options)"
grep -q "1. 开启 / 关闭全局 IP 变化检测" <<<"$ddns_out"
grep -q "2. 立即检测并刷新" <<<"$ddns_out"
grep -q "3. 查看 DDNS / IP 变化状态" <<<"$ddns_out"
grep -q "4. 查看 DDNS 日志" <<<"$ddns_out"
grep -q "5. 高级设置" <<<"$ddns_out"
grep -q "0. 返回" <<<"$ddns_out"
forbidden_regex="$(printf '%s|%s|%s|%s' "A 端""更新" "B 端""监控" "配置 A 端"" DDNS" "应用公网入口 DDNS ""变化")"
if grep -Eq "$forbidden_regex" <<<"$ddns_out"; then
  echo "FAIL: old DDNS menu wording leaked" >&2
  echo "$ddns_out" >&2
  exit 1
fi

echo "[OK] ddns menu regression passed"
