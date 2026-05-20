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

ensure_tsv_files >/dev/null
mkdir -p "$PBR_DIR"
cat >"$PBR_STATIC_CONF" <<'EOF'
36.234.134.253/32 CN2 forward tw tw.ike-nicholas.xyz
EOF

out="$(pbr_domain_list 2>&1)"
grep -q "当前没有域名 PBR" <<<"$out"
grep -q "从转发目标添加的 PBR" <<<"$out"
grep -q "查看 PBR" <<<"$out"
grep -q "forward:name domain" <<<"$out"

pbr_out="$(pbr_show 2>&1)"
grep -q "36.234.134.253/32" <<<"$pbr_out"
grep -q "forward:tw tw.ike-nicholas.xyz" <<<"$pbr_out"

echo "[OK] domain PBR message regression passed"
