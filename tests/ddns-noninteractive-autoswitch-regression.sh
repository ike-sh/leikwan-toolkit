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

mkdir -p "$ENTRIES_DIR" "$FORWARDS_DIR" "$PBR_DIR" "$STATUS_DIR"

cat >"$ENTRIES_TSV" <<'EOF'
# entry_name	public_host	et_ip	easytier_protocol	easytier_port	weight	enabled
public3	home.example.test	10.198.1.4	tcp,udp	8303	100	true
EOF
cat >"$RESOLVED_ENTRIES_TSV" <<'EOF'
# name	public_host	resolved_ip	last_checked	last_changed
public3	home.example.test	198.51.100.10	2026-05-15 12:00:00	2026-05-15 12:00:00
EOF
cat >"$FORWARDS_TSV" <<'EOF'
# name	entry_port	target_host	target_port	out_iface	route_table	enabled	comment
tw	10004	tw.example.test	52936	eth1	T_CN2	true	tw-target
EOF
cat >"$RESOLVED_TSV" <<'EOF'
# name	entry_port	target_host	resolved_ip	target_port	out_iface	route_table	enabled	last_resolved_at	comment
tw	10004	tw.example.test	203.0.113.10	52936	eth1	T_CN2	true	2026-05-15 12:00:00	tw-target
EOF
cat >"$PBR_DOMAIN_TSV" <<'EOF'
# name	host	route_table	enabled	comment
media	pbr.example.test	T_CN2	true	media-pbr
EOF
cat >"$PBR_RESOLVED_DOMAIN_TSV" <<'EOF'
# name	host	resolved_ip	route_table	last_checked	last_changed
media	pbr.example.test	192.0.2.10	T_CN2	2026-05-15 12:00:00	2026-05-15 12:00:00
EOF
cat >"$DDNS_CONFIG" <<'EOF'
DDNS_GLOBAL_ENABLED=true
DDNS_GLOBAL_INTERVAL=5min
DDNS_GLOBAL_DOMAINS=
PUBLIC_IP_CHECK_URLS=
DNS_RESOLVE_SERVERS=1.1.1.1,8.8.8.8,223.5.5.5,119.29.29.29
DNS_RESOLVE_STRATEGY=first-success
DNS_RESOLVE_WARN_ON_SPLIT=true
DDNS_AUTO_APPLY=true
DDNS_AUTO_SYNC_PBR=true
DDNS_AUTO_RESTART_RELAY=true
DDNS_RESTART_RELAY_COOLDOWN=300
DDNS_CHANGE_CONFIRM_COUNT=1
DDNS_KEEP_OLD_ON_FAIL=true
DDNS_UPDATE_DNS_RECORD=false
DDNS_REFRESH_INTERVAL=5min
DDNS_REFRESH_FORWARDS=true
DDNS_REFRESH_ENTRIES=true
DDNS_REFRESH_PBR=true
DDNS_AUTO_FIX_ROUTE=false
DDNS_AUTO_SYNC_FORWARD_PBR=true
DDNS_AUTO_SYNC_DOMAIN_PBR=true
DDNS_ENTRY_AUTO_RESTART_RELAY=true
EOF

restart_marker="${TMP_DIR}/restart-calls"
apply_marker="${TMP_DIR}/apply-calls"
pbr_marker="${TMP_DIR}/pbr-calls"
: >"$restart_marker"
: >"$apply_marker"
: >"$pbr_marker"

need_root_unless_dry_run() { return 0; }
dnsutils_auto_install() { return 0; }
detect_public_ipv4() { DDNS_PUBLIC_IP="203.0.113.9"; DDNS_PUBLIC_IP_SOURCE="mock"; printf '%s' "$DDNS_PUBLIC_IP"; }
lock_acquire() { printf -v "$3" "mock-lock"; return 0; }
lock_release() { return 0; }
global_lock_acquire() { LEIKWAN_GLOBAL_LOCK_TOKEN="mock"; return 0; }
global_lock_release() { LEIKWAN_GLOBAL_LOCK_TOKEN=""; return 0; }
ddns_auto_snapshot() { echo "[MOCK] snapshot"; return 0; }
apply_nft_rules() { printf 'apply\n' >>"$apply_marker"; echo "[MOCK] nft apply"; return 0; }
pbr_sync_from_forwards() { echo "[MOCK] pbr sync from forwards"; return 0; }
pbr_apply() { printf 'pbr\n' >>"$pbr_marker"; echo "[MOCK] pbr apply"; return 0; }
apply_easytier_relay_service() { printf 'restart\n' >>"$restart_marker"; echo "[MOCK] relay restart"; return 0; }

TEST_HOME_IP="198.51.100.20"
resolve_domain_ipv4_multi() {
  case "$1" in
    home.example.test) RESOLVE_SELECTED_IP="$TEST_HOME_IP" ;;
    tw.example.test) RESOLVE_SELECTED_IP="203.0.113.20" ;;
    pbr.example.test) RESOLVE_SELECTED_IP="192.0.2.20" ;;
    *) return 1 ;;
  esac
  RESOLVE_SELECTED_SOURCE="mock"
  RESOLVE_ALL_RESULTS="mock -> ${RESOLVE_SELECTED_IP}"
  RESOLVE_SPLIT_DETECTED=false
  return 0
}

ddns_refresh_once --global --non-interactive >"${TMP_DIR}/true.out" 2>&1
out_true="$(cat "${TMP_DIR}/true.out")"
if grep -Eq "是否现在重启 relay|\\[y/N\\]|\\[Y/n\\]" <<<"$out_true"; then
  echo "FAIL: non-interactive ddns run prompted" >&2
  echo "$out_true" >&2
  exit 1
fi
grep -q "非交互模式，DDNS_AUTO_RESTART_RELAY=true，正在自动重启 relay" <<<"$out_true"
grep -q "\[MOCK\] relay restart" <<<"$out_true"
grep -q "\[MOCK\] nft apply" <<<"$out_true"
grep -q "\[MOCK\] pbr apply" <<<"$out_true"
grep -q "198.51.100.20" "$RESOLVED_ENTRIES_TSV"
grep -q "203.0.113.20" "$RESOLVED_TSV"
grep -q "192.0.2.20" "$PBR_RESOLVED_DOMAIN_TSV" || {
  echo "FAIL: PBR resolved cache not updated" >&2
  ls -l "$PBR_RESOLVED_DOMAIN_TSV" "$PBR_DOMAIN_TSV" "$PBR_STATIC_CONF" 2>&2 || true
  cat "$PBR_RESOLVED_DOMAIN_TSV" >&2 || true
  grep -E "域名 PBR|PBR" "${TMP_DIR}/true.out" >&2 || true
  exit 1
}
grep -q "LAST_DDNS_RELAY_RESTARTED=true" "$DDNS_STATUS_FILE"
grep -q "LAST_DDNS_RELAY_RESTART_NEEDED=false" "$DDNS_STATUS_FILE"
grep -q "LAST_DDNS_ENTRY_RECENT_ACTION=.*relay 已重启" "$DDNS_STATUS_FILE"
[[ "$(wc -l <"$restart_marker")" -eq 1 ]]

sed -i 's/^DDNS_AUTO_RESTART_RELAY=.*/DDNS_AUTO_RESTART_RELAY=false/' "$DDNS_CONFIG"
sed -i 's/^DDNS_ENTRY_AUTO_RESTART_RELAY=.*/DDNS_ENTRY_AUTO_RESTART_RELAY=false/' "$DDNS_CONFIG"
TEST_HOME_IP="198.51.100.21"
: >"$restart_marker"
ddns_refresh_once --scope entries --non-interactive >"${TMP_DIR}/false.out" 2>&1
out_false="$(cat "${TMP_DIR}/false.out")"
if grep -Eq "是否现在重启 relay|\\[y/N\\]|\\[Y/n\\]" <<<"$out_false"; then
  echo "FAIL: non-interactive false ddns run prompted" >&2
  echo "$out_false" >&2
  exit 1
fi
grep -q "非交互模式，DDNS_AUTO_RESTART_RELAY=false，仅标记 relay restart needed" <<<"$out_false"
if grep -q "\[MOCK\] relay restart" <<<"$out_false"; then
  echo "FAIL: DDNS_AUTO_RESTART_RELAY=false should not restart relay" >&2
  echo "$out_false" >&2
  exit 1
fi
[[ "$(wc -l <"$restart_marker")" -eq 0 ]]
grep -q "198.51.100.21" "$RESOLVED_ENTRIES_TSV"
grep -q "LAST_DDNS_RELAY_RESTART_NEEDED=true" "$DDNS_STATUS_FILE"
grep -q "LAST_DDNS_ENTRY_RECENT_ACTION=已写入缓存 / relay restart needed" "$DDNS_STATUS_FILE"

echo "[OK] DDNS noninteractive autoswitch regression passed"
