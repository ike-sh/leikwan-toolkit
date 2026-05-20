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

menu="$(print_pbr_menu_options)"
grep -q "1. 添加静态 PBR" <<<"$menu"
grep -q "2. 从现有转发目标添加 PBR" <<<"$menu"
grep -q "3. 修改 PBR 规则" <<<"$menu"
grep -q "4. 删除 PBR 规则" <<<"$menu"
grep -q "5. 应用 PBR" <<<"$menu"
grep -q "6. 查看 PBR" <<<"$menu"
grep -q "7. 域名 PBR 管理" <<<"$menu"

echo "[OK] PBR edit menu regression passed"
