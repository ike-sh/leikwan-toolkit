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

resolve_domain_ipv4_multi tw.ike-nicholas.xyz >/dev/null
[[ "$RESOLVE_SELECTED_IP" == "1.1.1.1" ]]

resolve_domain_ipv4_for_pbr tw.ike-nicholas.xyz >"${TMP_DIR}/resolve.out" 2>&1
resolve_out="$(cat "${TMP_DIR}/resolve.out")"
[[ "$RESOLVE_SELECTED_IP" == "36.234.134.253" ]]
grep -q "转发/PBR 场景按多数结果选择：36.234.134.253" <<<"$resolve_out"
bad_strategy="first-success 选择："
bad_strategy="${bad_strategy}1.1.1.1"
if grep -q "按 DNS_RESOLVE_STRATEGY=${bad_strategy}" <<<"$resolve_out"; then
  echo "FAIL: forward/PBR resolver still reports first-success selection" >&2
  exit 1
fi

ensure_tsv_files >/dev/null
mkdir -p "$PBR_DIR"
cat >"$FORWARDS_TSV" <<'EOF'
# name	entry_port	target_host	target_port	out_iface	route_table	enabled	comment
tw	10004	tw.ike-nicholas.xyz	52936		T_CN2	true	Taiwan
EOF
: >"$PBR_STATIC_CONF"

select_forward_name() { printf '%s' "tw"; }
pbr_select_group() { printf '%s' "CN2"; }
pbr_apply() { return 0; }
prompt_yes_no() { return 1; }
apply_nft_rules() { return 0; }

out="$(pbr_add_from_forward 2>&1)"
grep -q "tw.ike-nicholas.xyz(36.234.134.253)" <<<"$out"
bad_forward="tw.ike-nicholas.xyz("
bad_forward="${bad_forward}1.1.1.1)"
if grep -q "$bad_forward" <<<"$out"; then
  echo "FAIL: pbr add showed first-success IP before majority IP" >&2
  echo "$out" >&2
  exit 1
fi
grep -q "36.234.134.253/32 CN2 forward tw tw.ike-nicholas.xyz" "$PBR_STATIC_CONF"

pbr_out="$(pbr_show 2>&1)"
grep -q "36.234.134.253/32" <<<"$pbr_out"
grep -q "forward:tw tw.ike-nicholas.xyz" <<<"$pbr_out"

echo "[OK] PBR forward domain resolution regression passed"
