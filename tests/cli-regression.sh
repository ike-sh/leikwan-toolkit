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

run_cli() {
  local out rc
  set +e
  out="$(bash leikwan-toolkit.sh "$@" 2>&1)"
  rc=$?
  set -e
  if (( rc != 0 )); then
    echo "FAIL: command returned ${rc}: $*" >&2
    echo "$out" >&2
    exit 1
  fi
  if grep -q "错误：脚本在�? <<<"$out"; then
    echo "FAIL: global trap triggered: $*" >&2
    echo "$out" >&2
    exit 1
  fi
  [[ -n "$out" ]] || { echo "FAIL: empty output: $*" >&2; exit 1; }
}

validate_json_cli() {
  local out
  out="$(bash leikwan-toolkit.sh "$@" 2>&1)"
  if grep -q "错误：脚本在�? <<<"$out"; then
    echo "FAIL: global trap triggered: $*" >&2
    echo "$out" >&2
    exit 1
  fi
  if command -v jq >/dev/null 2>&1; then
    jq . >/dev/null <<<"$out" || { echo "FAIL: invalid JSON: $*" >&2; echo "$out" >&2; exit 1; }
  elif command -v node >/dev/null 2>&1; then
    node -e 'const fs=require("fs"); JSON.parse(fs.readFileSync(0,"utf8"));' >/dev/null <<<"$out" || { echo "FAIL: invalid JSON: $*" >&2; echo "$out" >&2; exit 1; }
  else
    grep -q '^{.*' <<<"$(tr -d '\n' <<<"$out")" || { echo "FAIL: JSON validator unavailable and output is not object-like" >&2; echo "$out" >&2; exit 1; }
  fi
}

run_cli --version
run_cli --help
run_cli init --dry-run
run_cli init --plan
run_cli plan
run_cli status
run_cli --brief
run_cli --compact
validate_json_cli status --json
run_cli --status
validate_json_cli --status-json
validate_json_cli doctor --json
validate_json_cli --doctor-json
run_cli --dry-run doctor --auto-fix
run_cli --dry-run --doctor --auto-fix
run_cli port check
run_cli --port-check
run_cli ddns status
run_cli ddns overview
run_cli ddns check-consistency
run_cli ddns entry status
run_cli entry ddns status
run_cli update status
run_cli config list
run_cli output show
run_cli logs
run_cli logs ddns
run_cli logs entry-ddns
run_cli logs apply
run_cli logs update
run_cli logs doctor
run_cli pbr domain list

mkdir -p "${LEIKWAN_STATE_DIR}/entries" "${LEIKWAN_STATE_DIR}/forwards"
cat >"${LEIKWAN_STATE_DIR}/entries/entries.tsv" <<'EOF'
# entry_name	public_host	et_ip	easytier_protocol	easytier_port	weight	enabled
public3	home.example.test	10.198.1.4	tcp,udp	8303	100	false
EOF
cat >"${LEIKWAN_STATE_DIR}/forwards/forwards.tsv" <<'EOF'
# name	entry_port	target_host	target_port	out_iface	route_table	enabled	comment
tw	10004	tw.example.test	52936	eth1	T_CN2	false	tw-target
EOF
port_out="$(bash leikwan-toolkit.sh port check 2>&1)"
grep -q '\[INFO\].*�?disabled' <<<"$port_out" || {
  echo "FAIL: disabled port entries should be INFO" >&2
  echo "$port_out" >&2
  exit 1
}
if grep -q '\[WARN\].*disabled' <<<"$port_out"; then
  echo "FAIL: disabled port entries produced WARN" >&2
  echo "$port_out" >&2
  exit 1
fi

echo "[OK] cli regression passed"
