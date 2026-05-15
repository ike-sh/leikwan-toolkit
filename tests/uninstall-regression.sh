#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=/dev/null
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

menu_out="$(print_uninstall_menu)"
grep -q "普通卸载：移除服务和规则，保留配置 / 快照 / 备份" <<<"$menu_out"
grep -q "深度卸载：移除服务、规则、配置、日志、状�? <<<"$menu_out"
grep -q "0. 返回" <<<"$menu_out"

normal_out="$(bash leikwan-toolkit.sh --dry-run uninstall normal --yes 2>&1)"
grep -q "\[DRY-RUN\]" <<<"$normal_out"
[[ ! -e "$LEIKWAN_STATE_DIR" ]] || { echo "FAIL: dry-run normal uninstall created state dir" >&2; exit 1; }

deep_out="$(bash leikwan-toolkit.sh --dry-run uninstall deep --yes 2>&1)"
grep -q "final snapshot" <<<"$deep_out"
grep -q "\[DRY-RUN\]" <<<"$deep_out"
[[ ! -e "$LEIKWAN_STATE_DIR" ]] || { echo "FAIL: dry-run deep uninstall created state dir" >&2; exit 1; }

status_out="$(bash leikwan-toolkit.sh status 2>&1)"
grep -q "未检测到 Leikwan 配置目录" <<<"$status_out"
grep -q "建议执行：lq init" <<<"$status_out"
[[ ! -e "$LEIKWAN_STATE_DIR" ]] || { echo "FAIL: status after uninstall-like state created config dir" >&2; exit 1; }
if grep -q "错误：脚本在�? <<<"$status_out"; then
  echo "FAIL: status after uninstall-like state triggered global trap" >&2
  exit 1
fi

echo "[OK] uninstall regression passed"
