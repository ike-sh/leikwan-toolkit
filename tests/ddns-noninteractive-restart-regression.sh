#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/.tmp"
TMP_DIR="$(TMPDIR="$ROOT_DIR/.tmp" mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export LEIKWAN_STATE_DIR="${TMP_DIR}/state"
export LEIKWAN_BACKUP_DIR="${TMP_DIR}/backups"
export LEIKWAN_RUN_DIR="${TMP_DIR}/run"
export LEIKWAN_LOG_DISABLED=1
export LEIKWAN_NO_CLEAR=1
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

DRY_RUN=1
restart_calls=0
restart_marker="${TMP_DIR}/restart-calls"
: >"$restart_marker"

ddns_auto_snapshot() {
  echo "[MOCK] snapshot"
  return 0
}

apply_easytier_relay_service() {
  restart_calls=$((restart_calls + 1))
  printf 'restart\n' >>"$restart_marker"
  echo "[MOCK] relay restart"
  return 0
}

ddns_config_value() {
  case "$1" in
    DDNS_AUTO_RESTART_RELAY|DDNS_ENTRY_AUTO_RESTART_RELAY) printf '%s' "${TEST_AUTO_RESTART:-false}" ;;
    *) printf '%s' "${2:-}" ;;
  esac
}

DDNS_RELAY_RESTART_NEEDED=true
DDNS_ENTRY_CHANGED=public3
TEST_AUTO_RESTART=true
out_true="$(ddns_maybe_restart_relay 1 2>&1)"
grep -q "DDNS_AUTO_RESTART_RELAY=true，正在自动重启 relay" <<<"$out_true"
grep -q "\[MOCK\] relay restart" <<<"$out_true"
if grep -q "是否现在重启 relay" <<<"$out_true"; then
  echo "FAIL: non-interactive auto restart prompted" >&2
  echo "$out_true" >&2
  exit 1
fi
[[ "$(wc -l <"$restart_marker")" -eq 1 ]]
grep -q "已自动重启 relay" <<<"$out_true"

restart_calls=0
: >"$restart_marker"
DDNS_RELAY_RESTARTED=false
DDNS_RELAY_RESTART_NEEDED=true
TEST_AUTO_RESTART=false
out_false="$(ddns_maybe_restart_relay 1 2>&1)"
grep -q "DDNS_AUTO_RESTART_RELAY=false，非交互模式只标记 relay restart needed" <<<"$out_false"
if grep -q "\[MOCK\] relay restart" <<<"$out_false"; then
  echo "FAIL: non-interactive false auto restart should not restart" >&2
  echo "$out_false" >&2
  exit 1
fi
[[ "$(wc -l <"$restart_marker")" -eq 0 ]]
[[ "$DDNS_RELAY_RESTART_NEEDED" == "true" ]]

service_out="$(render_ddns_service)"
grep -q "ddns run --global --non-interactive" <<<"$service_out"

echo "[OK] ddns noninteractive restart regression passed"
