#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=tests/test-lib.sh
source "$ROOT_DIR/tests/test-lib.sh"

TMP_DIR="$(test_mktemp_dir "$ROOT_DIR")"
trap 'rm -rf "$TMP_DIR"' EXIT
export TMPDIR="$TMP_DIR"
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
auto_snapshot_or_confirm() { :; }

mkdir -p "$PBR_DIR"
cat >"$PBR_STATIC_CONF" <<'EOF'
203.0.113.10/32 CN2 static
EOF

cli_out="$(printf '\nT_CN2\neth2\ncli-note\nY\ny\n' | main pbr edit 1 2>&1)"
grep -q "PBR 规则已修改" <<<"$cli_out"
grep -q '^203.0.113.10/32 CN2 static iface=eth2 enabled=true remark=cli-note$' "$PBR_STATIC_CONF"

cat >"$PBR_STATIC_CONF" <<'EOF'
203.0.113.10/32 CN2 static
EOF
cidr_out="$(printf '\nT_9929\neth9\ncidr-note\nY\ny\n' | main pbr edit 203.0.113.10/32 2>&1)"
grep -q "PBR 规则已修改" <<<"$cidr_out"
grep -q '^203.0.113.10/32 9929 static iface=eth9 enabled=true remark=cidr-note$' "$PBR_STATIC_CONF"

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
lock_out="$(printf '\nT_9929\neth9\nlocked-note\nY\ny\n' | main pbr edit 1 2>&1)"
lock_rc=$?
set -e
kill "$holder_pid" 2>/dev/null || true
wait "$holder_pid" 2>/dev/null || true
(( lock_rc != 0 ))
grep -q "已有 Leikwan 任务运行中，当前操作已跳过" <<<"$lock_out"
grep -q "锁文件：" <<<"$lock_out"
if grep -q "错误：脚本在第" <<<"$lock_out"; then
  echo "FAIL: PBR edit lock conflict should not print on_error stack line" >&2
  echo "$lock_out" >&2
  exit 1
fi

echo "[OK] PBR CLI edit regression passed"
