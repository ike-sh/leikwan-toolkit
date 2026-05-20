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

CALLS_FILE="${TMP_DIR}/calls"
record_call() {
  printf '%s\n' "$1" >"$CALLS_FILE"
}

update_run() { record_call "update_run:${1:-}"; }
update_check() { record_call "update_check"; }
update_status() { record_call "update_status"; }
update_rollback() { record_call "update_rollback"; }

main update
grep -qx "update_run:" "$CALLS_FILE"

main update run
grep -qx "update_run:" "$CALLS_FILE"

main update check
grep -qx "update_check" "$CALLS_FILE"

main update status
grep -qx "update_status" "$CALLS_FILE"

main update rollback
grep -qx "update_rollback" "$CALLS_FILE"

help_out="$(print_help)"
grep -q "sudo bash leikwan-toolkit.sh update" <<<"$help_out"
grep -q "等价于 update run" <<<"$help_out"
grep -q "lq update" docs/cli.md
grep -q "等价于.*update run" docs/cli.md

echo "[OK] update command alias regression passed"
