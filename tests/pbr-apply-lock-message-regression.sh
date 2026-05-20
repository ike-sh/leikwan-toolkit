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

need_root_unless_dry_run() { :; }

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

set +e
pbr_out="$(pbr_apply 2>&1)"
pbr_rc=$?
set -e
kill "$holder_pid" 2>/dev/null || true
wait "$holder_pid" 2>/dev/null || true

(( pbr_rc != 0 ))
grep -q "已有 Leikwan 任务运行中，当前操作已跳过" <<<"$pbr_out"
grep -q "锁文件：" <<<"$pbr_out"
grep -q "持有进程：PID=" <<<"$pbr_out"
grep -q "命令：" <<<"$pbr_out"
grep -q "已运行：" <<<"$pbr_out"
grep -q "lq task status" <<<"$pbr_out"
if grep -q "错误：脚本在第" <<<"$pbr_out"; then
  echo "FAIL: lock conflict should not print on_error stack line" >&2
  echo "$pbr_out" >&2
  exit 1
fi
if grep -q "已有 Leikwan 任务运行中，请稍后再试" <<<"$pbr_out"; then
  echo "FAIL: old lock conflict message is still used" >&2
  echo "$pbr_out" >&2
  exit 1
fi

printf '%s\n' 999999 >"${LEIKWAN_LOCK_PATH}.pid"
touch "$LEIKWAN_LOCK_PATH"
pbr_init_rt_tables() { :; }
pbr_refresh_dynamic_rules() { :; }
stale_pbr_out="$(pbr_apply 2>&1)"
grep -q "检测到遗留任务锁，已自动清理" <<<"$stale_pbr_out"
grep -q "暂无 PBR 静态规则" <<<"$stale_pbr_out"

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

ddns_out="$(ddns_refresh_once --global --non-interactive 2>&1)"
kill "$holder_pid" 2>/dev/null || true
wait "$holder_pid" 2>/dev/null || true
grep -q "DDNS 本轮跳过：已有任务运行" <<<"$ddns_out"
grep -q "持有任务：PID=" <<<"$ddns_out"
grep -q "下个 timer 周期会自动重试" <<<"$ddns_out"

echo "[OK] PBR apply lock message regression passed"
