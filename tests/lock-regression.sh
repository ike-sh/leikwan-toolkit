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
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

printf '%s\n' 999999 >"${LEIKWAN_LOCK_PATH}.pid"
touch "$LEIKWAN_LOCK_PATH"
stale_out="$(global_lock_acquire 2>&1)"
grep -q "stale lock" <<<"$stale_out"
global_lock_release

holder_log="${TMP_DIR}/holder.log"
(
  export LEIKWAN_STATE_DIR LEIKWAN_BACKUP_DIR LEIKWAN_RUN_DIR LEIKWAN_LOG_DISABLED
  # shellcheck source=/dev/null
  source "$ROOT_DIR/leikwan-toolkit.sh"
  lock_token=""
  lock_acquire "$LEIKWAN_LOCK_PATH" "测试任务" lock_token
  sleep 4
  lock_release "$lock_token"
) >"$holder_log" 2>&1 &
holder_pid=$!
sleep 1

err_trap="$(trap -p ERR || true)"
trap - ERR
set +e
busy_out="$(global_lock_acquire 2>&1)"
busy_rc=$?
set -e
[[ -n "$err_trap" ]] && eval "$err_trap"
kill "$holder_pid" 2>/dev/null || true
wait "$holder_pid" 2>/dev/null || true

if (( busy_rc == 0 )); then
  global_lock_release
  echo "FAIL: global lock acquired while holder was active" >&2
  cat "$holder_log" >&2
  exit 1
fi
grep -q "已有 Leikwan 任务运行�? <<<"$busy_out" || {
  echo "FAIL: busy lock did not produce friendly warning" >&2
  echo "$busy_out" >&2
  cat "$holder_log" >&2
  exit 1
}

echo "[OK] lock regression passed"
