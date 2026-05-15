#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/tests/test-lib.sh"

mkdir -p "$ROOT_DIR/.tmp"
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

need_root_unless_dry_run() { return 0; }
prompt_apply_relay_after_entry_change() { return 0; }
dnsutils_auto_install() { return 0; }

mkdir -p "$ENTRIES_DIR"
cat >"$ENTRIES_TSV" <<'EOF'
# entry_name	public_host	et_ip	easytier_protocol	easytier_port	weight	enabled
public2	139.196.11.111	10.198.1.3	tcp,udp	8302	1000	true
public3	home.example.test	10.198.1.4	tcp,udp	8303	100	false
EOF

enable_out="$(printf '2\n\n' | set_entry_enabled 2>&1 || true)"
grep -q "是否启用公网入口 public3" <<<"$enable_out"
grep -q "已启用公网入口：public3" <<<"$enable_out"
old_enabled_prompt='enabled true'/'false'
if grep -q "$old_enabled_prompt" <<<"$enable_out"; then
  echo "FAIL: old enabled true-or-false prompt leaked for entry enable" >&2
  echo "$enable_out" >&2
  exit 1
fi
awk -F'\t' '$1=="public3" {exit !($7=="true")}' "$ENTRIES_TSV"

disable_out="$(printf '2\ny\n' | set_entry_enabled 2>&1 || true)"
grep -q "是否禁用公网入口 public3" <<<"$disable_out"
grep -q "已禁用公网入口：public3" <<<"$disable_out"
if grep -q "$old_enabled_prompt" <<<"$disable_out"; then
  echo "FAIL: old enabled true-or-false prompt leaked for entry disable" >&2
  echo "$disable_out" >&2
  exit 1
fi
awk -F'\t' '$1=="public3" {exit !($7=="false")}' "$ENTRIES_TSV"

bulk_out="$(printf '1\n\n' | bulk_entry_enable_menu 2>&1 || true)"
grep -q "是否启用所有公网入�? <<<"$bulk_out"
if grep -q "$old_enabled_prompt" <<<"$bulk_out"; then
  echo "FAIL: old enabled true-or-false prompt leaked for bulk entry toggle" >&2
  echo "$bulk_out" >&2
  exit 1
fi

echo "[OK] entry enable disable regression passed"
