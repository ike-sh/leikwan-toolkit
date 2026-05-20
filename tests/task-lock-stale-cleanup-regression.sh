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

printf '%s\n' 999999 >"${LEIKWAN_LOCK_PATH}.pid"
touch "$LEIKWAN_LOCK_PATH"
stale_file="${TMP_DIR}/stale.out"
global_lock_acquire >"$stale_file" 2>&1
stale_out="$(cat "$stale_file")"
grep -q "检测到遗留任务锁，已自动清理" <<<"$stale_out"
[[ -n "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]
global_lock_release

printf '%s\n' 999999 >"${LEIKWAN_LOCK_PATH}.pid"
touch "$LEIKWAN_LOCK_PATH"
unlock_out="$(task_unlock_stale 2>&1)"
grep -q "已清理遗留任务锁" <<<"$unlock_out"
[[ ! -e "$LEIKWAN_LOCK_PATH" ]]
[[ ! -e "${LEIKWAN_LOCK_PATH}.pid" ]]

printf '%s\n' 999999 >"${LEIKWAN_LOCK_PATH}.pid"
touch "$LEIKWAN_LOCK_PATH"
cli_unlock_out="$(
  LEIKWAN_STATE_DIR="$LEIKWAN_STATE_DIR" \
  LEIKWAN_BACKUP_DIR="$LEIKWAN_BACKUP_DIR" \
  LEIKWAN_RUN_DIR="$LEIKWAN_RUN_DIR" \
  LEIKWAN_LOG_DISABLED=1 \
  LEIKWAN_NO_CLEAR=1 \
  bash "$ROOT_DIR/leikwan-toolkit.sh" task unlock-stale 2>&1
)"
grep -q "已清理遗留任务锁" <<<"$cli_unlock_out"
[[ ! -e "$LEIKWAN_LOCK_PATH" ]]
[[ ! -e "${LEIKWAN_LOCK_PATH}.pid" ]]

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

live_out="$(task_unlock_stale 2>&1)"
kill "$holder_pid" 2>/dev/null || true
wait "$holder_pid" 2>/dev/null || true

grep -q "锁仍由活进程持有，未删除" <<<"$live_out"

echo "[OK] task lock stale cleanup regression passed"
