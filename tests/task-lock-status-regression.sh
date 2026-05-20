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

no_lock_out="$(task_status 2>&1)"
grep -q "当前没有 Leikwan 任务运行" <<<"$no_lock_out"
cli_no_lock_out="$(
  LEIKWAN_STATE_DIR="$LEIKWAN_STATE_DIR" \
  LEIKWAN_BACKUP_DIR="$LEIKWAN_BACKUP_DIR" \
  LEIKWAN_RUN_DIR="$LEIKWAN_RUN_DIR" \
  LEIKWAN_LOG_DISABLED=1 \
  LEIKWAN_NO_CLEAR=1 \
  bash "$ROOT_DIR/leikwan-toolkit.sh" task status 2>&1
)"
grep -q "当前没有 Leikwan 任务运行" <<<"$cli_no_lock_out"

holder_log="${TMP_DIR}/holder.log"
(
  trap 'rm -f "${LEIKWAN_LOCK_PATH}.pid" "${LEIKWAN_LOCK_PATH}.meta"' EXIT
  exec 9>"$LEIKWAN_LOCK_PATH"
  flock -n 9
  printf '%s\n' "$BASHPID" >"${LEIKWAN_LOCK_PATH}.pid"
  sleep 8
) >"$holder_log" 2>&1 &
holder_pid=$!

for _ in {1..30}; do
  [[ -f "${LEIKWAN_LOCK_PATH}.pid" ]] && break
  sleep 0.1
done

status_out="$(task_status 2>&1)"
kill "$holder_pid" 2>/dev/null || true
wait "$holder_pid" 2>/dev/null || true

grep -q "锁文件：${LEIKWAN_LOCK_PATH}" <<<"$status_out"
grep -q "持有进程：PID=" <<<"$status_out"
grep -q "命令：" <<<"$status_out"
grep -q "已运行：" <<<"$status_out"
grep -q "可查看日志：" <<<"$status_out"

echo "[OK] task lock status regression passed"
