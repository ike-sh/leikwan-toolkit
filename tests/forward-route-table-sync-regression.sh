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

detect_target_route() {
  printf '36.234.134.253\034eth0\034\034203.0.113.10\034\03436.234.134.253 dev eth0 src 203.0.113.10\n'
}

ensure_tsv_files >/dev/null
cat >"$FORWARDS_TSV" <<'EOF'
# name	entry_port	target_host	target_port	out_iface	route_table	enabled	comment
tw	10004	tw.ike-nicholas.xyz	52936	eth0	T_CN2	true	Taiwan
EOF

out="$(sync_forward_routes_if_needed 1 2>&1)"
grep -q "route_table 保留为 T_CN2" <<<"$out"
grep -q "PBR 未正确应用或域名解析分歧导致" <<<"$out"
awk -F'\t' '$1=="tw" && $6=="T_CN2" {found=1} END{exit !found}' "$FORWARDS_TSV"
if awk -F'\t' '$1=="tw" && $6=="" {found=1} END{exit !found}' "$FORWARDS_TSV"; then
  echo "FAIL: auto-fix-route cleared route_table" >&2
  cat "$FORWARDS_TSV" >&2
  exit 1
fi

doctor_out="$(report_forward_route_consistency tw tw.ike-nicholas.xyz eth0 T_CN2 2>&1)"
grep -q "route_table 元数据保留为 T_CN2" <<<"$doctor_out"
grep -q "PBR 未正确应用或域名解析分歧导致" <<<"$doctor_out"

echo "[OK] forward route_table sync regression passed"
