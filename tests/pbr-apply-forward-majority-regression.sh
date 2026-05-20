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

need_root_unless_dry_run() { :; }
global_lock_acquire() { LEIKWAN_GLOBAL_LOCK_TOKEN="test"; }
global_lock_release() { LEIKWAN_GLOBAL_LOCK_TOKEN=""; }
pbr_init_rt_tables() { :; }
pbr_table_id() { printf '%s' "102"; }
pbr_group_gateway() { printf '%s' "10.8.0.1"; }
dnsutils_auto_install() { :; }
dig() {
  local server="${4#@}"
  case "$server" in
    1.1.1.1) printf '%s\n' "1.1.1.1" ;;
    8.8.8.8) printf '%s\n' "8.8.8.8" ;;
    223.5.5.5|119.29.29.29) printf '%s\n' "36.234.134.253" ;;
    *) return 1 ;;
  esac
}
getent() {
  case "$1" in
    ahostsv4|ahosts) printf '%s STREAM tw.ike-nicholas.xyz\n' "36.234.134.253" ;;
    *) return 1 ;;
  esac
}
ip() {
  case "${1:-} ${2:-} ${3:-}" in
    "rule del priority") return 1 ;;
    "route replace default") return 0 ;;
    "rule add to") return 0 ;;
  esac
  return 0
}

ensure_tsv_files >/dev/null
mkdir -p "$PBR_DIR"
PBR_RT_TABLES="${TMP_DIR}/rt_tables"
printf '102 T_CN2\n' >"$PBR_RT_TABLES"
cat >"$PBR_STATIC_CONF" <<'EOF'
1.1.1.1/32 CN2 forward tw tw.ike-nicholas.xyz
EOF

out="$(pbr_apply 2>&1)"
grep -q "转发/PBR 场景按多数结果选择：36.234.134.253" <<<"$out"
old_cidr="1.1.1.1/32"
grep -q "PBR 来源转发 tw 解析变化：${old_cidr} -> 36.234.134.253/32" <<<"$out"
grep -q "PBR：36.234.134.253/32 -> T_CN2" <<<"$out"

bad_strategy="first-success 选择："
bad_strategy="${bad_strategy}1.1.1.1"
bad_pbr="PBR："
bad_pbr="${bad_pbr}1.1.1.1/32"
if grep -q "$bad_strategy" <<<"$out" || grep -q "$bad_pbr" <<<"$out"; then
  echo "FAIL: PBR apply still used first-success IP" >&2
  echo "$out" >&2
  exit 1
fi
grep -q "36.234.134.253/32 CN2 forward tw tw.ike-nicholas.xyz" "$PBR_STATIC_CONF"
if grep -q "^1.1.1.1/32" "$PBR_STATIC_CONF"; then
  echo "FAIL: PBR static config still contains first-success CIDR" >&2
  cat "$PBR_STATIC_CONF" >&2
  exit 1
fi

echo "[OK] PBR apply forward majority regression passed"
