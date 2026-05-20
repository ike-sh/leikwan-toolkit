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

dnsutils_auto_install() { :; }
dig() {
  local server="${4#@}"
  case "$server" in
    1.1.1.1) printf '%s\n' "1.1.1.1" ;;
    8.8.8.8) printf '%s\n' "8.8.8.8" ;;
    223.5.5.5|119.29.29.29) printf '%s\n' "36.234.134.253" ;;
    *) return 1 ;;
  esac
}
getent() {
  case "$1" in
    ahostsv4|ahosts) printf '%s STREAM tw.ike-nicholas.xyz\n' "36.234.134.253" ;;
    *) return 1 ;;
  esac
}
ddns_timer_state() { printf '%s' "inactive"; }

ensure_tsv_files >/dev/null
mkdir -p "$PBR_DIR" "$STATUS_DIR"
cat >"$FORWARDS_TSV" <<'EOF'
# name	entry_port	target_host	target_port	out_iface	route_table	enabled	comment
tw	10004	tw.ike-nicholas.xyz	52936	eth0	T_CN2	true	Taiwan
EOF
cat >"$PBR_STATIC_CONF" <<'EOF'
36.234.134.253/32 CN2 forward tw tw.ike-nicholas.xyz
EOF
cat >"$DDNS_STATUS_FILE" <<'EOF'
LAST_DDNS_TIME=2026-05-20 12:00:00
LAST_DDNS_RESULT=ok
LAST_DDNS_PUBLIC_IP=203.0.113.8
LAST_DDNS_PUBLIC_IP_SOURCE=https://api.ipify.org
LAST_DDNS_DNS_SPLIT_DETECTED=true
LAST_DDNS_DNS_SPLIT_DOMAIN=tw.ike-nicholas.xyz
LAST_DDNS_DNS_SELECTED_IP=1.1.1.1
LAST_DDNS_RELAY_RESTART_NEEDED=false
EOF

out="$(report_ddns_global_state 2>&1)"
grep -q "检测到 DNS 传播不一致：tw.ike-nicholas.xyz" <<<"$out"
grep -q "转发/PBR 场景当前采用多数结果：36.234.134.253" <<<"$out"
bad_current="当前采用 "
bad_current="${bad_current}1.1.1.1"
if grep -q "$bad_current" <<<"$out"; then
  echo "FAIL: doctor still says forward/PBR currently uses first-success IP" >&2
  echo "$out" >&2
  exit 1
fi

echo "[OK] doctor forward/PBR DNS split regression passed"
