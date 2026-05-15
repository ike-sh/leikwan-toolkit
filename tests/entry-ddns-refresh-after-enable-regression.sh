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

need_root_unless_dry_run() { return 0; }
prompt_apply_relay_after_entry_change() { echo "[MOCK] relay prompt"; return 0; }
dnsutils_auto_install() { return 0; }
detect_public_ipv4() { DDNS_PUBLIC_IP="203.0.113.9"; DDNS_PUBLIC_IP_SOURCE="mock"; printf '%s' "$DDNS_PUBLIC_IP"; }
resolve_domain_ipv4_multi() {
  RESOLVE_SELECTED_IP="74.48.182.221"
  RESOLVE_SELECTED_SOURCE="mock"
  RESOLVE_ALL_RESULTS="mock -> 74.48.182.221"
  RESOLVE_SPLIT_DETECTED=false
  return 0
}

mkdir -p "$ENTRIES_DIR"
cat >"$ENTRIES_TSV" <<'EOF'
# entry_name	public_host	et_ip	easytier_protocol	easytier_port	weight	enabled
public3	home.example.test	10.198.1.4	tcp,udp	8303	100	false
EOF

out="$(printf '1\n\n' | set_entry_enabled 2>&1)"
grep -q "已启用公网入口：public3" <<<"$out"
grep -q "检测到公网入口使用域名，正在刷新解析缓�? <<<"$out"
grep -q "home.example.test" "$RESOLVED_ENTRIES_TSV"
grep -q "74.48.182.221" "$RESOLVED_ENTRIES_TSV"
grep -q "LAST_DDNS_ENTRY_RECENT_EVENTS=public3: 初次记录 74.48.182.221" "$DDNS_STATUS_FILE"

echo "[OK] entry ddns refresh after enable regression passed"
