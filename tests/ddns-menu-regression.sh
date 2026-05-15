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

main_out="$(print_main_menu_options)"
grep -q "4. DDNS" <<<"$main_out"
grep -q "6." <<<"$main_out"
grep -q "0." <<<"$main_out"

ddns_out="$(print_ddns_menu_options)"
grep -q "DDNS" <<<"$ddns_out"
grep -q "1." <<<"$ddns_out"
grep -q "2." <<<"$ddns_out"
grep -q "3." <<<"$ddns_out"
grep -q "4." <<<"$ddns_out"
grep -q "5." <<<"$ddns_out"
grep -q "0." <<<"$ddns_out"

advanced_out="$(printf '0\n' | ddns_advanced_menu 2>&1 || true)"
grep -q "DNS" <<<"$advanced_out"
grep -q "relay" <<<"$advanced_out"
grep -q "3." <<<"$advanced_out"
grep -q "4." <<<"$advanced_out"
grep -q "5." <<<"$advanced_out"
grep -q "9." <<<"$advanced_out"
grep -q "10." <<<"$advanced_out"

systemctl() { return 0; }
need_root_unless_dry_run() { return 0; }
ddns_install_units() { ok "unit stub"; }
toggle_out="$(printf '1\n\n0\n' | ddns_toggle_menu 2>&1 || true)"
[[ -n "$toggle_out" ]]
grep -q "0." <<<"$toggle_out"

echo "[OK] ddns menu regression passed"
