#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/tests/test-lib.sh"

mkdir -p "$ROOT_DIR/.tmp"
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
mkdir -p "$STATUS_DIR"

restart_marker="${TMP_DIR}/restart-calls"
: >"$restart_marker"

ddns_config_value() {
  case "$1" in
    DDNS_AUTO_RESTART_RELAY|DDNS_ENTRY_AUTO_RESTART_RELAY) printf 'true' ;;
    DDNS_RESTART_RELAY_COOLDOWN) printf '300' ;;
    *) printf '%s' "${2:-}" ;;
  esac
}

ddns_auto_snapshot() { echo "[MOCK] snapshot"; return 0; }
apply_easytier_relay_service() {
  printf 'restart\n' >>"$restart_marker"
  echo "[MOCK] relay restart"
  return 0
}

cat >"$DDNS_STATUS_FILE" <<'EOF'
LAST_DDNS_RELAY_RESTARTED_AT=1000
EOF

DDNS_RELAY_RESTART_NEEDED=true
DDNS_RELAY_RESTARTED=false
DDNS_RELAY_RESTART_SKIPPED_COOLDOWN=false
DDNS_ENTRY_CHANGED=public3
LQ_TEST_NOW_EPOCH=1100
ddns_maybe_restart_relay 1 >"${TMP_DIR}/cooldown.out" 2>&1
out_cooldown="$(cat "${TMP_DIR}/cooldown.out")"
grep -q "非交互模式，DDNS_AUTO_RESTART_RELAY=true，正在自动重�?relay" <<<"$out_cooldown"
grep -q "relay 最近已自动重启，处�?cooldown，跳过本次自动重�? <<<"$out_cooldown"
[[ "$(wc -l <"$restart_marker")" -eq 0 ]]
[[ "$DDNS_RELAY_RESTART_NEEDED" == "true" ]]
[[ "$DDNS_RELAY_RESTART_SKIPPED_COOLDOWN" == "true" ]]

DDNS_RELAY_RESTART_NEEDED=true
DDNS_RELAY_RESTARTED=false
DDNS_RELAY_RESTART_SKIPPED_COOLDOWN=false
LQ_TEST_NOW_EPOCH=1401
ddns_maybe_restart_relay 1 >"${TMP_DIR}/restart.out" 2>&1
out_restart="$(cat "${TMP_DIR}/restart.out")"
grep -q "\[MOCK\] relay restart" <<<"$out_restart"
grep -q "已自动重�?relay" <<<"$out_restart"
[[ "$(wc -l <"$restart_marker")" -eq 1 ]]
[[ "$DDNS_RELAY_RESTART_NEEDED" == "false" ]]
[[ "$DDNS_RELAY_RESTARTED" == "true" ]]
[[ "$DDNS_RELAY_RESTARTED_AT" == "1401" ]]

echo "[OK] DDNS relay restart cooldown regression passed"
