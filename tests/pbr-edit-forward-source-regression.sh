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
36.234.134.253/32 CN2 forward tw tw.ike-nicholas.xyz
EOF

out="$(printf 'n\nnew-forward-note\ny\n' | pbr_edit_rule 1 2>&1)"
grep -q "这是从转发目标生成的 PBR" <<<"$out"
grep -q "目标 IP 会跟随转发目标解析自动同步" <<<"$out"
grep -q "转发目标管理 -> 修改转发目标" <<<"$out"
grep -q "forward 来源 PBR 默认不允许直接修改目标 CIDR" <<<"$out"
grep -q '^36.234.134.253/32 CN2 forward tw tw.ike-nicholas.xyz enabled=true remark=new-forward-note$' "$PBR_STATIC_CONF"

cat >"$PBR_STATIC_CONF" <<'EOF'
36.234.134.253/32 CN2 forward tw tw.ike-nicholas.xyz
EOF

convert_out="$(printf 'y\ny\nconverted-note\nY\ny\n' | pbr_edit_rule 1 2>&1)"
grep -q "确认转为静态 PBR" <<<"$convert_out"
grep -q "PBR 规则已修改" <<<"$convert_out"
grep -q '^36.234.134.253/32 CN2 static enabled=true remark=converted-note$' "$PBR_STATIC_CONF"
if grep -q ' forward ' "$PBR_STATIC_CONF"; then
  echo "FAIL: forward source was not removed after converting to static" >&2
  cat "$PBR_STATIC_CONF" >&2
  exit 1
fi

cat >"$PBR_STATIC_CONF" <<'EOF'
198.51.100.8/32 CN2 pbr-domain:site site.example.com
EOF
before_domain="$(cat "$PBR_STATIC_CONF")"
domain_out="$(pbr_edit_rule 1 2>&1)"
grep -q "这是由 pbr-domain:site site.example.com 生成的 PBR" <<<"$domain_out"
grep -q "请使用对应管理入口修改" <<<"$domain_out"
after_domain="$(cat "$PBR_STATIC_CONF")"
[[ "$after_domain" == "$before_domain" ]]

echo "[OK] PBR edit forward source regression passed"
