#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=tests/test-lib.sh
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

need_root_unless_dry_run() { :; }
dnsutils_auto_install() { :; }
dig() {
  local server="${4#@}"
  case "$server" in
    1.1.1.1) printf '%s\n' "1.1.1.1" ;;
    8.8.8.8|223.5.5.5|119.29.29.29) printf '%s\n' "36.234.134.253" ;;
    *) return 1 ;;
  esac
}
getent() {
  case "$1" in
    ahostsv4|ahosts) printf '%s STREAM tw.ike-nicholas.xyz\n' "36.234.134.253" ;;
    *) return 1 ;;
  esac
}

ensure_tsv_files >/dev/null
cat >"$FORWARDS_TSV" <<'EOF'
# name	entry_port	target_host	target_port	out_iface	route_table	enabled	comment
tw	10004	tw.ike-nicholas.xyz	52936		T_CN2	true	Taiwan
EOF

resolve_out="$(resolve_forwards 2>&1)"
grep -q "转发/PBR 场景按多数结果选择：36.234.134.253" <<<"$resolve_out"
awk -F'\t' '$1=="tw" && $4=="36.234.134.253" {found=1} END{exit !found}' "$RESOLVED_TSV"
if awk -F'\t' '$1=="tw" && $4=="1.1.1.1" {found=1} END{exit !found}' "$RESOLVED_TSV"; then
  echo "FAIL: resolved.tsv used first-success IP" >&2
  cat "$RESOLVED_TSV" >&2
  exit 1
fi

list_out="$(display_forwards 2>&1)"
grep -q "tw.ike-nicholas.xyz:52936" <<<"$list_out"
grep -q "36.234.134.253" <<<"$list_out"
if grep -q "1.1.1.1" <<<"$list_out"; then
  echo "FAIL: forward list displayed first-success IP" >&2
  echo "$list_out" >&2
  exit 1
fi

echo "[OK] forward domain resolution regression passed"
