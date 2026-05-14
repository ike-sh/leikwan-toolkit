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

mkdir -p "$ENTRIES_DIR" "$FORWARDS_DIR" "$PBR_DIR" "$ENTRY_DIR" "$STATUS_DIR"
cat >"$ENTRIES_TSV" <<'EOF'
# entry_name	public_host	et_ip	easytier_protocol	easytier_port	weight	enabled
public3	home.example.test	10.198.1.4	tcp,udp	8303	100	true
EOF
cat >"$FORWARDS_TSV" <<'EOF'
# name	entry_port	target_host	target_port	out_iface	route_table	enabled	comment
tw	10004	tw.example.test	52936	eth1	T_CN2	true	tw-target
EOF
cat >"$PBR_DOMAIN_TSV" <<'EOF'
# name	host	route_table	enabled	comment
tw	tw.example.test	T_CN2	true	tw-ddns-pbr
EOF
cat >"$DDNS_STATUS_FILE" <<'EOF'
LAST_DDNS_TIME=2026-05-11 12:00:00
LAST_DDNS_RESULT=ok
LAST_DDNS_SCOPE=all
LAST_DDNS_PUBLIC_IP=203.0.113.9
LAST_DDNS_PUBLIC_IP_SOURCE=https://api.ipify.org
LAST_DDNS_FORWARD_CHANGED=
LAST_DDNS_FORWARD_FAILED=
LAST_DDNS_FORWARD_CHECKED=1
LAST_DDNS_FORWARD_FAILED_COUNT=0
LAST_DDNS_ENTRY_CHANGED=public3
LAST_DDNS_ENTRY_FAILED=
LAST_DDNS_ENTRY_CHECKED=1
LAST_DDNS_ENTRY_FAILED_COUNT=0
LAST_DDNS_PBR_CHANGED=
LAST_DDNS_PBR_FAILED=
LAST_DDNS_PBR_CHECKED=1
LAST_DDNS_PBR_FAILED_COUNT=0
LAST_DDNS_RELAY_RESTART_NEEDED=true
LAST_DDNS_NFT_APPLIED=false
LAST_DDNS_PBR_APPLIED=false
LAST_DDNS_RELAY_RESTARTED=false
LAST_DDNS_VERSION=1.4.1
EOF
entry_ddns_write_config true home.example.test custom-url "" "" "" "" 5min last
cat >"$ENTRY_DDNS_STATUS_FILE" <<'EOF'
LAST_ENTRY_DDNS_TIME=2026-05-11 12:00:00
LAST_ENTRY_DDNS_RESULT=ok
LAST_ENTRY_DDNS_HOST=home.example.test
LAST_ENTRY_DDNS_PUBLIC_IP=198.51.100.10
LAST_ENTRY_DDNS_RESOLVED_IP=198.51.100.10
LAST_ENTRY_DDNS_CHANGED=false
LAST_ENTRY_DDNS_VERSION=1.4.1
EOF

overview="$(ddns_overview)"
grep -q "DDNS / IP 变化检测状态" <<<"$overview"
grep -q "本机公网 IP" <<<"$overview"
grep -q "后端域名: checked 1, changed 0, failed 0" <<<"$overview"
grep -q "公网入口域名: checked 1, changed 1, failed 0" <<<"$overview"
grep -q "PBR 域名: checked 1, changed 0, failed 0" <<<"$overview"
grep -q "relay restart needed: yes" <<<"$overview"

status_out="$(ddns_status)"
grep -q "DDNS / IP 变化检测状态" <<<"$status_out"
grep -q "本机公网 IP" <<<"$status_out"
grep -q "后端域名" <<<"$status_out"
grep -q "公网入口域名" <<<"$status_out"
grep -q "PBR 域名" <<<"$status_out"
grep -q "relay restart needed" <<<"$status_out"

json_out="$(bash leikwan-toolkit.sh status --json)"
grep -q '"relay_restart_needed": "yes"' <<<"$json_out"

echo "[OK] ddns overview regression passed"
