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
dnsutils_auto_install() { return 0; }

cat >"$DDNS_STATUS_FILE" <<'EOF'
LAST_DDNS_TIME=2026-05-15 12:00:00
LAST_DDNS_RESULT=ok
LAST_DDNS_PUBLIC_IP=203.0.113.9
LAST_DDNS_PUBLIC_IP_SOURCE=https://4.ipw.cn
LAST_DDNS_RELAY_RESTART_NEEDED=false
LAST_DDNS_NFT_APPLIED=false
LAST_DDNS_PBR_APPLIED=false
LAST_DDNS_RELAY_RESTARTED=false
EOF

ddns_timer_state() { printf 'active'; }
ddns_timer_next_run() { printf 'Fri 2026-05-15 12:05:00 CST'; }
out="$(ddns_status)"
grep -q "timer: enabled" <<<"$out"
grep -q "下次检�? Fri 2026-05-15 12:05:00 CST" <<<"$out"

ddns_timer_state() { printf 'disabled'; }
out_disabled="$(ddns_status)"
grep -q "timer: disabled" <<<"$out_disabled"
grep -q "下次检�? 未启�? <<<"$out_disabled"

echo "[OK] ddns status timer regression passed"
