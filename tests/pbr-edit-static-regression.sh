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
trap - ERR

need_root_unless_dry_run() { :; }
auto_snapshot_or_confirm() { :; }

mkdir -p "$PBR_DIR"
cat >"$PBR_STATIC_CONF" <<'EOF'
203.0.113.10/32 CN2 static iface=eth0 enabled=true remark=old
EOF

out="$(printf '103.100.176.107\nT_9929\neth1\nnew-remark\nn\ny\n' | pbr_edit_rule 1 2>&1)"
grep -q "PBR 规则已修改" <<<"$out"
grep -q '^103.100.176.107/32 9929 static iface=eth1 enabled=false remark=new-remark$' "$PBR_STATIC_CONF"

show_out="$(pbr_show 2>&1)"
grep -q "103.100.176.107/32" <<<"$show_out"
grep -q "T_9929" <<<"$show_out"
grep -q "eth1" <<<"$show_out"
grep -q "false" <<<"$show_out"
grep -q "new-remark" <<<"$show_out"

out_keep="$(printf '\n\n\n\nY\ny\n' | pbr_edit_rule 1 2>&1)"
grep -q "PBR 规则已修改" <<<"$out_keep"
grep -q '^103.100.176.107/32 9929 static iface=eth1 enabled=true remark=new-remark$' "$PBR_STATIC_CONF"

before="$(cat "$PBR_STATIC_CONF")"
out_invalid="$(printf 'not-an-ip\n103.100.176.107/32\n\n\n\nY\ny\n' | pbr_edit_rule 1 2>&1)"
grep -q "目标 IP/CIDR 无效" <<<"$out_invalid"
after="$(cat "$PBR_STATIC_CONF")"
[[ "$after" == "$before" ]]

echo "[OK] PBR edit static regression passed"
