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

main_out="$(print_main_menu_options)"
grep -q "Leikwan Toolkit 1.4.17 LTS" <<<"$main_out"
grep -q "1." <<<"$main_out"
grep -q "2." <<<"$main_out"
grep -q "3." <<<"$main_out"
grep -q "4. DDNS" <<<"$main_out"
grep -q "5." <<<"$main_out"
grep -q "6." <<<"$main_out"
grep -q "0." <<<"$main_out"
if grep -Eq '7\.|8\.|9\.' <<<"$main_out"; then
  echo "FAIL: main menu should only expose six core entries" >&2
  echo "$main_out" >&2
  exit 1
fi

ddns_out="$(print_ddns_menu_options)"
grep -q "DDNS" <<<"$ddns_out"
grep -q "1." <<<"$ddns_out"
grep -q "2." <<<"$ddns_out"
grep -q "3." <<<"$ddns_out"
grep -q "4." <<<"$ddns_out"
grep -q "5." <<<"$ddns_out"
grep -q "0." <<<"$ddns_out"

advanced_out="$(print_advanced_menu_options)"
grep -q "EasyTier" <<<"$advanced_out"
grep -q "1." <<<"$advanced_out"
grep -q "2." <<<"$advanced_out"
grep -q "3." <<<"$advanced_out"
grep -q "4." <<<"$advanced_out"
grep -q "5." <<<"$advanced_out"
grep -q "6." <<<"$advanced_out"
grep -q "7." <<<"$advanced_out"
grep -q "系统网络优化" <<<"$advanced_out"
grep -q "8." <<<"$advanced_out"
grep -q "0." <<<"$advanced_out"

relay_out="$(print_relay_host_menu_options)"
grep -q "4. 重新应用转发规则" <<<"$relay_out"

forwards_out="$(print_forwards_menu_options)"
grep -q "6. 解析 target_host" <<<"$forwards_out"
grep -q "10. 生成转发入口输出" <<<"$forwards_out"
if grep -q "重新应用利群转发规则" <<<"$forwards_out" || grep -Eq '^[0-9]+\. .*DDNS 自动刷新' <<<"$forwards_out"; then
  echo "FAIL: forwards menu contains duplicate apply-relay or numbered DDNS entry" >&2
  echo "$forwards_out" >&2
  exit 1
fi

pbr_out="$(print_pbr_menu_options)"
grep -q "1. 添加静态 PBR" <<<"$pbr_out"
grep -q "2. 从现有转发目标添加 PBR" <<<"$pbr_out"
grep -q "3. 修改 PBR 规则" <<<"$pbr_out"
grep -q "4. 删除 PBR 规则" <<<"$pbr_out"
grep -q "5. 应用 PBR" <<<"$pbr_out"
grep -q "6. 查看 PBR" <<<"$pbr_out"
grep -q "7. 域名 PBR 管理" <<<"$pbr_out"

status_out="$(print_status_diagnostics_menu_options)"
grep -q "1." <<<"$status_out"
grep -q "4." <<<"$status_out"
grep -q "6." <<<"$status_out"

echo "[OK] final menu regression passed"
