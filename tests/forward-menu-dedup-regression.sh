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
trap - ERR

b_menu="$(print_relay_host_menu_options)"
grep -q "重新应用转发规则" <<<"$b_menu"

forward_menu="$(print_forwards_menu_options)"
for text in \
  "添加转发目标" \
  "修改转发目标" \
  "删除转发目标" \
  "查看转发目标" \
  "启用 / 禁用转发目标" \
  "解析 target_host" \
  "测试单个转发目标" \
  "导入 forwards.tsv（高级）" \
  "导出 forwards.tsv" \
  "生成转发入口输出"; do
  grep -q "$text" <<<"$forward_menu"
done

if grep -q "重新应用利群转发规则" <<<"$forward_menu"; then
  echo "FAIL: forwards menu still contains duplicate apply-relay entry" >&2
  echo "$forward_menu" >&2
  exit 1
fi
if grep -q "DDNS 自动刷新（已移动到主菜单）" <<<"$forward_menu"; then
  echo "FAIL: forwards menu still contains old numbered DDNS entry" >&2
  echo "$forward_menu" >&2
  exit 1
fi
if grep -Eq '^[0-9]+\. .*DDNS 自动刷新' <<<"$forward_menu"; then
  echo "FAIL: forwards menu still exposes DDNS as a numbered item" >&2
  echo "$forward_menu" >&2
  exit 1
fi
grep -q "DDNS / 域名解析变化检测已移动到主菜单“DDNS”" <<<"$forward_menu"

call_file="${TMP_DIR}/forward-call"
apply_nft_rules() { printf '%s %s\n' "$1" "${2:-0}" >"$call_file"; }
main forward apply-relay
grep -qx "leikwan-relay 0" "$call_file"
main forward apply-relay --auto-fix-route
grep -qx "leikwan-relay 1" "$call_file"

truncated_report="${TMP_DIR}/leikwan-menu-truncated.txt"
if grep -R -n -E "简洁状([^态]|$)|整体状([^态]|$)|请择" leikwan-toolkit.sh README.md docs >"$truncated_report" 2>/dev/null; then
  echo "FAIL: truncated menu text found" >&2
  cat "$truncated_report" >&2
  exit 1
fi

echo "[OK] forward menu dedup regression passed"
