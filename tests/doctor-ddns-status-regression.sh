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
mkdir -p "$STATUS_DIR"

ddns_timer_state() { printf 'disabled'; }
ddns_config_value() { printf '%s' "${2:-}"; }

cat >"$DDNS_STATUS_FILE" <<'EOF'
LAST_DDNS_TIME=2026-05-15 12:00:00
LAST_DDNS_RESULT=ok
LAST_DDNS_PUBLIC_IP=203.0.113.9
LAST_DDNS_PUBLIC_IP_SOURCE=https://4.ipw.cn
LAST_DDNS_RELAY_RESTART_NEEDED=false
LAST_DDNS_DNS_SPLIT_DETECTED=false
EOF

out="$(report_ddns_global_state 2>&1)"
grep -q "辅助公网 IP 检测最近成功：203.0.113.9 (https://4.ipw.cn)" <<<"$out"
if grep -q "最近没有可用结果" <<<"$out"; then
  echo "FAIL: doctor reported missing public IP despite successful DDNS status" >&2
  echo "$out" >&2
  exit 1
fi

cat >"$DDNS_STATUS_FILE" <<'EOF'
LAST_DDNS_TIME=2026-05-15 12:00:00
LAST_DDNS_RESULT=fail
LAST_DDNS_PUBLIC_IP=
LAST_DDNS_PUBLIC_IP_SOURCE=
EOF
fail_out="$(report_ddns_global_state 2>&1)"
grep -q "辅助公网 IP 检测失败" <<<"$fail_out"

echo "[OK] doctor DDNS status regression passed"
