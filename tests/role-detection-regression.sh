#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/tests/test-lib.sh"

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

reset_state() {
  rm -rf "$LEIKWAN_STATE_DIR"
  mkdir -p "$EASYTIER_DIR" "$ENTRIES_DIR" "$FORWARDS_DIR" "$PBR_DIR" "$ENTRY_DIR" "$STATUS_DIR"
  printf '# entry_name\tpublic_host\tet_ip\teasytier_protocol\teasytier_port\tweight\tenabled\n' >"$ENTRIES_TSV"
  printf '# name\tentry_port\ttarget_host\ttarget_port\tout_iface\troute_table\tenabled\tcomment\n' >"$FORWARDS_TSV"
}

summary_field() {
  local summary="$1" index="$2"
  awk -F'\t' -v idx="$index" '{print $idx}' <<<"$summary"
}

reset_state
cat >"$NETWORK_ENV" <<'EOF'
ROLE=leikwan-relay
EASYTIER_NETWORK_NAME=test-net
EASYTIER_NETWORK_SECRET=testsec
EOF
printf 'public3\thome.example.test\t10.198.1.4\ttcp,udp\t8303\t100\ttrue\n' >>"$ENTRIES_TSV"
printf 'hk\t10001\t198.51.100.10\t443\teth0\tT_CN2\ttrue\thk-target\n' >>"$FORWARDS_TSV"
summary="$(role_summary)"
[[ "$(summary_field "$summary" 1)" == "leikwan-relay" ]] || { echo "FAIL: relay role not detected" >&2; exit 1; }
[[ "$(summary_field "$summary" 3)" == "false" ]] || { echo "FAIL: relay with entries.tsv was marked mixed" >&2; exit 1; }
status_out="$(status_overview)"
if grep -q "高级混合部署" <<<"$status_out"; then
  echo "FAIL: relay node with entries.tsv produced mixed-role warning" >&2
  echo "$status_out" >&2
  exit 1
fi

reset_state
cat >"$NETWORK_ENV" <<'EOF'
ROLE=cloud-entry
ENTRY_NAME=public3
ENTRY_ET_IP=10.198.1.4
EOF
summary="$(role_summary)"
[[ "$(summary_field "$summary" 1)" == "cloud-entry" ]] || { echo "FAIL: entry role not detected" >&2; exit 1; }

reset_state
cat >"$NETWORK_ENV" <<'EOF'
ROLE=leikwan-relay
EASYTIER_NETWORK_NAME=test-net
EASYTIER_NETWORK_SECRET=testsec
EOF
cat >"$ENTRY_EXPOSE_ENV" <<'EOF'
ENTRY_EXPOSE_START=10000
ENTRY_EXPOSE_END=19999
ENTRY_EXPOSE_RELAY_IP=10.198.1.1
EOF
summary="$(role_summary)"
[[ "$(summary_field "$summary" 1)" == "leikwan-relay" ]] || { echo "FAIL: mixed deployment should keep relay as primary role" >&2; exit 1; }
[[ "$(summary_field "$summary" 3)" == "true" ]] || { echo "FAIL: true relay+entry deployment was not marked mixed" >&2; exit 1; }
status_out="$(status_overview)"
grep -q "检测到高级混合部署：relay + entry" <<<"$status_out" || {
  echo "FAIL: true mixed deployment did not produce warning" >&2
  echo "$status_out" >&2
  exit 1
}

echo "[OK] role detection regression passed"
