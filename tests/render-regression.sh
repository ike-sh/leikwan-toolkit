#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export LEIKWAN_STATE_DIR="${TMP_DIR}/state"
export LEIKWAN_BACKUP_DIR="${TMP_DIR}/backups"
export LEIKWAN_RUN_DIR="${TMP_DIR}/run"
export LEIKWAN_LOG_DISABLED=1
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

mkdir -p "$ENTRIES_DIR" "$FORWARDS_DIR" "$PBR_DIR" "$OUTPUT_DIR"
cat >"$ENTRIES_TSV" <<'EOF'
# entry_name	public_host	et_ip	easytier_protocol	easytier_port	weight	enabled
public1	203.0.113.10	10.198.1.2	tcp,udp	8301	100	true
public2	203.0.113.20	10.198.1.3	tcp,udp	8302	80	false
EOF
cat >"$PENDING_ENTRIES_TSV" <<'EOF'
# entry_name	et_ip	easytier_protocol	easytier_port	created_at
public3	10.198.1.4	tcp,udp	8303	2026-05-11 03:00:00
EOF
cat >"$FORWARDS_TSV" <<'EOF'
# name	entry_port	target_host	target_port	out_iface	route_table	enabled	comment
hk	10001	198.51.100.10	443	eth0	T_CN2	true	hk-target
sg	10002	198.51.100.20	8443	eth1		false	sg-target
EOF
cat >"$PBR_STATIC_CONF" <<'EOF'
198.51.100.10/32 T_CN2 static
203.0.113.7/32 T_CT pbr-domain:tw tw.example.test
EOF

assert_render() {
  local mode="$1" cols="$2" out
  export LEIKWAN_COMPACT="$mode"
  export LEIKWAN_COLUMNS="$cols"
  out="$(display_entries)"
  grep -q "public1" <<<"$out"
  out="$(display_forwards)"
  grep -q "hk" <<<"$out"
  out="$(display_pbr_rules)"
  grep -q "198.51.100.10/32" <<<"$out"
  out="$(display_pending_entries)"
  grep -q "public3" <<<"$out"
}

assert_render 1 80
assert_render 0 80
assert_render 0 160

export LEIKWAN_NO_CLEAR=1
menu_out="$(print_init_wizard_menu)"
grep -q "Leikwan 初始化向导" <<<"$menu_out"
grep -q "B：利群主机" <<<"$menu_out"
main_out="$(print_main_menu_options)"
grep -q "1. 快速组网" <<<"$main_out"
grep -q "6. 高级维护" <<<"$main_out"
ddns_out="$(print_ddns_menu_options)"
grep -q "4. 查看 DDNS 日志" <<<"$ddns_out"

echo "[OK] render regression passed"
